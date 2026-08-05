//! Authentication service: JWT access tokens, rotating refresh tokens,
//! RBAC middleware, and the auth endpoints.

pub mod handlers;
pub mod jwt;
pub mod middleware;
pub mod password;

use axum::{
    routing::{get, post},
    Router,
};
use sqlx::PgPool;

#[derive(Clone)]
pub struct JwtConfig {
    pub secret: String,
    pub access_ttl_secs: i64,
    pub refresh_ttl_days: i64,
}

#[derive(Clone)]
pub struct AuthState {
    pub db: PgPool,
    pub jwt: JwtConfig,
}

/// Routes that must be reachable without a token.
pub fn public_router(state: AuthState) -> Router {
    Router::new()
        .route("/auth/register", post(handlers::register))
        .route("/auth/login", post(handlers::login))
        .route("/auth/refresh", post(handlers::refresh))
        .with_state(state)
}

/// Routes that require a valid access token (layered behind `middleware::require_auth`).
pub fn protected_router(state: AuthState) -> Router {
    Router::new()
        .route("/auth/me", get(handlers::me))
        .with_state(state)
}
