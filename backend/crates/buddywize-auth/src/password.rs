//! Argon2id password hashing.

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use buddywize_core::ApiError;

pub fn hash(password: &str) -> Result<String, ApiError> {
    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|e| ApiError::Internal(anyhow::anyhow!("hash failed: {e}")))?;
    Ok(hash.to_string())
}

pub fn verify(password: &str, encoded: &str) -> bool {
    match PasswordHash::new(encoded) {
        Ok(parsed) => Argon2::default()
            .verify_password(password.as_bytes(), &parsed)
            .is_ok(),
        Err(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_and_verify_roundtrip() {
        let password = "super-secret-password";
        let encoded = hash(password).expect("hash should succeed");
        assert!(verify(password, &encoded), "correct password should verify");
        assert!(!verify("wrong-password", &encoded), "wrong password should fail");
    }

    #[test]
    fn hash_produces_different_salts() {
        let password = "same-password";
        let h1 = hash(password).unwrap();
        let h2 = hash(password).unwrap();
        assert_ne!(h1, h2, "two hashes of the same password should differ (random salt)");
        assert!(verify(password, &h1));
        assert!(verify(password, &h2));
    }

    #[test]
    fn verify_rejects_garbage() {
        assert!(!verify("anything", "not-a-valid-hash"));
        assert!(!verify("", ""));
    }
}
