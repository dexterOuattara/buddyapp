//! Auth middleware (Bearer token validation) and typed extractors.

use axum::{
    extract::{FromRequestParts, Request, State},
    http::{header::AUTHORIZATION, request::Parts},
    middleware::Next,
    response::Response,
};
use buddywize_core::{ApiError, Role};

use crate::{jwt::Claims, AuthState};

/// Validates `Authorization: Bearer <jwt>` and inserts `Claims` into request
/// extensions. Apply to every non-public route.
pub async fn require_auth(
    State(state): State<AuthState>,
    mut req: Request,
    next: Next,
) -> Result<Response, ApiError> {
    let token = req
        .headers()
        .get(AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or(ApiError::Unauthorized)?;

    let claims = crate::jwt::validate(&state.jwt.secret, token).map_err(|_| ApiError::Unauthorized)?;
    req.extensions_mut().insert(claims);
    Ok(next.run(req).await)
}

/// Must run after `require_auth`; rejects non-admin claims.
pub async fn require_admin(req: Request, next: Next) -> Result<Response, ApiError> {
    let claims = req
        .extensions()
        .get::<Claims>()
        .ok_or(ApiError::Unauthorized)?;
    if claims.role != Role::Admin.as_str() {
        return Err(ApiError::Forbidden);
    }
    Ok(next.run(req).await)
}

/// Extractor for handlers that need the authenticated user.
pub struct AuthUser(pub Claims);

#[async_trait::async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<Claims>()
            .cloned()
            .map(AuthUser)
            .ok_or(ApiError::Unauthorized)
    }
}
