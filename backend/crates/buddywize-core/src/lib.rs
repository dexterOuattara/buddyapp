//! Shared kernel for BuddyWize services: errors, roles, sync primitives,
//! storage abstraction, entitlement checks, and cross-service types.

pub mod settings;
pub mod storage;

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use chrono::{DateTime, NaiveDate, NaiveDateTime, NaiveTime, TimeZone, Utc};
use serde::Deserialize;
use sqlx::PgPool;
use utoipa::IntoParams;
use uuid::Uuid;

// --------------------------------------------------------------------- errors

/// Shared application error mapped to HTTP responses.
#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("resource not found")]
    NotFound,
    #[error("authentication required")]
    Unauthorized,
    #[error("insufficient permissions")]
    Forbidden,
    #[error("conflict: {0}")]
    Conflict(String),
    #[error("bad request: {0}")]
    BadRequest(String),
    #[error("internal error")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = match &self {
            ApiError::NotFound => StatusCode::NOT_FOUND,
            ApiError::Unauthorized => StatusCode::UNAUTHORIZED,
            ApiError::Forbidden => StatusCode::FORBIDDEN,
            ApiError::Conflict(_) => StatusCode::CONFLICT,
            ApiError::BadRequest(_) => StatusCode::BAD_REQUEST,
            ApiError::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        };
        if let ApiError::Internal(err) = &self {
            // Print the full anyhow chain so the actual failure is visible
            // in the logs (the `Display` impl only says "internal error").
            tracing::error!(error = ?err, "request failed");
        }
        let body = serde_json::json!({ "error": self.to_string() });
        (status, Json(body)).into_response()
    }
}

impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => ApiError::NotFound,
            other => ApiError::Internal(other.into()),
        }
    }
}

pub type ApiResult<T> = Result<T, ApiError>;

// ---------------------------------------------------------------------- roles

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Role {
    Student,
    Admin,
}

impl Role {
    pub fn as_str(&self) -> &'static str {
        match self {
            Role::Student => "student",
            Role::Admin => "admin",
        }
    }

    pub fn parse(value: &str) -> Result<Self, ApiError> {
        match value {
            "student" => Ok(Role::Student),
            "admin" => Ok(Role::Admin),
            other => Err(ApiError::Internal(anyhow::anyhow!(
                "unknown role '{other}'"
            ))),
        }
    }
}

// ------------------------------------------------------------------ sync bits

/// `?since=<cursor>` delta-sync query parameter shared by all list endpoints.
/// Derives `IntoParams` so handlers can reference it in `#[utoipa::path(params(...))]`.
#[derive(Debug, Default, Deserialize, IntoParams)]
pub struct SinceQuery {
    pub since: Option<i64>,
}

/// Recording ids flow through this channel into the AI pipeline worker.
pub type JobSender = tokio::sync::mpsc::Sender<Uuid>;
pub type JobReceiver = tokio::sync::mpsc::Receiver<Uuid>;

pub fn job_channel(buffer: usize) -> (JobSender, JobReceiver) {
    tokio::sync::mpsc::channel(buffer)
}

// ---------------------------------------------------------------- entitlement

#[derive(Debug, sqlx::FromRow)]
pub struct SubscriptionRow {
    pub id: Uuid,
    pub user_id: Uuid,
    pub plan: String,
    pub status: String,
    pub started_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

/// Returns the user's active (non-expired) entitlement, if any.
///
/// Admins always get a synthetic "admin" entitlement regardless of the
/// `subscriptions` table — they're treated as fully-unlimited users. This
/// mirrors the platform convention that admin accounts bypass billing.
pub async fn active_entitlement(
    db: &PgPool,
    user_id: Uuid,
    role: &str,
) -> Result<Option<SubscriptionRow>, sqlx::Error> {
    if role == "admin" {
        return Ok(Some(admin_entitlement(user_id)));
    }
    sqlx::query_as::<_, SubscriptionRow>(
        "SELECT id, user_id, plan, status, started_at, expires_at
           FROM subscriptions
          WHERE user_id = $1 AND status = 'active' AND expires_at > now()
          ORDER BY expires_at DESC
          LIMIT 1",
    )
    .bind(user_id)
    .fetch_optional(db)
    .await
}

/// Synthetic unlimited entitlement for admin users.
///
/// Uses a far-future `expires_at` so downstream code (which compares against
/// `now()`) treats this as active forever. `id` is zero — admin entitlements
/// aren't stored as rows, so the id is meaningless and never persisted.
fn admin_entitlement(user_id: Uuid) -> SubscriptionRow {
    let now = Utc::now();
    let expires = NaiveDateTime::new(
        NaiveDate::from_ymd_opt(2099, 1, 1).expect("valid date"),
        NaiveTime::from_hms_opt(0, 0, 0).expect("valid time"),
    );
    SubscriptionRow {
        id: Uuid::nil(),
        user_id,
        plan: "admin".into(),
        status: "active".into(),
        started_at: now,
        expires_at: Utc.from_utc_datetime(&expires),
    }
}

// ------------------------------------------------------------------ user rows

/// Full user row (includes password hash — keep inside the backend).
#[derive(Debug, sqlx::FromRow)]
pub struct UserRow {
    pub id: Uuid,
    pub email: String,
    pub password_hash: String,
    pub role: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn role_parse_valid() {
        assert_eq!(Role::parse("student").unwrap(), Role::Student);
        assert_eq!(Role::parse("admin").unwrap(), Role::Admin);
    }

    #[test]
    fn role_parse_invalid() {
        assert!(Role::parse("superadmin").is_err());
        assert!(Role::parse("").is_err());
        assert!(Role::parse("STUDENT").is_err());
    }

    #[test]
    fn role_as_str_roundtrip() {
        assert_eq!(Role::Student.as_str(), "student");
        assert_eq!(Role::Admin.as_str(), "admin");
        assert_eq!(Role::parse(Role::Student.as_str()).unwrap(), Role::Student);
        assert_eq!(Role::parse(Role::Admin.as_str()).unwrap(), Role::Admin);
    }

    #[test]
    fn api_error_display_messages() {
        assert_eq!(ApiError::NotFound.to_string(), "resource not found");
        assert_eq!(
            ApiError::Unauthorized.to_string(),
            "authentication required"
        );
        assert_eq!(ApiError::Forbidden.to_string(), "insufficient permissions");
        assert_eq!(
            ApiError::Conflict("email taken".into()).to_string(),
            "conflict: email taken"
        );
        assert_eq!(
            ApiError::BadRequest("missing field".into()).to_string(),
            "bad request: missing field"
        );
    }

    #[test]
    fn api_error_http_status_mapping() {
        let cases: Vec<(ApiError, StatusCode)> = vec![
            (ApiError::NotFound, StatusCode::NOT_FOUND),
            (ApiError::Unauthorized, StatusCode::UNAUTHORIZED),
            (ApiError::Forbidden, StatusCode::FORBIDDEN),
            (ApiError::Conflict("x".into()), StatusCode::CONFLICT),
            (ApiError::BadRequest("x".into()), StatusCode::BAD_REQUEST),
            (
                ApiError::Internal(anyhow::anyhow!("x")),
                StatusCode::INTERNAL_SERVER_ERROR,
            ),
        ];
        for (err, expected) in cases {
            let response = err.into_response();
            assert_eq!(response.status(), expected);
        }
    }

    #[test]
    fn since_query_default_is_none() {
        let q = SinceQuery::default();
        assert!(q.since.is_none());
    }

    #[test]
    fn job_channel_works() {
        let (tx, mut rx) = job_channel(4);
        let id = Uuid::new_v4();
        tx.try_send(id).unwrap();
        let received = rx.try_recv().unwrap();
        assert_eq!(received, id);
    }

    /// Admin users get a synthetic unlimited entitlement even when they
    /// have no row in the `subscriptions` table. The entitlement must be
    /// active and far enough in the future that every comparison
    /// `expires_at > now()` succeeds.
    #[tokio::test]
    async fn admin_entitlement_is_synthetic_and_active() {
        // We can't hit the DB here (no test container wired up), but we can
        // exercise the helper directly. The function-level check is the same
        // — `active_entitlement` short-circuits before the SQL query for
        // admins.
        let user_id = Uuid::new_v4();
        // Re-derive the synthetic via the public function (use a dummy pool
        // by never touching it for the admin branch).
        // We can't easily build a fake PgPool here, so we just confirm the
        // shape of the row that the helper produces.
        let row = super::admin_entitlement(user_id);
        assert_eq!(row.user_id, user_id);
        assert_eq!(row.plan, "admin");
        assert_eq!(row.status, "active");
        assert!(row.expires_at > Utc::now() + chrono::Duration::days(365 * 50));
    }
}
