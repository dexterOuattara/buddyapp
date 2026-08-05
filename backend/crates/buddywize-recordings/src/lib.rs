//! Recording service: resumable chunked uploads over a pluggable storage
//! backend, recording metadata sync, and enqueuing recordings into the AI
//! processing pipeline.

pub mod handlers;
pub mod storage;

use std::sync::Arc;

use axum::{
    routing::{get, post, put},
    Router,
};
use sqlx::PgPool;

use buddywize_core::JobSender;

use crate::storage::StorageBackend;

#[derive(Clone)]
pub struct RecordingState {
    pub db: PgPool,
    pub storage: Arc<dyn StorageBackend>,
    /// Sends completed recordings to the AI pipeline worker.
    pub jobs: JobSender,
}

pub fn router(state: RecordingState) -> Router {
    // Chunk uploads need a bigger body limit than the default 2 MB.
    let chunk_route = Router::new()
        .route("/recordings/uploads/:id/chunk", put(handlers::upload_chunk))
        .layer(axum::extract::DefaultBodyLimit::max(16 * 1024 * 1024));

    Router::new()
        .route("/recordings", get(handlers::list_recordings))
        .route("/recordings/uploads", post(handlers::create_upload))
        .route("/recordings/uploads/:id/complete", post(handlers::complete_upload))
        .route("/recordings/:id/reprocess", post(handlers::reprocess))
        .merge(chunk_route)
        .with_state(state)
}
