//! Runtime-tunable application settings.
//!
//! Settings live in the `app_settings` table. The pipeline reads them on
//! every job (so admins can swap a model without a restart), but we
//! cache them in-process to avoid hammering Postgres on the hot path.
//!
//! `DbSettingsStore` is the source of truth (one SQL query per miss).
//! `SettingsCache` wraps it with an `Arc<RwLock<HashMap>>` that callers
//! can `get_or_load` from cheaply. When the admin updates a key, the
//! handler calls `cache.refresh()` which reloads everything from the DB
//! — simpler than tracking per-key invalidation, and the cost (one
//! indexed PK scan over a handful of rows) is negligible.

use std::collections::HashMap;
use std::sync::Arc;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use tokio::sync::RwLock;

/// One row of the `app_settings` table.
#[derive(Debug, Clone)]
pub struct AppSetting {
    pub key: String,
    pub value: String,
    pub updated_at: DateTime<Utc>,
}

/// Storage contract for runtime-tunable settings. Implementations may
/// persist anywhere (Postgres, Redis, file); the pipeline only depends
/// on the trait.
#[async_trait]
pub trait SettingsStore: Send + Sync {
    /// Read a single value by key. `None` if the key is unset.
    async fn get(&self, key: &str) -> Result<Option<String>, sqlx::Error>;

    /// Read every row (used to warm the cache).
    async fn all(&self) -> Result<Vec<AppSetting>, sqlx::Error>;

    /// Upsert a key. `updated_by` is recorded as the admin user id
    /// (or `None` if the change came from a system context).
    async fn set(
        &self,
        key: &str,
        value: &str,
        updated_by: Option<uuid::Uuid>,
    ) -> Result<(), sqlx::Error>;
}

/// Postgres-backed implementation. Single source of truth.
pub struct DbSettingsStore {
    db: PgPool,
}

impl DbSettingsStore {
    pub fn new(db: PgPool) -> Arc<Self> {
        Arc::new(Self { db })
    }
}

#[async_trait]
impl SettingsStore for DbSettingsStore {
    async fn get(&self, key: &str) -> Result<Option<String>, sqlx::Error> {
        let row: Option<(String,)> =
            sqlx::query_as("SELECT value FROM app_settings WHERE key = $1")
                .bind(key)
                .fetch_optional(&self.db)
                .await?;
        Ok(row.map(|(v,)| v))
    }

    async fn all(&self) -> Result<Vec<AppSetting>, sqlx::Error> {
        let rows: Vec<(String, String, DateTime<Utc>)> =
            sqlx::query_as("SELECT key, value, updated_at FROM app_settings ORDER BY key")
                .fetch_all(&self.db)
                .await?;
        Ok(rows
            .into_iter()
            .map(|(key, value, updated_at)| AppSetting {
                key,
                value,
                updated_at,
            })
            .collect())
    }

    async fn set(
        &self,
        key: &str,
        value: &str,
        updated_by: Option<uuid::Uuid>,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            "INSERT INTO app_settings (key, value, updated_by, updated_at)
             VALUES ($1, $2, $3, now())
             ON CONFLICT (key) DO UPDATE
                SET value = EXCLUDED.value,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = now()",
        )
        .bind(key)
        .bind(value)
        .bind(updated_by)
        .execute(&self.db)
        .await?;
        Ok(())
    }
}

/// In-memory cache fronting a `SettingsStore`. Cheap reads; refresh on
/// admin updates. Cheap enough that we always do a full refresh instead
/// of per-key invalidation.
#[derive(Clone)]
pub struct SettingsCache {
    store: Arc<dyn SettingsStore>,
    inner: Arc<RwLock<HashMap<String, String>>>,
}

impl SettingsCache {
    pub async fn new(store: Arc<dyn SettingsStore>) -> Self {
        let cache = Self {
            store,
            inner: Arc::new(RwLock::new(HashMap::new())),
        };
        // Warm the cache eagerly so the first pipeline call doesn't hit
        // the DB on the critical path.
        if let Err(e) = cache.refresh().await {
            tracing::warn!(error = %e, "settings cache warm-up failed; will retry on first get");
        }
        cache
    }

    /// Reload every key from the underlying store. Call this after any
    /// admin update.
    pub async fn refresh(&self) -> Result<(), sqlx::Error> {
        let rows = self.store.all().await?;
        let mut guard = self.inner.write().await;
        guard.clear();
        for r in rows {
            guard.insert(r.key, r.value);
        }
        Ok(())
    }

    /// Read a value. Cache hit → O(1). Miss → one DB read + cache fill.
    pub async fn get_or_load(&self, key: &str) -> Result<Option<String>, sqlx::Error> {
        if let Some(v) = self.inner.read().await.get(key).cloned() {
            return Ok(Some(v));
        }
        let from_db = self.store.get(key).await?;
        if let Some(v) = &from_db {
            self.inner.write().await.insert(key.to_string(), v.clone());
        }
        Ok(from_db)
    }

    /// Admin write path: persist + refresh cache so subsequent reads
    /// see the new value.
    pub async fn set(
        &self,
        key: &str,
        value: &str,
        updated_by: Option<uuid::Uuid>,
    ) -> Result<(), sqlx::Error> {
        self.store.set(key, value, updated_by).await?;
        // Re-read the row so the cache reflects server-side timestamps
        // and any concurrent writes.
        self.refresh().await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// In-memory store, for unit tests only.
    struct InMemoryStore {
        inner: RwLock<HashMap<String, String>>,
    }

    impl InMemoryStore {
        fn new() -> Arc<Self> {
            Arc::new(Self {
                inner: RwLock::new(HashMap::new()),
            })
        }
    }

    #[async_trait]
    impl SettingsStore for InMemoryStore {
        async fn get(&self, key: &str) -> Result<Option<String>, sqlx::Error> {
            Ok(self.inner.read().await.get(key).cloned())
        }
        async fn all(&self) -> Result<Vec<AppSetting>, sqlx::Error> {
            Ok(self
                .inner
                .read()
                .await
                .iter()
                .map(|(k, v)| AppSetting {
                    key: k.clone(),
                    value: v.clone(),
                    updated_at: Utc::now(),
                })
                .collect())
        }
        async fn set(
            &self,
            key: &str,
            value: &str,
            _updated_by: Option<uuid::Uuid>,
        ) -> Result<(), sqlx::Error> {
            self.inner
                .write()
                .await
                .insert(key.to_string(), value.to_string());
            Ok(())
        }
    }

    #[tokio::test]
    async fn cache_returns_value_from_underlying_store() {
        let store: Arc<dyn SettingsStore> = InMemoryStore::new();
        store.set("k", "v1", None).await.unwrap();
        let cache = SettingsCache::new(store).await;
        assert_eq!(
            cache.get_or_load("k").await.unwrap(),
            Some("v1".to_string())
        );
    }

    #[tokio::test]
    async fn cache_refresh_picks_up_updates() {
        let store = InMemoryStore::new();
        store.set("k", "v1", None).await.unwrap();
        let cache = SettingsCache::new(store.clone()).await;

        // Mutate behind the cache; the cache still has the old value.
        store.set("k", "v2", None).await.unwrap();
        assert_eq!(
            cache.get_or_load("k").await.unwrap(),
            Some("v1".to_string())
        );

        // After refresh, the new value is visible.
        cache.refresh().await.unwrap();
        assert_eq!(
            cache.get_or_load("k").await.unwrap(),
            Some("v2".to_string())
        );
    }

    #[tokio::test]
    async fn cache_set_persists_and_updates_cache() {
        let store = InMemoryStore::new();
        let cache = SettingsCache::new(store.clone()).await;
        cache.set("k", "hello", None).await.unwrap();
        // Visible immediately, without an explicit refresh.
        assert_eq!(
            cache.get_or_load("k").await.unwrap(),
            Some("hello".to_string())
        );
        // And the underlying store got it too.
        assert_eq!(store.get("k").await.unwrap(), Some("hello".to_string()));
    }

    #[tokio::test]
    async fn cache_get_or_load_returns_none_for_missing_key() {
        let store = InMemoryStore::new();
        let cache = SettingsCache::new(store).await;
        assert_eq!(cache.get_or_load("missing").await.unwrap(), None);
    }
}
