//! Admin-scoped endpoints backing the Svelte admin panel: user listing,
//! recording/pipeline monitoring, and moderation of AI-generated content.
//! All routes here are additionally guarded by `require_admin` in the API
//! gateway.

use axum::{
    extract::{Path, Query, State},
    routing::{get, post},
    Json, Router,
};
use buddywize_core::{ApiError, ApiResult};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Clone)]
pub struct AdminState {
    pub db: PgPool,
}

pub fn router(state: AdminState) -> Router {
    Router::new()
        .route("/admin/users", get(list_users))
        .route("/admin/users/:id/role", post(set_user_role))
        .route("/admin/recordings", get(list_recordings))
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
            "SELECT id, user_id, chapter_id, status, error, duration_secs, created_at, updated_at
               FROM recordings WHERE status = $1 ORDER BY updated_at DESC LIMIT $2",
        )
        .bind(status)
        .bind(limit)
        .fetch_all(&state.db)
        .await?
    } else {
        sqlx::query_as(
            "SELECT id, user_id, chapter_id, status, error, duration_secs, created_at, updated_at
               FROM recordings ORDER BY updated_at DESC LIMIT $1",
        )
        .bind(limit)
        .fetch_all(&state.db)
        .await?
    };
    Ok(Json(rows))
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
