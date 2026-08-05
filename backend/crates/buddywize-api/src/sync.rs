//! Lightweight "what changed?" probe so clients can decide whether to run a
//! full pull. Returns counts of rows newer than the client's cursor.

use axum::{
    extract::{Query, State},
    Json,
};
use buddywize_auth::middleware::AuthUser;
use buddywize_core::{ApiResult, SinceQuery};
use serde::Serialize;
use sqlx::PgPool;
use utoipa::ToSchema;

#[derive(Clone)]
pub struct SyncState {
    pub db: PgPool,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct SyncStatusResponse {
    pub agenda_changed: i64,
    pub courses_changed: i64,
    pub lessons_changed: i64,
    pub chapters_changed: i64,
    pub recordings_changed: i64,
    pub study_changed: i64,
    /// True when there is anything new for the client.
    pub has_changes: bool,
}

/// Cheap delta probe across all resource types.
#[utoipa::path(
    get,
    path = "/api/sync/status",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Change counts", body = SyncStatusResponse))
)]
pub async fn status(
    State(state): State<SyncState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<SyncStatusResponse>> {
    #[derive(sqlx::FromRow)]
    struct Counts {
        agenda: i64,
        courses: i64,
        lessons: i64,
        chapters: i64,
        recordings: i64,
        study: i64,
    }

    let counts: Counts = sqlx::query_as(
        "SELECT
           (SELECT COUNT(*) FROM agenda_items a
             WHERE a.user_id = $1 AND ($2::bigint IS NULL OR a.sync_version > $2)) AS agenda,
           (SELECT COUNT(*) FROM courses c
             WHERE c.user_id = $1 AND ($2::bigint IS NULL OR c.sync_version > $2)) AS courses,
           (SELECT COUNT(*) FROM lessons l
             JOIN courses c ON c.id = l.course_id
             WHERE c.user_id = $1 AND ($2::bigint IS NULL OR l.sync_version > $2)) AS lessons,
           (SELECT COUNT(*) FROM chapters ch
             JOIN lessons l ON l.id = ch.lesson_id
             JOIN courses c ON c.id = l.course_id
             WHERE c.user_id = $1 AND ($2::bigint IS NULL OR ch.sync_version > $2)) AS chapters,
           (SELECT COUNT(*) FROM recordings r
             WHERE r.user_id = $1 AND ($2::bigint IS NULL OR r.sync_version > $2)) AS recordings,
           (SELECT COUNT(*) FROM summaries s
             JOIN recordings r ON r.id = s.recording_id
             WHERE r.user_id = $1 AND s.status = 'approved'
               AND ($2::bigint IS NULL OR s.sync_version > $2)) AS study",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_one(&state.db)
    .await?;

    let has_changes = counts.agenda
        + counts.courses
        + counts.lessons
        + counts.chapters
        + counts.recordings
        + counts.study
        > 0;

    Ok(Json(SyncStatusResponse {
        agenda_changed: counts.agenda,
        courses_changed: counts.courses,
        lessons_changed: counts.lessons,
        chapters_changed: counts.chapters,
        recordings_changed: counts.recordings,
        study_changed: counts.study,
        has_changes,
    }))
}
