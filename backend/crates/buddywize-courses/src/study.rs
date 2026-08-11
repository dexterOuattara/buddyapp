//! Approved study-material delta feed (summaries, exercises, quizzes) and
//! quiz attempt history. Only `approved` content is delivered to students —
//! admin moderation happens upstream (see buddywize-admin).

use axum::{
    extract::{Path, Query, State},
    Json,
};
use buddywize_auth::middleware::AuthUser;
use buddywize_core::{ApiResult, SinceQuery};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::CourseState;

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct SummaryDto {
    pub id: Uuid,
    pub chapter_id: Uuid,
    pub recording_id: Uuid,
    pub generation_id: Option<Uuid>,
    pub content_md: String,
    pub structured_content: Option<serde_json::Value>,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct ExercisesDto {
    pub id: Uuid,
    pub chapter_id: Uuid,
    pub recording_id: Uuid,
    pub generation_id: Option<Uuid>,
    pub items: serde_json::Value,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct QuizDto {
    pub id: Uuid,
    pub chapter_id: Uuid,
    pub recording_id: Uuid,
    pub generation_id: Option<Uuid>,
    pub questions: serde_json::Value,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct TranscriptDto {
    pub id: Uuid,
    pub recording_id: Uuid,
    pub content: String,
    pub language: Option<String>,
    pub segments: serde_json::Value,
    pub sync_version: i64,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct StudyDelta {
    pub transcripts: Vec<TranscriptDto>,
    pub summaries: Vec<SummaryDto>,
    pub exercises: Vec<ExercisesDto>,
    pub quizzes: Vec<QuizDto>,
    /// Max sync_version across everything returned; use as `since` next pull.
    pub cursor: i64,
}

/// Pull approved summaries/exercises/quizzes changed since `since`.
#[utoipa::path(
    get,
    path = "/api/study",
    params(buddywize_core::SinceQuery),
    responses((status = 200, description = "Study material delta", body = StudyDelta))
)]
pub async fn delta(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Query(q): Query<SinceQuery>,
) -> ApiResult<Json<StudyDelta>> {
    let transcripts: Vec<TranscriptDto> = sqlx::query_as(
        "SELECT t.id, t.recording_id, t.content, t.language,
                t.segments, t.sync_version
           FROM transcripts t
           JOIN recordings r ON r.id = t.recording_id
          WHERE r.user_id = $1
            AND ($2::bigint IS NULL OR t.sync_version > $2)
          ORDER BY t.sync_version LIMIT 200",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_all(&state.db)
    .await?;

    let summaries: Vec<SummaryDto> = sqlx::query_as(
        "SELECT s.id, s.chapter_id, s.recording_id, s.generation_id, s.content_md,
                s.structured_content, s.sync_version
           FROM summaries s
           JOIN recordings r ON r.id = s.recording_id
          WHERE r.user_id = $1 AND s.status = 'approved'
            AND ($2::bigint IS NULL OR s.sync_version > $2)
          ORDER BY s.sync_version LIMIT 200",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_all(&state.db)
    .await?;

    let exercises: Vec<ExercisesDto> = sqlx::query_as(
        "SELECT e.id, e.chapter_id, e.recording_id, e.generation_id, e.items, e.sync_version
           FROM exercises e
           JOIN recordings r ON r.id = e.recording_id
          WHERE r.user_id = $1 AND e.status = 'approved'
            AND ($2::bigint IS NULL OR e.sync_version > $2)
          ORDER BY e.sync_version LIMIT 200",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_all(&state.db)
    .await?;

    let quizzes: Vec<QuizDto> = sqlx::query_as(
        "SELECT qz.id, qz.chapter_id, qz.recording_id, qz.generation_id, qz.questions, qz.sync_version
           FROM quizzes qz
           JOIN recordings r ON r.id = qz.recording_id
          WHERE r.user_id = $1 AND qz.status = 'approved'
            AND ($2::bigint IS NULL OR qz.sync_version > $2)
          ORDER BY qz.sync_version LIMIT 200",
    )
    .bind(user.sub)
    .bind(q.since)
    .fetch_all(&state.db)
    .await?;

    let cursor = summaries
        .iter()
        .map(|s| s.sync_version)
        .chain(transcripts.iter().map(|t| t.sync_version))
        .chain(exercises.iter().map(|e| e.sync_version))
        .chain(quizzes.iter().map(|q| q.sync_version))
        .max()
        .unwrap_or(q.since.unwrap_or(0));

    Ok(Json(StudyDelta {
        transcripts,
        summaries,
        exercises,
        quizzes,
        cursor,
    }))
}

// ---------------------------------------------------------------- quiz attempts

#[derive(Debug, Deserialize, ToSchema)]
pub struct AttemptRequest {
    /// Device-generated idempotency key. Retried offline pushes cannot create
    /// duplicate attempts.
    pub client_uuid: Uuid,
    pub score: i32,
    pub total: i32,
    /// Optional answer breakdown, e.g. [{ question_index, choice, correct }].
    #[serde(default)]
    pub answers: Option<serde_json::Value>,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct AttemptRow {
    pub id: Uuid,
    pub client_uuid: Uuid,
    pub quiz_id: Uuid,
    pub score: i32,
    pub total: i32,
    pub answers: Option<serde_json::Value>,
    pub taken_at: DateTime<Utc>,
}

/// Record a quiz attempt (client-side graded in v1).
#[utoipa::path(
    post,
    path = "/api/quizzes/{quiz_id}/attempts",
    request_body = AttemptRequest,
    responses((status = 200, description = "Attempt recorded", body = AttemptRow))
)]
pub async fn record_attempt(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(quiz_id): Path<Uuid>,
    Json(body): Json<AttemptRequest>,
) -> ApiResult<Json<AttemptRow>> {
    // Quiz must belong to the user and be approved.
    let _owns: Uuid = sqlx::query_scalar(
        "SELECT qz.id FROM quizzes qz
           JOIN recordings r ON r.id = qz.recording_id
          WHERE qz.id = $1 AND r.user_id = $2 AND qz.status = 'approved'",
    )
    .bind(quiz_id)
    .bind(user.sub)
    .fetch_one(&state.db)
    .await?;

    let row: AttemptRow = sqlx::query_as(
        "INSERT INTO quiz_attempts
            (client_uuid, quiz_id, user_id, score, total, answers)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (client_uuid) DO UPDATE SET
            score = EXCLUDED.score,
            total = EXCLUDED.total,
            answers = EXCLUDED.answers
         WHERE quiz_attempts.user_id = $3 AND quiz_attempts.quiz_id = $2
         RETURNING id, client_uuid, quiz_id, score, total, answers, taken_at",
    )
    .bind(body.client_uuid)
    .bind(quiz_id)
    .bind(user.sub)
    .bind(body.score)
    .bind(body.total)
    .bind(body.answers)
    .fetch_one(&state.db)
    .await?;
    Ok(Json(row))
}

/// Attempt history for progress tracking.
#[utoipa::path(
    get,
    path = "/api/quizzes/{quiz_id}/attempts",
    responses((status = 200, description = "Attempt history", body = Vec<AttemptRow>))
)]
pub async fn list_attempts(
    State(state): State<CourseState>,
    AuthUser(user): AuthUser,
    Path(quiz_id): Path<Uuid>,
) -> ApiResult<Json<Vec<AttemptRow>>> {
    let rows: Vec<AttemptRow> = sqlx::query_as(
        "SELECT id, client_uuid, quiz_id, score, total, answers, taken_at
           FROM quiz_attempts
          WHERE quiz_id = $1 AND user_id = $2
          ORDER BY taken_at DESC
          LIMIT 100",
    )
    .bind(quiz_id)
    .bind(user.sub)
    .fetch_all(&state.db)
    .await?;
    Ok(Json(rows))
}
