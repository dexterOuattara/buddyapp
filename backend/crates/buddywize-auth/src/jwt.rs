//! JWT issuing / validation for access tokens.

use anyhow::{anyhow, Context};
use chrono::Utc;
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    /// User id.
    pub sub: Uuid,
    pub email: String,
    /// "student" | "admin"
    pub role: String,
    /// Expiry, unix seconds.
    pub exp: i64,
    /// Issued-at, unix seconds.
    pub iat: i64,
}

pub fn issue(
    secret: &str,
    ttl_secs: i64,
    user_id: Uuid,
    email: &str,
    role: &str,
) -> anyhow::Result<String> {
    let now = Utc::now().timestamp();
    let claims = Claims {
        sub: user_id,
        email: email.to_string(),
        role: role.to_string(),
        iat: now,
        exp: now + ttl_secs,
    };
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .context("failed to encode JWT")
}

pub fn validate(secret: &str, token: &str) -> anyhow::Result<Claims> {
    let data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|e| anyhow!("invalid token: {e}"))?;
    Ok(data.claims)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn issue_and_validate_roundtrip() {
        let secret = "test-secret-key";
        let user_id = Uuid::new_v4();
        let email = "student@example.com";
        let role = "student";

        let token = issue(secret, 3600, user_id, email, role).expect("issue should succeed");
        let claims = validate(secret, &token).expect("validate should succeed");

        assert_eq!(claims.sub, user_id);
        assert_eq!(claims.email, email);
        assert_eq!(claims.role, role);
        assert!(claims.exp > claims.iat);
        assert!(claims.exp - claims.iat <= 3600);
    }

    #[test]
    fn validate_rejects_wrong_secret() {
        let token = issue("secret-a", 3600, Uuid::new_v4(), "a@b.com", "student").unwrap();
        let result = validate("secret-b", &token);
        assert!(result.is_err(), "wrong secret should fail validation");
    }

    #[test]
    fn validate_rejects_expired_token() {
        let secret = "test-secret";
        // Issue with a large negative TTL (expired well beyond the 60s default leeway)
        let token = issue(secret, -120, Uuid::new_v4(), "a@b.com", "admin").unwrap();
        let result = validate(secret, &token);
        assert!(result.is_err(), "expired token should fail validation");
    }

    #[test]
    fn validate_rejects_garbage() {
        let result = validate("secret", "not.a.jwt");
        assert!(result.is_err());
    }

    #[test]
    fn admin_role_preserved() {
        let secret = "secret";
        let token = issue(
            secret,
            3600,
            Uuid::new_v4(),
            "admin@buddywize.local",
            "admin",
        )
        .unwrap();
        let claims = validate(secret, &token).unwrap();
        assert_eq!(claims.role, "admin");
    }
}
