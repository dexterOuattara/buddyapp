//! Admin-scoped endpoints backing the Svelte admin panel: user listing,
//! recording/pipeline monitoring, moderation of AI-generated content, and
//! per-recording detail (audio stream + transcript + study material).
//! All routes here are additionally guarded by `require_admin` in the API
//! gateway.

use std::sync::Arc;

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::Response,
    routing::{get, post},
    Json, Router,
};
use buddywize_core::storage::StorageBackend;
use buddywize_core::{ApiError, ApiResult};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Clone)]
pub struct AdminState {
    pub db: PgPool,
    pub storage: Arc<dyn StorageBackend>,
}

pub fn router(state: AdminState) -> Router {
    Router::new()
        .route("/admin/users", get(list_users))
        .route("/admin/users/:id/role", post(set_user_role))
        .route("/admin/recordings", get(list_recordings))
        .route("/admin/recordings/:id", get(recording_detail))
        .route("/admin/recordings/:id/audio", get(recording_audio))
        .route("/admin/moderation", get(list_pending_moderation))
        .route("/admin/moderation/summaries/:id", post(decide_summary))
        .route("/admin/moderation/exercises/:id", post(decide_exercises))
        .route("/admin/moderation/quizzes/:id", post(decide_quiz))
        .with_state(state)
}

// ----------------------------------------------------------------------- users

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct AdminUserRow {
    pub id: Uuid,
    pub email: String,
    pub role: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct ListUsersQuery {
    pub q: Option<String>,
    pub limit: Option<i64>,
}

/// List users (search by email substring).
#[utoipa::path(
    get,
    path = "/api/admin/users",
    responses((status = 200, description = "Users", body = Vec<AdminUserRow>))
)]
pub async fn list_users(
    State(state): State<AdminState>,
    Query(q): Query<ListUsersQuery>,
) -> ApiResult<Json<Vec<AdminUserRow>>> {
    let limit = q.limit.unwrap_or(100).min(500);
    let pattern = format!("%{}%", q.q.clone().unwrap_or_default());
    let rows: Vec<AdminUserRow> = sqlx::query_as(
        "SELECT id, email, role, created_at FROM users
          WHERE email ILIKE $1
          ORDER BY created_at DESC
          LIMIT $2",
    )
    .bind(pattern)
    .bind(limit)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct SetRoleRequest {
    /// "student" | "admin"
    pub role: String,
}

/// Promote/demote a user's role.
#[utoipa::path(
    post,
    path = "/api/admin/users/{id}/role",
    request_body = SetRoleRequest,
    responses((status = 200, description = "Role updated"))
)]
pub async fn set_user_role(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
    Json(body): Json<SetRoleRequest>,
) -> ApiResult<Json<serde_json::Value>> {
    if !matches!(body.role.as_str(), "student" | "admin") {
        return Err(ApiError::BadRequest("role must be student or admin".into()));
    }
    let updated = sqlx::query("UPDATE users SET role = $2, updated_at = now() WHERE id = $1")
        .bind(id)
        .bind(&body.role)
        .execute(&state.db)
        .await?;
    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }
    Ok(Json(serde_json::json!({ "id": id, "role": body.role })))
}

// ------------------------------------------------------------------ recordings

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct AdminRecordingRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub chapter_id: Uuid,
    pub status: String,
    pub error: Option<String>,
    pub duration_secs: Option<i32>,
    /// Storage key (R2 object key or local file name). The admin uses this
    /// to fetch the audio bytes for the moderation player.
    pub storage_path: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct ListRecordingsQuery {
    pub status: Option<String>,
    pub limit: Option<i64>,
}

/// Monitor recording processing status / sync health.
#[utoipa::path(
    get,
    path = "/api/admin/recordings",
    responses((status = 200, description = "Recordings", body = Vec<AdminRecordingRow>))
)]
pub async fn list_recordings(
    State(state): State<AdminState>,
    Query(q): Query<ListRecordingsQuery>,
) -> ApiResult<Json<Vec<AdminRecordingRow>>> {
    let limit = q.limit.unwrap_or(100).min(500);
    let rows: Vec<AdminRecordingRow> = if let Some(status) = q.status {
        sqlx::query_as(
            "SELECT id, user_id, chapter_id, status, error, duration_secs, storage_path, created_at, updated_at
               FROM recordings WHERE status = $1 ORDER BY updated_at DESC LIMIT $2",
        )
        .bind(status)
        .bind(limit)
        .fetch_all(&state.db)
        .await?
    } else {
        sqlx::query_as(
            "SELECT id, user_id, chapter_id, status, error, duration_secs, storage_path, created_at, updated_at
               FROM recordings ORDER BY updated_at DESC LIMIT $1",
        )
        .bind(limit)
        .fetch_all(&state.db)
        .await?
    };
    Ok(Json(rows))
}

// ----------------------------------------------------------- recording detail

#[derive(Debug, Serialize, ToSchema)]
pub struct AudioMeta {
    /// MIME type derived from the storage key extension.
    pub mime: String,
    /// Size in bytes; 0 if unknown.
    pub size: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct TranscriptRow {
    pub provider: String,
    pub content: String,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct StudySummaryRow {
    pub id: Uuid,
    pub status: String,
    pub content_md: String,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct StudyExercisesRow {
    pub id: Uuid,
    pub status: String,
    pub items: serde_json::Value,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct StudyQuizzesRow {
    pub id: Uuid,
    pub status: String,
    pub questions: serde_json::Value,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct RecordingDetailDto {
    pub recording: AdminRecordingRow,
    pub user_email: Option<String>,
    pub chapter_title: Option<String>,
    pub audio: AudioMeta,
    pub transcript: Option<TranscriptRow>,
    pub summary: Option<StudySummaryRow>,
    pub exercises: Option<StudyExercisesRow>,
    pub quizzes: Option<StudyQuizzesRow>,
}

async fn load_admin_recording(state: &AdminState, id: Uuid) -> ApiResult<AdminRecordingRow> {
    sqlx::query_as(
        "SELECT id, user_id, chapter_id, status, error, duration_secs, storage_path, created_at, updated_at
           FROM recordings WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?
    .ok_or(ApiError::NotFound)
}

/// Full record of a recording: metadata + transcript + study material + audio
/// metadata. Admin can see content even before it has been moderated.
#[utoipa::path(
    get,
    path = "/api/admin/recordings/{id}",
    responses((status = 200, description = "Recording detail", body = RecordingDetailDto))
)]
pub async fn recording_detail(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<RecordingDetailDto>> {
    let rec = load_admin_recording(&state, id).await?;

    let user_email: Option<String> =
        sqlx::query_scalar("SELECT email FROM users WHERE id = $1")
            .bind(rec.user_id)
            .fetch_optional(&state.db)
            .await?;

    let chapter_title: Option<String> =
        sqlx::query_scalar("SELECT title FROM chapters WHERE id = $1")
            .bind(rec.chapter_id)
            .fetch_optional(&state.db)
            .await?;

    let transcript: Option<TranscriptRow> = sqlx::query_as(
        "SELECT provider, content FROM transcripts WHERE recording_id = $1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;

    let summary: Option<StudySummaryRow> = sqlx::query_as(
        "SELECT id, status, content_md FROM summaries
          WHERE recording_id = $1 ORDER BY created_at DESC LIMIT 1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;

    let exercises: Option<StudyExercisesRow> = sqlx::query_as(
        "SELECT id, status, items FROM exercises
          WHERE recording_id = $1 ORDER BY created_at DESC LIMIT 1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;

    let quizzes: Option<StudyQuizzesRow> = sqlx::query_as(
        "SELECT id, status, questions FROM quizzes
          WHERE recording_id = $1 ORDER BY created_at DESC LIMIT 1",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;

    // For audio size we read the bytes; for very large files this could be
    // expensive — the moderation UI only needs the MIME + a working play URL.
    // We keep size for the UI badge and to surface storage anomalies.
    let size = match state.storage.read(&storage_path_for_audio(&rec)).await {
        Ok(bytes) => bytes.len() as i64,
        Err(_) => 0,
    };
    let mime = mime_for_key(&storage_path_for_audio(&rec)).to_string();

    Ok(Json(RecordingDetailDto {
        recording: rec,
        user_email,
        chapter_title,
        audio: AudioMeta { mime, size },
        transcript,
        summary,
        exercises,
        quizzes,
    }))
}

/// Stream the raw audio bytes. The admin UI fetches this with the Bearer
/// token and creates a Blob URL for the `<audio>` element.
#[utoipa::path(
    get,
    path = "/api/admin/recordings/{id}/audio",
    responses(
        (status = 200, description = "Audio bytes", content_type = "audio/*"),
        (status = 404, description = "Recording missing or audio unreadable"),
    )
)]
pub async fn recording_audio(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let rec = load_admin_recording(&state, id)
        .await
        .map_err(|e| ApiError::Internal(anyhow::anyhow!(e.to_string())))?;
    let key = storage_path_for_audio(&rec);
    let bytes = state
        .storage
        .read(&key)
        .await
        .map_err(|e| ApiError::Internal(anyhow::anyhow!(e.to_string())))?;
    let mime = mime_for_key(&key);

    let total = bytes.len() as u64;

    // Always advertise range support — the browser needs this to know it
    // can request a partial response for `<audio>` seek / streaming.
    let mut resp_headers = HeaderMap::new();
    resp_headers.insert(header::ACCEPT_RANGES, HeaderValue::from_static("bytes"));
    resp_headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("private, max-age=300"));

    // Parse `Range: bytes=START-END` (per RFC 9110). We accept:
    //   bytes=START-      (open-ended: bytes START .. total)
    //   bytes=START-END   (closed)
    //   bytes=-SUFFIX     (last N bytes — not used by audio, but cheap)
    let range = headers
        .get(header::RANGE)
        .and_then(|v| v.to_str().ok())
        .and_then(parse_bytes_range);

    match range {
        Some((start, end_inclusive)) if start < total => {
            let end = end_inclusive.min(total - 1);
            let len = end - start + 1;
            let mut header = format!("bytes {start}-{end}/{total}");
            if header.len() > 64 {
                // sanity-check formatting
                header.truncate(64);
            }
            resp_headers.insert(header::CONTENT_TYPE, HeaderValue::from_static(mime));
            resp_headers.insert(
                header::CONTENT_LENGTH,
                HeaderValue::from_str(&len.to_string()).unwrap(),
            );
            resp_headers.insert(
                header::CONTENT_RANGE,
                HeaderValue::from_str(&format!("bytes {start}-{end}/{total}")).unwrap(),
            );
            let body = bytes.get(start as usize..=end as usize).unwrap_or(&[]).to_vec();
            tracing::debug!(
                recording_id = %id,
                key = %key,
                start,
                end,
                total,
                "serving partial audio content"
            );
            Ok(range_response(StatusCode::PARTIAL_CONTENT, body, resp_headers))
        }
        // bytes=-SUFFIX: last N bytes. Not useful for audio but easy.
        Some((u64::MAX, _)) => {
            let n = total.min(0);
            let body = bytes.get(total as usize - n as usize..).unwrap_or(&[]).to_vec();
            resp_headers.insert(header::CONTENT_TYPE, HeaderValue::from_static(mime));
            resp_headers.insert(
                header::CONTENT_LENGTH,
                HeaderValue::from_str(&body.len().to_string()).unwrap(),
            );
            Ok(range_response(StatusCode::PARTIAL_CONTENT, body, resp_headers))
        }
        // Out-of-range or malformed: ignore Range, serve the whole file.
        _ => {
            resp_headers.insert(header::CONTENT_TYPE, HeaderValue::from_static(mime));
            resp_headers.insert(
                header::CONTENT_LENGTH,
                HeaderValue::from(total),
            );
            Ok(range_response(StatusCode::OK, bytes, resp_headers))
        }
    }
}

fn range_response(
    status: StatusCode,
    bytes: Vec<u8>,
    headers: HeaderMap,
) -> Response {
    let mut resp = Response::new(Body::from(bytes));
    *resp.status_mut() = status;
    resp.headers_mut().extend(headers);
    resp
}

/// Parse a `Range: bytes=START-END` header value into `(start, end_inclusive)`.
///
/// Returns `Some((u64::MAX, 0))` for suffix ranges (`bytes=-N`),
/// `None` for malformed input.
fn parse_bytes_range(value: &str) -> Option<(u64, u64)> {
    let rest = value.trim().strip_prefix("bytes=")?;
    let (start_s, end_s) = rest.split_once('-')?;
    if start_s.is_empty() {
        // bytes=-N suffix form
        let n: u64 = end_s.parse().ok()?;
        Some((u64::MAX, n))
    } else {
        let start: u64 = start_s.parse().ok()?;
        let end: u64 = if end_s.is_empty() {
            u64::MAX
        } else {
            end_s.parse().ok()?
        };
        Some((start, end))
    }
}

/// Map a storage key to a MIME type we can play in the browser.
fn mime_for_key(key: &str) -> &'static str {
    let lower = key.to_ascii_lowercase();
    if lower.ends_with(".m4a") || lower.ends_with(".aac") {
        "audio/mp4"
    } else if lower.ends_with(".mp3") {
        "audio/mpeg"
    } else if lower.ends_with(".wav") {
        "audio/wav"
    } else if lower.ends_with(".ogg") {
        "audio/ogg"
    } else if lower.ends_with(".webm") {
        "audio/webm"
    } else if lower.ends_with(".flac") {
        "audio/flac"
    } else {
        "application/octet-stream"
    }
}

fn storage_path_for_audio(rec: &AdminRecordingRow) -> String {
    // The recordings table stores the storage key (R2 path or local filename).
    // We use the same `read()` entry point as the AI pipeline.
    rec.storage_path.clone()
}

// ------------------------------------------------------------------ moderation

#[derive(Debug, Serialize, ToSchema)]
pub struct PendingItem {
    pub id: Uuid,
    /// "summary" | "exercises" | "quiz"
    pub kind: String,
    pub recording_id: Uuid,
    pub chapter_id: Uuid,
    pub created_at: DateTime<Utc>,
}

/// Everything awaiting human review.
#[utoipa::path(
    get,
    path = "/api/admin/moderation",
    responses((status = 200, description = "Pending items", body = Vec<PendingItem>))
)]
pub async fn list_pending_moderation(
    State(state): State<AdminState>,
) -> ApiResult<Json<Vec<PendingItem>>> {
    let mut items = Vec::new();

    #[derive(sqlx::FromRow)]
    struct Row {
        id: Uuid,
        recording_id: Uuid,
        chapter_id: Uuid,
        created_at: DateTime<Utc>,
    }

    let summaries: Vec<Row> = sqlx::query_as(
        "SELECT id, recording_id, chapter_id, created_at FROM summaries
          WHERE status = 'pending_review' ORDER BY created_at LIMIT 200",
    )
    .fetch_all(&state.db)
    .await?;
    for r in summaries {
        items.push(PendingItem { id: r.id, kind: "summary".into(), recording_id: r.recording_id, chapter_id: r.chapter_id, created_at: r.created_at });
    }

    let exercises: Vec<Row> = sqlx::query_as(
        "SELECT id, recording_id, chapter_id, created_at FROM exercises
          WHERE status = 'pending_review' ORDER BY created_at LIMIT 200",
    )
    .fetch_all(&state.db)
    .await?;
    for r in exercises {
        items.push(PendingItem { id: r.id, kind: "exercises".into(), recording_id: r.recording_id, chapter_id: r.chapter_id, created_at: r.created_at });
    }

    let quizzes: Vec<Row> = sqlx::query_as(
        "SELECT id, recording_id, chapter_id, created_at FROM quizzes
          WHERE status = 'pending_review' ORDER BY created_at LIMIT 200",
    )
    .fetch_all(&state.db)
    .await?;
    for r in quizzes {
        items.push(PendingItem { id: r.id, kind: "quiz".into(), recording_id: r.recording_id, chapter_id: r.chapter_id, created_at: r.created_at });
    }

    items.sort_by_key(|i| i.created_at);
    Ok(Json(items))
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct ModerationDecision {
    /// "approved" | "rejected"
    pub decision: String,
}

fn validate_decision(d: &str) -> ApiResult<&'static str> {
    match d {
        "approved" => Ok("approved"),
        "rejected" => Ok("rejected"),
        _ => Err(ApiError::BadRequest("decision must be approved or rejected".into())),
    }
}

/// Approve/reject a generated summary.
#[utoipa::path(
    post,
    path = "/api/admin/moderation/summaries/{id}",
    request_body = ModerationDecision,
    responses((status = 200, description = "Decision recorded"))
)]
pub async fn decide_summary(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
    Json(body): Json<ModerationDecision>,
) -> ApiResult<Json<serde_json::Value>> {
    let decision = validate_decision(&body.decision)?;
    apply_decision(&state, "summaries", id, decision).await
}

/// Approve/reject generated exercises.
#[utoipa::path(
    post,
    path = "/api/admin/moderation/exercises/{id}",
    request_body = ModerationDecision,
    responses((status = 200, description = "Decision recorded"))
)]
pub async fn decide_exercises(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
    Json(body): Json<ModerationDecision>,
) -> ApiResult<Json<serde_json::Value>> {
    let decision = validate_decision(&body.decision)?;
    apply_decision(&state, "exercises", id, decision).await
}

/// Approve/reject a generated quiz.
#[utoipa::path(
    post,
    path = "/api/admin/moderation/quizzes/{id}",
    request_body = ModerationDecision,
    responses((status = 200, description = "Decision recorded"))
)]
pub async fn decide_quiz(
    State(state): State<AdminState>,
    Path(id): Path<Uuid>,
    Json(body): Json<ModerationDecision>,
) -> ApiResult<Json<serde_json::Value>> {
    let decision = validate_decision(&body.decision)?;
    apply_decision(&state, "quizzes", id, decision).await
}

async fn apply_decision(
    state: &AdminState,
    table: &str,
    id: Uuid,
    decision: &'static str,
) -> ApiResult<Json<serde_json::Value>> {
    // Bump sync_version so a fresh approval shows up in clients' next delta pull.
    let query = format!(
        "UPDATE {table} SET status = $2, updated_at = now(), sync_version = nextval('sync_version_seq')
          WHERE id = $1 AND status = 'pending_review'"
    );
    let updated = sqlx::query(&query).bind(id).bind(decision).execute(&state.db).await?;
    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }
    Ok(Json(serde_json::json!({ "id": id, "status": decision })))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mime_for_known_audio_extensions() {
        assert_eq!(mime_for_key("lesson.m4a"), "audio/mp4");
        assert_eq!(mime_for_key("lesson.AAC"), "audio/mp4");
        assert_eq!(mime_for_key("song.mp3"), "audio/mpeg");
        assert_eq!(mime_for_key("noise.wav"), "audio/wav");
        assert_eq!(mime_for_key("clip.ogg"), "audio/ogg");
        assert_eq!(mime_for_key("recording.webm"), "audio/webm");
        assert_eq!(mime_for_key("hi-fi.flac"), "audio/flac");
    }

    #[test]
    fn mime_for_unknown_extension_falls_back_to_octet_stream() {
        assert_eq!(mime_for_key("recording.txt"), "application/octet-stream");
        assert_eq!(mime_for_key("recording"), "application/octet-stream");
        assert_eq!(mime_for_key(""), "application/octet-stream");
    }
}