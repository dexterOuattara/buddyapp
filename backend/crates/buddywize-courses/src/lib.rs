//! Course structure service: agenda, courses, lessons, chapters, and the
//! approved study-material delta feed. All mutations are idempotent upserts
//! keyed by client UUID; all reads support `?since=` delta sync.

pub mod handlers;
pub mod study;

use std::sync::Arc;

use axum::{
    routing::get,
    Router,
};
use buddywize_ai::providers::AgendaParser;
use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::PgPool;
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Clone)]
pub struct CourseState {
    pub db: PgPool,
    pub agenda_parser: Arc<dyn AgendaParser>,
}

pub fn router(state: CourseState) -> Router {
    Router::new()
        // agenda
        .route("/agenda", get(handlers::list_agenda).post(handlers::upsert_agenda))
        .route("/agenda/:client_uuid", axum::routing::delete(handlers::delete_agenda))
        // agenda ingestion: photo (multipart) or iCal (JSON body)
        .route("/agenda/parse", axum::routing::post(handlers::parse_agenda_image))
        .route("/agenda/ical", axum::routing::post(handlers::import_ical))
        // courses
        .route("/courses", get(handlers::list_courses).post(handlers::upsert_course))
        .route("/courses/:client_uuid", axum::routing::delete(handlers::delete_course))
        // lessons
        .route("/lessons", get(handlers::list_lessons).post(handlers::upsert_lesson))
        .route("/lessons/:client_uuid", axum::routing::delete(handlers::delete_lesson))
        // chapters
        .route("/chapters", get(handlers::list_chapters).post(handlers::upsert_chapter))
        .route("/chapters/:client_uuid", axum::routing::delete(handlers::delete_chapter))
        // study material + quiz attempts
        .route("/study", get(study::delta))
        .route("/quizzes/:quiz_id/attempts", get(study::list_attempts).post(study::record_attempt))
        .with_state(state)
}

// ------------------------------------------------------------------ row types

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct AgendaRow {
    pub id: Uuid,
    pub client_uuid: Option<Uuid>,
    pub title: String,
    pub notes: Option<String>,
    pub starts_at: Option<DateTime<Utc>>,
    pub ends_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct CourseRow {
    pub id: Uuid,
    pub client_uuid: Option<Uuid>,
    pub institution_id: Option<Uuid>,
    pub title: String,
    pub description: Option<String>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct LessonRow {
    pub id: Uuid,
    pub course_id: Uuid,
    pub client_uuid: Option<Uuid>,
    pub title: String,
    pub position: i32,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
}

#[derive(Debug, sqlx::FromRow, Serialize, ToSchema)]
pub struct ChapterRow {
    pub id: Uuid,
    pub lesson_id: Uuid,
    pub client_uuid: Option<Uuid>,
    pub title: String,
    pub position: i32,
    pub deleted_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub sync_version: i64,
}
