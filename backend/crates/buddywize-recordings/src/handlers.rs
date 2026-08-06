//! Recording handlers: resumable upload session lifecycle, recording delta
//! sync, and reprocess (on-demand regeneration of study material).

use axum::{
    body::Bytes,
    extract::{Path, Query, State},
    Json,
};
use buddywize_auth::middleware::AuthUser;
use buddywize_core::{ApiError, ApiResult, SinceQuery};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::storage::{object_key, UploadChunk};
use crate::RecordingState;

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct RecordingDto {
    pub id: Uuid,
    pub chapter_id: Uuid,
    pub client_uuid: Option<Uuid>,
    pub duration_secs: Option<i32>,
    pub status: String,
    pub error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow)]
struct UploadSessionRow {
    id: Uuid,
    user_id: Uuid,
    client_uuid: Uuid,
    chapter_id: Uuid,
    path: String,
    received_bytes: i64,
    duration_secs: Option<i32>,
    completed_at: Option<DateTime<Utc>>,
}

// -------------------------------------------------------------------- uploads

#[derive(Debug, Deserialize, ToSchema)]
pub struct CreateUploadRequest {
    /// Client UUID of the recording that will result from this upload.
    pub client_uuid: Uuid,
    /// Chapter (by client UUID) the recording belongs to.
    pub chapter_client_uuid: Uuid,
    pub duration_secs: Option<i32>,
    /// Original file name, used only to pick a file extension.
    pub file_name: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UploadSessionDto {
    pub upload_id: Uuid,
    /// Byte offset the client should resume from (0 for a new upload).
    pub offset: u64,
}

/// Start a resumable upload for a recording. Idempotent on `client_uuid`.
#[utoipa::path(
    post,
    path = "/api/recordings/uploads",
    request_body = CreateUploadRequest,
    responses((status = 200, description = "Upload session", body = UploadSessionDto))
)]
pub async fn create_upload(
    State(state): State<RecordingState>,
    AuthUser(user): AuthUser,
    Json(body): Json<CreateUploadRequest>,
) -> ApiResult<Json<UploadSessionDto>> {
    let chapter_id: Uuid = sqlx::query_scalar(
        "SELECT ch.id FROM chapters ch
           JOIN lessons l ON l.id = ch.lesson_id
           JOIN courses c ON c.id = l.course_id
          WHERE ch.client_uuid = $1 AND c.user_id = $2 AND ch.deleted_at IS NULL",
    )
    .bind(body.chapter_client_uuid)
    .bind(user.sub)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| ApiError::BadRequest("chapter not found; sync structure first".into()))?;

    // Reuse an existing session for this client_uuid (resume, not duplicate).
    if let Some(existing) = sqlx::query_as::<_, UploadSessionRow>(
        "SELECT * FROM upload_sessions WHERE client_uuid = $1 AND user_id = $2",
    )
    .bind(body.client_uuid)
    .bind(user.sub)
    .fetch_optional(&state.db)
    .await?
    {
        let offset = state.storage.upload_offset(&existing.path).await.map_err(|e| ApiError::Internal(e.into()))?;
        return Ok(Json(UploadSessionDto { upload_id: existing.id, offset }));
    }

    let id = Uuid::new_v4();
    let key = object_key(&id, body.file_name.as_deref());
    state.storage.create_upload(&key).await.map_err(|e| ApiError::Internal(e.into()))?;

    sqlx::query(
        "INSERT INTO upload_sessions (id, user_id, client_uuid, chapter_id, path, duration_secs)
         VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind(id)
    .bind(user.sub)
    .bind(body.client_uuid)
    .bind(chapter_id)
    .bind(&key)
    .bind(body.duration_secs)
    .execute(&state.db)
    .await?;

    Ok(Json(UploadSessionDto { upload_id: id, offset: 0 }))
}

#[derive(Debug, Deserialize)]
pub struct ChunkQuery {
    pub offset: u64,
}

/// Append a chunk at the given offset. The server echoes the new offset so
/// the client can resume after interruptions.
#[utoipa::path(
    put,
    path = "/api/recordings/uploads/{id}/chunk",
    request_body(content = Vec<u8>, content_type = "application/octet-stream"),
    params(
        ("id" = Uuid, Path, description = "Upload session ID"),
        ("offset" = u64, Query, description = "Byte offset of this chunk")
    ),
    responses((status = 200, description = "Chunk accepted", body = UploadSessionDto))
)]
pub async fn upload_chunk(
    State(state): State<RecordingState>,
    AuthUser(user): AuthUser,
    Path(id): Path<Uuid>,
    Query(q): Query<ChunkQuery>,
    data: Bytes,
) -> ApiResult<Json<UploadSessionDto>> {
    let session = load_owned_session(&state, user.sub, id).await?;
    if session.completed_at.is_some() {
        return Err(ApiError::Conflict("upload already completed".into()));
    }

    let chunk = UploadChunk { offset: q.offset, bytes: data.to_vec() };
    let new_offset = state
        .storage
        .append_chunk(&session.path, chunk)
        .await
        .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    sqlx::query("UPDATE upload_sessions SET received_bytes = $1 WHERE id = $2")
        .bind(new_offset as i64)
        .bind(id)
        .execute(&state.db)
        .await?;

    Ok(Json(UploadSessionDto { upload_id: id, offset: new_offset }))
}

/// Finalize the upload: creates the recording row and enqueues AI processing.
#[utoipa::path(
    post,
    path = "/api/recordings/uploads/{id}/complete",
    responses((status = 200, description = "Recording created", body = RecordingDto))
)]
pub async fn complete_upload(
    State(state): State<RecordingState>,
    AuthUser(user): AuthUser,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<RecordingDto>> {
    let session = load_owned_session(&state, user.sub, id).await?;
    if let Some(_) = session.completed_at {
        let recording = fetch_recording_by_client_uuid(&state, user.sub, session.client_uuid).await?;
        return Ok(Json(recording));
    }

    state.storage.finish_upload(&session.path).await.map_err(|e| ApiError::Internal(e.into()))?;

    let recording = upsert_recording(&state, &session).await?;

    sqlx::query("UPDATE upload_sessions SET completed_at = now() WHERE id = $1")
        .bind(id)
        .execute(&state.db)
        .await?;

    // Kick off the AI pipeline; failures here should not fail the upload.
    if let Err(e) = state.jobs.send(recording.id).await {
        tracing::error!(error = %e, recording_id = %recording.id, "failed to enqueue recording");
    }

    Ok(Json(recording))
}

async fn load_owned_session(
    state: &RecordingState,
    user_id: Uuid,
    id: Uuid,
) -> ApiResult<UploadSessionRow> {
    let session: Option<UploadSessionRow> =
        sqlx::query_as("SELECT * FROM upload_sessions WHERE id = $1 AND user_id = $2")
            .bind(id)
            .bind(user_id)
            .fetch_optional(&state.db)
            .await?;
    session.ok_or(ApiError::NotFound)
}

async fn upsert_recording(state: &RecordingState, session: &UploadSessionRow) -> ApiResult<RecordingDto> {
    if let Some(existing) = fetch_recording_by_client_uuid_opt(state, session.user_id, session.client_uuid).await? {
        return Ok(existing);
    }
    // Persist the storage *key* (backend-agnostic), not an absolute path.
    let row: RecordingDto = sqlx::query_as(
        "INSERT INTO recordings
            (user_id, chapter_id, client_uuid, storage_path, duration_secs, status)
         VALUES ($1, $2, $3, $4, $5, 'uploaded')
         RETURNING id, chapter_id, client_uuid, duration_secs, status, error, created_at, updated_at, sync_version",
    )
    .bind(session.user_id)
    .bind(session.chapter_id)
    .bind(session.client_uuid)
    .bind(&session.path)
    .bind(session.duration_secs)
    .fetch_one(&state.db)
    .await?;
    Ok(row)
}

async fn fetch_recording_by_client_uuid(
    state: &RecordingState,
    user_id: Uuid,
    client_uuid: Uuid,
) -> ApiResult<RecordingDto> {
    fetch_recording_by_client_uuid_opt(state, user_id, client_uuid)
        .await?
        .ok_or(ApiError::NotFound)
}

async fn fetch_recording_by_client_uuid_opt(
    state: &RecordingState,
    user_id: Uuid,
    client_uuid: Uuid,
) -> ApiResult<Option<RecordingDto>> {
    let row: Option<RecordingDto> = sqlx::query_as(
        "SELECT id, chapter_id, client_uuid, duration_secs, status, error, created_at, updated_at, sync_version
           FROM recordings WHERE client_uuid = $1 AND user_id = $2",
    )
    .bind(client_uuid)
    .bind(user_id)
    .fetch_optional(&state.db)
    .await?;
    Ok(row)
}

// ----------------------------------------------------------------------- list

#[derive(Debug, Serialize, ToSchema)]
pub struct DeltaResponse<T: Serialize> {
    pub items: Vec<T>,
    pub cursor: i64,
    pub has_more: bool,
}

/// Delta-sync recording metadata (status drives the sync UI in the app).
#[utoipa::path(
    get,
    path = "/api/recordings",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Recording delta", body = DeltaResponse<RecordingDto>))
)]
pub async fn list_recordings(
    State(state): State<RecordingState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<DeltaResponse<RecordingDto>>> {
    let rows: Vec<RecordingDto> = sqlx::query_as(
        "SELECT id, chapter_id, client_uuid, duration_secs, status, error, created_at, updated_at, sync_version
           FROM recordings
          WHERE user_id = $1 AND ($2::bigint IS NULL OR sync_version > $2)
          ORDER BY sync_version
          LIMIT 500",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_all(&state.db)
    .await?;

    let cursor = rows.iter().map(|r| r.sync_version).max().unwrap_or(q.since.unwrap_or(0));
    let has_more = rows.len() >= 500;
    Ok(Json(DeltaResponse { items: rows, cursor, has_more }))
}

// ------------------------------------------------------------------ reprocess

#[derive(Debug, Serialize, ToSchema)]
pub struct ReprocessResponse {
    pub recording_id: Uuid,
    pub status: String,
    pub message: String,
}

/// Re-run the AI pipeline for an existing recording (e.g. on-demand quiz
/// generation or after a provider upgrade). Requires an active entitlement.
#[utoipa::path(
    post,
    path = "/api/recordings/{id}/reprocess",
    responses((status = 202, description = "Processing queued", body = ReprocessResponse))
)]
pub async fn reprocess(
    State(state): State<RecordingState>,
    AuthUser(user): AuthUser,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<ReprocessResponse>> {
    let entitlement = buddywize_core::active_entitlement(&state.db, user.sub, &user.role).await?;
    if entitlement.is_none() {
        return Err(ApiError::Forbidden.into());
    }

    let recording: Option<RecordingDto> = sqlx::query_as(
        "SELECT id, chapter_id, client_uuid, duration_secs, status, error, created_at, updated_at, sync_version
           FROM recordings WHERE id = $1 AND user_id = $2",
    )
    .bind(id)
    .bind(user.sub)
    .fetch_optional(&state.db)
    .await?;
    let recording = recording.ok_or(ApiError::NotFound)?;

    state.jobs.send(recording.id).await.map_err(|e| ApiError::Internal(e.into()))?;

    Ok(Json(ReprocessResponse {
        recording_id: recording.id,
        status: "queued".to_string(),
        message: "AI processing queued".to_string(),
    }))
}
