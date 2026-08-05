//! /auth endpoints: register, login, refresh (rotation), me.

use axum::{extract::State, Json};
use buddywize_core::{active_entitlement, ApiError, ApiResult, UserRow};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::{jwt, password, middleware::AuthUser, AuthState};

// ------------------------------------------------------------------------ DTO

#[derive(Debug, Deserialize, ToSchema)]
pub struct CredentialsRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct UserDto {
    pub id: Uuid,
    pub email: String,
    pub role: String,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct SubscriptionDto {
    pub plan: String,
    pub status: String,
    pub started_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub user: UserDto,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct MeResponse {
    pub user: UserDto,
    pub subscription: Option<SubscriptionDto>,
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct RefreshRequest {
    pub refresh_token: String,
}

fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn user_dto(user: &UserRow) -> UserDto {
    UserDto {
        id: user.id,
        email: user.email.clone(),
        role: user.role.clone(),
    }
}

async fn issue_tokens(state: &AuthState, user: &UserRow) -> ApiResult<AuthResponse> {
    let access_token = jwt::issue(
        &state.jwt.secret,
        state.jwt.access_ttl_secs,
        user.id,
        &user.email,
        &user.role,
    )
    .map_err(|e| ApiError::Internal(e))?;

    let refresh_token = format!("{}{}", Uuid::new_v4(), Uuid::new_v4()).replace('-', "");
    let expires_at = Utc::now() + Duration::days(state.jwt.refresh_ttl_days);
    sqlx::query(
        "INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)",
    )
    .bind(user.id)
    .bind(sha256_hex(&refresh_token))
    .bind(expires_at)
    .execute(&state.db)
    .await?;

    Ok(AuthResponse {
        access_token,
        refresh_token,
        token_type: "bearer".to_string(),
        user: user_dto(user),
    })
}

// -------------------------------------------------------------------- handlers

/// Create an account and start the 7-day free trial.
#[utoipa::path(
    post,
    path = "/api/auth/register",
    request_body = CredentialsRequest,
    responses((status = 200, description = "Account created", body = AuthResponse))
)]
pub async fn register(
    State(state): State<AuthState>,
    Json(body): Json<CredentialsRequest>,
) -> ApiResult<Json<AuthResponse>> {
    let email = body.email.trim().to_lowercase();
    if email.is_empty() || !email.contains('@') {
        return Err(ApiError::BadRequest("invalid email".into()));
    }
    if body.password.len() < 8 {
        return Err(ApiError::BadRequest(
            "password must be at least 8 characters".into(),
        ));
    }

    let hash = password::hash(&body.password)?;
    let user = sqlx::query_as::<_, UserRow>(
        "INSERT INTO users (email, password_hash, role)
         VALUES ($1, $2, 'student')
         ON CONFLICT (email) DO NOTHING
         RETURNING *",
    )
    .bind(&email)
    .bind(&hash)
    .fetch_optional(&state.db)
    .await?;

    let user = match user {
        Some(u) => u,
        None => return Err(ApiError::Conflict("email already registered".into())),
    };

    // 7-day free trial, tracked server-side (survives reinstalls).
    sqlx::query(
        "INSERT INTO subscriptions (user_id, plan, status, expires_at)
         VALUES ($1, 'trial', 'active', now() + INTERVAL '7 days')",
    )
    .bind(user.id)
    .execute(&state.db)
    .await?;

    Ok(Json(issue_tokens(&state, &user).await?))
}

/// Log in with email + password.
#[utoipa::path(
    post,
    path = "/api/auth/login",
    request_body = CredentialsRequest,
    responses((status = 200, description = "Authenticated", body = AuthResponse))
)]
pub async fn login(
    State(state): State<AuthState>,
    Json(body): Json<CredentialsRequest>,
) -> ApiResult<Json<AuthResponse>> {
    let email = body.email.trim().to_lowercase();
    let user: Option<UserRow> =
        sqlx::query_as("SELECT * FROM users WHERE email = $1")
            .bind(&email)
            .fetch_optional(&state.db)
            .await?;

    let user = match user {
        Some(u) if password::verify(&body.password, &u.password_hash) => u,
        _ => return Err(ApiError::Unauthorized),
    };

    Ok(Json(issue_tokens(&state, &user).await?))
}

/// Rotate a refresh token: the old one is revoked, a new pair is issued.
#[utoipa::path(
    post,
    path = "/api/auth/refresh",
    request_body = RefreshRequest,
    responses((status = 200, description = "New token pair", body = AuthResponse))
)]
pub async fn refresh(
    State(state): State<AuthState>,
    Json(body): Json<RefreshRequest>,
) -> ApiResult<Json<AuthResponse>> {
    #[derive(sqlx::FromRow)]
    struct TokenRow {
        id: Uuid,
        user_id: Uuid,
        expires_at: DateTime<Utc>,
        revoked_at: Option<DateTime<Utc>>,
    }

    let token: Option<TokenRow> = sqlx::query_as(
        "SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = $1",
    )
    .bind(sha256_hex(&body.refresh_token))
    .fetch_optional(&state.db)
    .await?;

    let token = match token {
        Some(t) if t.revoked_at.is_none() && t.expires_at > Utc::now() => t,
        _ => return Err(ApiError::Unauthorized),
    };

    let user: UserRow = sqlx::query_as("SELECT * FROM users WHERE id = $1")
        .bind(token.user_id)
        .fetch_one(&state.db)
        .await?;

    // Revoke the presented token (rotation).
    sqlx::query("UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1")
        .bind(token.id)
        .execute(&state.db)
        .await?;

    Ok(Json(issue_tokens(&state, &user).await?))
}

/// Current user + active entitlement.
#[utoipa::path(
    get,
    path = "/api/auth/me",
    responses((status = 200, description = "Current user", body = MeResponse))
)]
pub async fn me(
    State(state): State<AuthState>,
    AuthUser(claims): AuthUser,
) -> ApiResult<Json<MeResponse>> {
    let user: UserRow = sqlx::query_as("SELECT * FROM users WHERE id = $1")
        .bind(claims.sub)
        .fetch_one(&state.db)
        .await?;

    let subscription = active_entitlement(&state.db, user.id)
        .await?
        .map(|s| SubscriptionDto {
            plan: s.plan,
            status: s.status,
            started_at: s.started_at,
            expires_at: s.expires_at,
        });

    Ok(Json(MeResponse {
        user: user_dto(&user),
        subscription,
    }))
}

/// Idempotently seed an admin account (used at boot for dev/demo access).
pub async fn seed_admin(
    db: &sqlx::PgPool,
    email: &str,
    password: &str,
) -> ApiResult<()> {
    let email = email.trim().to_lowercase();
    let exists: Option<UserRow> = sqlx::query_as("SELECT * FROM users WHERE email = $1")
        .bind(&email)
        .fetch_optional(db)
        .await?;
    if exists.is_some() {
        return Ok(());
    }
    let hash = password::hash(password)?;
    sqlx::query("INSERT INTO users (email, password_hash, role) VALUES ($1, $2, 'admin')")
        .bind(&email)
        .bind(&hash)
        .execute(db)
        .await?;
    tracing::info!(email = %email, "seeded admin user");
    Ok(())
}
