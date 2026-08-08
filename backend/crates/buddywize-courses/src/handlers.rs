//! Agenda / course / lesson / chapter handlers (delta-sync + idempotent upserts).

use axum::{
    extract::{Path, Query, State},
    Json,
};
use buddywize_auth::middleware::AuthUser;
use buddywize_core::{ApiError, ApiResult, SinceQuery};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::{AgendaRow, ChapterRow, CourseRow, CourseState, LessonRow};

const PAGE_LIMIT: i64 = 500;

// ------------------------------------------------------------------------ DTO

#[derive(Debug, Deserialize, ToSchema)]
pub struct AgendaUpsert {
    pub client_uuid: Uuid,
    pub title: String,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub starts_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub ends_at: Option<DateTime<Utc>>,
    /// Set true to soft-delete (tombstone) the item.
    #[serde(default)]
    pub deleted: bool,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct CourseUpsert {
    pub client_uuid: Uuid,
    pub title: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub deleted: bool,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct LessonUpsert {
    pub client_uuid: Uuid,
    /// Parent course, referenced by its client UUID (survives reordering of pushes).
    pub course_client_uuid: Uuid,
    pub title: String,
    #[serde(default)]
    pub position: i32,
    #[serde(default)]
    pub deleted: bool,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct ChapterUpsert {
    pub client_uuid: Uuid,
    /// Parent lesson, referenced by its client UUID.
    pub lesson_client_uuid: Uuid,
    pub title: String,
    #[serde(default)]
    pub position: i32,
    #[serde(default)]
    pub deleted: bool,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct DeltaResponse<T: Serialize> {
    pub items: Vec<T>,
    /// Highest sync_version in this batch; pass back as `since` next time.
    pub cursor: i64,
    pub has_more: bool,
}

fn cursor_of(sync_versions: &[i64], since: Option<i64>) -> (i64, bool) {
    let max = sync_versions.iter().copied().max().unwrap_or(since.unwrap_or(0));
    (max, sync_versions.len() as i64 >= PAGE_LIMIT)
}

// ---------------------------------------------------------------------- agenda

/// Delta-sync agenda items.
#[utoipa::path(
    get,
    path = "/api/agenda",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Agenda delta", body = DeltaResponse<AgendaRow>))
)]
pub async fn list_agenda(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<DeltaResponse<AgendaRow>>> {
    let rows: Vec<AgendaRow> = sqlx::query_as(
        "SELECT * FROM agenda_items
          WHERE user_id = $1 AND ($2::bigint IS NULL OR sync_version > $2)
          ORDER BY sync_version
          LIMIT $3",
    )
    .bind(user.sub)
    .bind(q.since)
    .bind(PAGE_LIMIT)
    .fetch_all(&state.db)
    .await?;

    let versions: Vec<i64> = rows.iter().map(|r| r.sync_version).collect();
    let (cursor, has_more) = cursor_of(&versions, q.since);
    Ok(Json(DeltaResponse { items: rows, cursor, has_more }))
}

/// Idempotent create/update of an agenda item keyed by client UUID.
#[utoipa::path(
    post,
    path = "/api/agenda",
    request_body = AgendaUpsert,
    responses((status = 200, description = "Upserted item", body = AgendaRow))
)]
pub async fn upsert_agenda(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Json(body): Json<AgendaUpsert>,
) -> ApiResult<Json<AgendaRow>> {
    if body.title.trim().is_empty() {
        return Err(ApiError::BadRequest("title is required".into()));
    }
    let row: AgendaRow = sqlx::query_as(
        "INSERT INTO agenda_items (user_id, client_uuid, title, notes, starts_at, ends_at, deleted_at)
         VALUES ($1, $2, $3, $4, $5, $6, CASE WHEN $7 THEN now() ELSE NULL END)
         ON CONFLICT (client_uuid) DO UPDATE SET
            title = EXCLUDED.title,
            notes = EXCLUDED.notes,
            starts_at = EXCLUDED.starts_at,
            ends_at = EXCLUDED.ends_at,
            deleted_at = EXCLUDED.deleted_at,
            updated_at = now(),
            sync_version = nextval('sync_version_seq')
         WHERE agenda_items.user_id = $1
         RETURNING *",
    )
    .bind(user.sub)
    .bind(body.client_uuid)
    .bind(&body.title)
    .bind(&body.notes)
    .bind(body.starts_at)
    .bind(body.ends_at)
    .bind(body.deleted)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

/// Soft-delete an agenda item (tombstone syncs to other devices).
#[utoipa::path(
    delete,
    path = "/api/agenda/{client_uuid}",
    responses((status = 200, description = "Deleted", body = AgendaRow))
)]
pub async fn delete_agenda(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(client_uuid): Path<Uuid>,
) -> ApiResult<Json<AgendaRow>> {
    let row: AgendaRow = sqlx::query_as(
        "UPDATE agenda_items
            SET deleted_at = now(), updated_at = now(), sync_version = nextval('sync_version_seq')
          WHERE client_uuid = $1 AND user_id = $2 AND deleted_at IS NULL
          RETURNING *",
    )
    .bind(client_uuid)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

// ---------------------------------------------------------------------- courses

/// Delta-sync courses.
#[utoipa::path(
    get,
    path = "/api/courses",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Course delta", body = DeltaResponse<CourseRow>))
)]
pub async fn list_courses(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<DeltaResponse<CourseRow>>> {
    let rows: Vec<CourseRow> = sqlx::query_as(
        "SELECT * FROM courses
          WHERE user_id = $1 AND ($2::bigint IS NULL OR sync_version > $2)
          ORDER BY sync_version
          LIMIT $3",
    )
    .bind(user.sub)
    .bind(q.since)
    .bind(PAGE_LIMIT)
    .fetch_all(&state.db)
    .await?;

    let versions: Vec<i64> = rows.iter().map(|r| r.sync_version).collect();
    let (cursor, has_more) = cursor_of(&versions, q.since);
    Ok(Json(DeltaResponse { items: rows, cursor, has_more }))
}

/// Idempotent create/update of a course.
#[utoipa::path(
    post,
    path = "/api/courses",
    request_body = CourseUpsert,
    responses((status = 200, description = "Upserted course", body = CourseRow))
)]
pub async fn upsert_course(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Json(body): Json<CourseUpsert>,
) -> ApiResult<Json<CourseRow>> {
    if body.title.trim().is_empty() {
        return Err(ApiError::BadRequest("title is required".into()));
    }
    let row: CourseRow = sqlx::query_as(
        "INSERT INTO courses (user_id, client_uuid, title, description, deleted_at)
         VALUES ($1, $2, $3, $4, CASE WHEN $5 THEN now() ELSE NULL END)
         ON CONFLICT (client_uuid) DO UPDATE SET
            title = EXCLUDED.title,
            description = EXCLUDED.description,
            deleted_at = EXCLUDED.deleted_at,
            updated_at = now(),
            sync_version = nextval('sync_version_seq')
         WHERE courses.user_id = $1
         RETURNING *",
    )
    .bind(user.sub)
    .bind(body.client_uuid)
    .bind(&body.title)
    .bind(&body.description)
    .bind(body.deleted)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

/// Soft-delete a course (cascades to lessons/chapters on hard delete only).
#[utoipa::path(
    delete,
    path = "/api/courses/{client_uuid}",
    responses((status = 200, description = "Deleted", body = CourseRow))
)]
pub async fn delete_course(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(client_uuid): Path<Uuid>,
) -> ApiResult<Json<CourseRow>> {
    let row: CourseRow = sqlx::query_as(
        "UPDATE courses
            SET deleted_at = now(), updated_at = now(), sync_version = nextval('sync_version_seq')
          WHERE client_uuid = $1 AND user_id = $2 AND deleted_at IS NULL
          RETURNING *",
    )
    .bind(client_uuid)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

// ---------------------------------------------------------------------- lessons

/// Delta-sync lessons, optionally filtered by course.
#[utoipa::path(
    get,
    path = "/api/lessons",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Lesson delta", body = DeltaResponse<LessonRow>))
)]
pub async fn list_lessons(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<DeltaResponse<LessonRow>>> {
    let rows: Vec<LessonRow> = sqlx::query_as(
        "SELECT l.* FROM lessons l
           JOIN courses c ON c.id = l.course_id
          WHERE c.user_id = $1 AND ($2::bigint IS NULL OR l.sync_version > $2)
          ORDER BY l.sync_version
          LIMIT $3",
    )
    .bind(user.sub)
    .bind(q.since)
    .bind(PAGE_LIMIT)
    .fetch_all(&state.db)
    .await?;

    let versions: Vec<i64> = rows.iter().map(|r| r.sync_version).collect();
    let (cursor, has_more) = cursor_of(&versions, q.since);
    Ok(Json(DeltaResponse { items: rows, cursor, has_more }))
}

/// Idempotent create/update of a lesson; parent referenced by client UUID.
#[utoipa::path(
    post,
    path = "/api/lessons",
    request_body = LessonUpsert,
    responses((status = 200, description = "Upserted lesson", body = LessonRow))
)]
pub async fn upsert_lesson(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Json(body): Json<LessonUpsert>,
) -> ApiResult<Json<LessonRow>> {
    if body.title.trim().is_empty() {
        return Err(ApiError::BadRequest("title is required".into()));
    }
    let course_id: Uuid = sqlx::query_scalar(
        "SELECT id FROM courses WHERE client_uuid = $1 AND user_id = $2",
    )
    .bind(body.course_client_uuid)
    .bind(user.sub)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| ApiError::BadRequest("parent course not found; push it first".into()))?;

    let row: LessonRow = sqlx::query_as(
        "INSERT INTO lessons (course_id, client_uuid, title, position, deleted_at)
         VALUES ($1, $2, $3, $4, CASE WHEN $5 THEN now() ELSE NULL END)
         ON CONFLICT (client_uuid) DO UPDATE SET
            course_id = EXCLUDED.course_id,
            title = EXCLUDED.title,
            position = EXCLUDED.position,
            deleted_at = EXCLUDED.deleted_at,
            updated_at = now(),
            sync_version = nextval('sync_version_seq')
         WHERE EXISTS (
            SELECT 1 FROM courses c
             WHERE c.id = lessons.course_id AND c.user_id = $6
         )
         RETURNING *",
    )
    .bind(course_id)
    .bind(body.client_uuid)
    .bind(&body.title)
    .bind(body.position)
    .bind(body.deleted)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

/// Soft-delete a lesson.
#[utoipa::path(
    delete,
    path = "/api/lessons/{client_uuid}",
    responses((status = 200, description = "Deleted", body = LessonRow))
)]
pub async fn delete_lesson(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(client_uuid): Path<Uuid>,
) -> ApiResult<Json<LessonRow>> {
    let row: LessonRow = sqlx::query_as(
        "UPDATE lessons
            SET deleted_at = now(), updated_at = now(), sync_version = nextval('sync_version_seq')
          WHERE client_uuid = $1
            AND deleted_at IS NULL
            AND EXISTS (SELECT 1 FROM courses c WHERE c.id = lessons.course_id AND c.user_id = $2)
          RETURNING *",
    )
    .bind(client_uuid)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

// --------------------------------------------------------------------- chapters

/// Delta-sync chapters.
#[utoipa::path(
    get,
    path = "/api/chapters",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Chapter delta", body = DeltaResponse<ChapterRow>))
)]
pub async fn list_chapters(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<DeltaResponse<ChapterRow>>> {
    let rows: Vec<ChapterRow> = sqlx::query_as(
        "SELECT ch.* FROM chapters ch
           JOIN lessons l ON l.id = ch.lesson_id
           JOIN courses c ON c.id = l.course_id
          WHERE c.user_id = $1 AND ($2::bigint IS NULL OR ch.sync_version > $2)
          ORDER BY ch.sync_version
          LIMIT $3",
    )
    .bind(user.sub)
    .bind(q.since)
    .bind(PAGE_LIMIT)
    .fetch_all(&state.db)
    .await?;

    let versions: Vec<i64> = rows.iter().map(|r| r.sync_version).collect();
    let (cursor, has_more) = cursor_of(&versions, q.since);
    Ok(Json(DeltaResponse { items: rows, cursor, has_more }))
}

/// Idempotent create/update of a chapter; parent referenced by client UUID.
#[utoipa::path(
    post,
    path = "/api/chapters",
    request_body = ChapterUpsert,
    responses((status = 200, description = "Upserted chapter", body = ChapterRow))
)]
pub async fn upsert_chapter(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Json(body): Json<ChapterUpsert>,
) -> ApiResult<Json<ChapterRow>> {
    if body.title.trim().is_empty() {
        return Err(ApiError::BadRequest("title is required".into()));
    }
    let lesson_id: Uuid = sqlx::query_scalar(
        "SELECT l.id FROM lessons l
           JOIN courses c ON c.id = l.course_id
          WHERE l.client_uuid = $1 AND c.user_id = $2",
    )
    .bind(body.lesson_client_uuid)
    .bind(user.sub)
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| ApiError::BadRequest("parent lesson not found; push it first".into()))?;

    let row: ChapterRow = sqlx::query_as(
        "INSERT INTO chapters (lesson_id, client_uuid, title, position, deleted_at)
         VALUES ($1, $2, $3, $4, CASE WHEN $5 THEN now() ELSE NULL END)
         ON CONFLICT (client_uuid) DO UPDATE SET
            lesson_id = EXCLUDED.lesson_id,
            title = EXCLUDED.title,
            position = EXCLUDED.position,
            deleted_at = EXCLUDED.deleted_at,
            updated_at = now(),
            sync_version = nextval('sync_version_seq')
         WHERE EXISTS (
            SELECT 1 FROM lessons l
             JOIN courses c ON c.id = l.course_id
             WHERE l.id = chapters.lesson_id AND c.user_id = $6
         )
         RETURNING *",
    )
    .bind(lesson_id)
    .bind(body.client_uuid)
    .bind(&body.title)
    .bind(body.position)
    .bind(body.deleted)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

/// Soft-delete a chapter.
#[utoipa::path(
    delete,
    path = "/api/chapters/{client_uuid}",
    responses((status = 200, description = "Deleted", body = ChapterRow))
)]
pub async fn delete_chapter(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(client_uuid): Path<Uuid>,
) -> ApiResult<Json<ChapterRow>> {
    let row: ChapterRow = sqlx::query_as(
        "UPDATE chapters
            SET deleted_at = now(), updated_at = now(), sync_version = nextval('sync_version_seq')
          WHERE client_uuid = $1
            AND deleted_at IS NULL
            AND EXISTS (
                SELECT 1 FROM lessons l
                  JOIN courses c ON c.id = l.course_id
                 WHERE l.id = chapters.lesson_id AND c.user_id = $2
            )
          RETURNING *",
    )
    .bind(client_uuid)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

// ---------------------------------------------------------------- agenda ingestion

/// Multipart upload of an agenda photo. Returns the parsed drafts
/// for the mobile to display in a confirmation screen before saving.
#[utoipa::path(
    post,
    path = "/api/agenda/parse",
    request_body(content = String, content_type = "image/jpeg"),
    responses((status = 200, description = "Parsed drafts", body = Vec<buddywize_ai::providers::AgendaItemDraft>))
)]
pub async fn parse_agenda_image(
    State(state): State<crate::CourseState>,
    AuthUser(_user): AuthUser,
    mut multipart: axum::extract::Multipart,
) -> ApiResult<Json<Vec<buddywize_ai::providers::AgendaItemDraft>>> {
    let mut bytes: Option<Vec<u8>> = None;
    while let Some(field) = multipart.next_field().await.map_err(|e| {
        ApiError::BadRequest(format!("invalid multipart payload: {e}"))
    })? {
        if field.name() == Some("image") {
            bytes = Some(
                field
                    .bytes()
                    .await
                    .map_err(|e| ApiError::BadRequest(format!("failed to read image: {e}")))?
                    .to_vec(),
            );
            break;
        }
    }
    let bytes = bytes.ok_or_else(|| ApiError::BadRequest("missing 'image' field".into()))?;
    let drafts = state
        .agenda_parser
        .parse(&bytes)
        .await
        .map_err(ApiError::Internal)?;
    tracing::info!(
        drafts = drafts.len(),
        provider = state.agenda_parser.name(),
        "agenda photo parsed"
    );
    Ok(Json(drafts))
}

/// Import from an iCal feed. Accepts either a URL (server fetches it,
/// 10 s timeout) or a raw `text` payload the mobile already fetched.
#[derive(Debug, Deserialize, ToSchema)]
pub struct IcalImportRequest {
    /// Either `url` or `text` must be present.
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub text: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/agenda/ical",
    request_body = IcalImportRequest,
    responses((status = 200, description = "Parsed drafts", body = Vec<buddywize_ai::providers::AgendaItemDraft>))
)]
pub async fn import_ical(
    State(_state): State<crate::CourseState>,
    AuthUser(_user): AuthUser,
    Json(body): Json<IcalImportRequest>,
) -> ApiResult<Json<Vec<buddywize_ai::providers::AgendaItemDraft>>> {
    let text = match (body.url, body.text) {
        (Some(url), None) => {
            fetch_url(&url).await.map_err(|e| {
                ApiError::BadRequest(format!("failed to fetch iCal URL '{url}': {e}"))
            })?
        }
        (None, Some(text)) => text,
        (Some(_), Some(_)) => {
            return Err(ApiError::BadRequest(
                "provide either 'url' or 'text', not both".into(),
            ))
        }
        (None, None) => return Err(ApiError::BadRequest("missing 'url' or 'text'".into())),
    };
    let drafts = buddywize_ai::ical::parse_ical(&text).map_err(ApiError::Internal)?;
    tracing::info!(drafts = drafts.len(), "iCal parsed");
    Ok(Json(drafts))
}

async fn fetch_url(url: &str) -> anyhow::Result<String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()?;
    let resp = client.get(url).send().await?;
    if !resp.status().is_success() {
        anyhow::bail!("HTTP {}", resp.status());
    }
    Ok(resp.text().await?)
}
