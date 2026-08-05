//! Pluggable object storage. The spec calls for S3-compatible storage; this
//! scaffold ships two implementations behind the same trait so callers can
//! pick one at startup:
//!
//! * [`LocalFsStorage`] — files rooted at a directory (dev / single-node).
//! * [`R2Storage`] — Cloudflare R2 over the S3 API (production).
//!
//! Set the `R2_*` env vars to enable R2; otherwise the local filesystem
//! backend is used.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;

use async_trait::async_trait;
use aws_credential_types::Credentials;
use aws_sdk_s3::config::{Builder as S3ConfigBuilder, Region};
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::types::{CompletedMultipartUpload, CompletedPart};
use aws_sdk_s3::Client as S3Client;
use tokio::sync::Mutex;

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("object not found: {0}")]
    NotFound(String),
    #[error("storage backend error: {0}")]
    Backend(String),
}

pub type StorageResult<T> = Result<T, StorageError>;

/// Chunk of an in-progress upload.
pub struct UploadChunk {
    /// Byte offset within the object where this chunk starts.
    pub offset: u64,
    pub bytes: Vec<u8>,
}

#[async_trait]
pub trait StorageBackend: Send + Sync {
    /// Begin a resumable upload; returns nothing on success.
    async fn create_upload(&self, key: &str) -> StorageResult<()>;
    /// Append a chunk at `offset` (resume-safe: server validates the offset).
    /// Returns the new total size.
    async fn append_chunk(&self, key: &str, chunk: UploadChunk) -> StorageResult<u64>;
    /// Total bytes received so far (used for resume handshakes).
    async fn upload_offset(&self, key: &str) -> StorageResult<u64>;
    /// Mark the upload complete and make the object readable.
    async fn finish_upload(&self, key: &str) -> StorageResult<()>;
    /// Read the full object (used by the AI pipeline).
    async fn read(&self, key: &str) -> StorageResult<Vec<u8>>;
    /// Human-readable location (for admin dashboards/debugging).
    fn location(&self, key: &str) -> String;
}

/// Filesystem-backed storage rooted at a directory (dev / single-node).
pub struct LocalFsStorage {
    root: PathBuf,
}

impl LocalFsStorage {
    pub fn new(root: impl Into<PathBuf>) -> StorageResult<Self> {
        let root = root.into();
        std::fs::create_dir_all(root.join("partial"))?;
        std::fs::create_dir_all(root.join("objects"))?;
        Ok(Self { root })
    }

    fn partial_path(&self, key: &str) -> PathBuf {
        // Keys are server-generated ("uuid.ext"); flatten into one directory.
        self.root.join("partial").join(format!("{key}.part"))
    }

    fn object_path(&self, key: &str) -> PathBuf {
        self.root.join("objects").join(key)
    }

    fn offset_mismatch(actual: u64, expected: u64) -> StorageError {
        StorageError::Io(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("offset mismatch: expected {expected}, got {actual}"),
        ))
    }
}

#[async_trait]
impl StorageBackend for LocalFsStorage {
    async fn create_upload(&self, key: &str) -> StorageResult<()> {
        tokio::fs::File::create(self.partial_path(key)).await?;
        Ok(())
    }

    async fn append_chunk(&self, key: &str, chunk: UploadChunk) -> StorageResult<u64> {
        use std::io::SeekFrom;
        use tokio::io::{AsyncSeekExt, AsyncWriteExt};

        let path = self.partial_path(key);
        let mut file = tokio::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .open(&path)
            .await?;
        let len = file.metadata().await?.len();
        if chunk.offset != len {
            return Err(Self::offset_mismatch(chunk.offset, len));
        }
        file.seek(SeekFrom::Start(chunk.offset)).await?;
        file.write_all(&chunk.bytes).await?;
        file.flush().await?;
        Ok(len + chunk.bytes.len() as u64)
    }

    async fn upload_offset(&self, key: &str) -> StorageResult<u64> {
        match tokio::fs::metadata(self.partial_path(key)).await {
            Ok(meta) => Ok(meta.len()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(0),
            Err(e) => Err(e.into()),
        }
    }

    async fn finish_upload(&self, key: &str) -> StorageResult<()> {
        let from = self.partial_path(key);
        if !from.exists() {
            return Err(StorageError::NotFound(key.to_string()));
        }
        if let Some(parent) = self.object_path(key).parent() {
            tokio::fs::create_dir_all(parent).await?;
        }
        tokio::fs::rename(&from, self.object_path(key)).await?;
        Ok(())
    }

    async fn read(&self, key: &str) -> StorageResult<Vec<u8>> {
        let path = self.object_path(key);
        if !path.exists() {
            return Err(StorageError::NotFound(key.to_string()));
        }
        Ok(tokio::fs::read(path).await?)
    }

    fn location(&self, key: &str) -> String {
        self.object_path(key).to_string_lossy().into_owned()
    }
}

/// Cloudflare R2 storage. The endpoint is `https://<account_id>.r2.cloudflarestorage.com`
/// and the bucket region is `auto`. Multipart uploads are tracked in memory —
/// `finish_upload` flushes the parts to R2 via `CompleteMultipartUpload`.
pub struct R2Storage {
    client: S3Client,
    bucket: String,
    /// In-progress multipart uploads keyed by the object key. The `R2Upload`
    /// is created on `create_upload` and removed on `finish_upload`.
    uploads: Arc<Mutex<HashMap<String, R2Upload>>>,
}

#[derive(Default)]
struct R2Upload {
    /// R2 multipart upload ID. Empty until the first chunk is uploaded.
    upload_id: String,
    /// Parts already uploaded, in part-number order.
    parts: Vec<CompletedPart>,
    /// Total bytes received so far.
    offset: u64,
}

#[derive(Debug, Clone)]
pub struct R2Config {
    pub account_id: String,
    pub access_key_id: String,
    pub secret_access_key: String,
    pub bucket: String,
}

impl R2Storage {
    pub async fn connect(cfg: &R2Config) -> anyhow::Result<Self> {
        let endpoint = format!("https://{}.r2.cloudflarestorage.com", cfg.account_id);
        let creds = Credentials::new(
            &cfg.access_key_id,
            &cfg.secret_access_key,
            None,
            None,
            "buddywize-r2",
        );

        let shared = aws_config::defaults(aws_config::BehaviorVersion::latest())
            .credentials_provider(creds)
            .region(Region::new("auto".to_string()))
            .load()
            .await;

        let s3_conf = S3ConfigBuilder::from(&shared)
            .endpoint_url(&endpoint)
            .build();
        let client = S3Client::from_conf(s3_conf);

        // Verify the bucket is reachable. A bad bucket or key surfaces here
        // instead of at the first upload.
        client
            .head_bucket()
            .bucket(&cfg.bucket)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("R2 head_bucket({}) failed: {}", cfg.bucket, e))?;

        Ok(Self {
            client,
            bucket: cfg.bucket.clone(),
            uploads: Arc::new(Mutex::new(HashMap::new())),
        })
    }
}

#[async_trait]
impl StorageBackend for R2Storage {
    async fn create_upload(&self, key: &str) -> StorageResult<()> {
        // Lazy: don't hit R2 until the first chunk. The local entry is what
        // gates the offset arithmetic.
        let mut uploads = self.uploads.lock().await;
        uploads.entry(key.to_string()).or_default();
        Ok(())
    }

    async fn append_chunk(&self, key: &str, chunk: UploadChunk) -> StorageResult<u64> {
        // We hold the uploads lock for the whole call: uploads on the same
        // key are sequential by design (a single client uses one upload
        // session at a time), and serializing here keeps the offset/state
        // bookkeeping simple and correct.
        let mut uploads = self.uploads.lock().await;
        let upload = uploads.entry(key.to_string()).or_default();

        if chunk.offset != upload.offset {
            return Err(LocalFsStorage::offset_mismatch(chunk.offset, upload.offset));
        }

        // Lazily create the multipart upload on the first chunk.
        if upload.upload_id.is_empty() {
            let resp = self
                .client
                .create_multipart_upload()
                .bucket(&self.bucket)
                .key(key)
                .content_type("audio/mp4")
                .send()
                .await
                .map_err(|e| StorageError::Backend(format!("r2 create_multipart_upload: {e}")))?;
            let upload_id = resp.upload_id().unwrap_or("").to_string();
            if upload_id.is_empty() {
                return Err(StorageError::Backend(
                    "R2 returned an empty upload_id".into(),
                ));
            }
            upload.upload_id = upload_id;
        }

        let part_number = (upload.parts.len() + 1) as i32;
        let resp = self
            .client
            .upload_part()
            .bucket(&self.bucket)
            .key(key)
            .upload_id(&upload.upload_id)
            .part_number(part_number)
            .body(ByteStream::from(chunk.bytes.clone()))
            .send()
            .await
            .map_err(|e| StorageError::Backend(format!("r2 upload_part: {e}")))?;

        let etag = resp.e_tag().unwrap_or("").to_string();
        upload.parts.push(
            CompletedPart::builder()
                .part_number(part_number)
                .e_tag(etag)
                .build(),
        );
        upload.offset += chunk.bytes.len() as u64;
        Ok(upload.offset)
    }

    async fn upload_offset(&self, key: &str) -> StorageResult<u64> {
        let uploads = self.uploads.lock().await;
        Ok(uploads.get(key).map(|u| u.offset).unwrap_or(0))
    }

    async fn finish_upload(&self, key: &str) -> StorageResult<()> {
        let mut uploads = self.uploads.lock().await;
        let upload = uploads
            .remove(key)
            .ok_or_else(|| StorageError::NotFound(key.to_string()))?;

        // No data was uploaded — nothing to do.
        if upload.upload_id.is_empty() {
            return Ok(());
        }

        let completed = CompletedMultipartUpload::builder()
            .set_parts(Some(upload.parts))
            .build();

        self.client
            .complete_multipart_upload()
            .bucket(&self.bucket)
            .key(key)
            .upload_id(&upload.upload_id)
            .multipart_upload(completed)
            .send()
            .await
            .map_err(|e| StorageError::Backend(format!("r2 complete_multipart_upload: {e}")))?;

        Ok(())
    }

    async fn read(&self, key: &str) -> StorageResult<Vec<u8>> {
        let resp = self
            .client
            .get_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| StorageError::Backend(format!("r2 get_object: {e}")))?;

        let collected = resp
            .body
            .collect()
            .await
            .map_err(|e| StorageError::Backend(format!("r2 read body: {e}")))?;
        Ok(collected.into_bytes().to_vec())
    }

    fn location(&self, key: &str) -> String {
        format!("r2://{}/{}", self.bucket, key)
    }
}

/// Resolves a storage backend from environment variables. If `R2_BUCKET` is
/// set along with the credentials, returns an R2 client; otherwise falls
/// back to the local filesystem rooted at `STORAGE_DIR`.
pub async fn from_env() -> anyhow::Result<Arc<dyn StorageBackend>> {
    let r2_bucket = std::env::var("R2_BUCKET").ok();
    let storage: Arc<dyn StorageBackend> = match r2_bucket {
        Some(bucket) if !bucket.is_empty() => {
            let cfg = R2Config {
                account_id: std::env::var("R2_ACCOUNT_ID")
                    .map_err(|_| anyhow::anyhow!("R2_BUCKET is set but R2_ACCOUNT_ID is missing"))?,
                access_key_id: std::env::var("R2_ACCESS_KEY_ID")
                    .map_err(|_| anyhow::anyhow!("R2_BUCKET is set but R2_ACCESS_KEY_ID is missing"))?,
                secret_access_key: std::env::var("R2_SECRET_ACCESS_KEY").map_err(|_| {
                    anyhow::anyhow!("R2_BUCKET is set but R2_SECRET_ACCESS_KEY is missing")
                })?,
                bucket,
            };
            tracing::info!(bucket = %cfg.bucket, account = %cfg.account_id, "using Cloudflare R2 storage");
            Arc::new(R2Storage::connect(&cfg).await?)
        }
        _ => {
            let dir = std::env::var("STORAGE_DIR").unwrap_or_else(|_| ".storage".into());
            tracing::info!(dir = %dir, "using local filesystem storage");
            Arc::new(LocalFsStorage::new(dir)?)
        }
    };
    Ok(storage)
}

/// Resolve a storage object key from a recording id + client-provided file name.
pub fn object_key(recording_id: &uuid::Uuid, original_name: Option<&str>) -> String {
    let ext = original_name
        .and_then(|n| std::path::Path::new(n).extension())
        .and_then(|e| e.to_str())
        .unwrap_or("m4a");
    format!("{recording_id}.{ext}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn object_key_uses_supplied_extension() {
        let id = uuid::Uuid::new_v4();
        assert_eq!(object_key(&id, Some("lesson.m4a")), format!("{id}.m4a"));
    }

    #[test]
    fn object_key_defaults_to_m4a() {
        let id = uuid::Uuid::new_v4();
        assert_eq!(object_key(&id, None), format!("{id}.m4a"));
    }

    #[test]
    fn object_key_mp4_extension() {
        let id = uuid::Uuid::new_v4();
        assert_eq!(object_key(&id, Some("a.mp4")), format!("{id}.mp4"));
    }

    #[test]
    fn object_key_extension_uses_last_dot() {
        let id = uuid::Uuid::new_v4();
        assert_eq!(object_key(&id, Some("weird.tar.gz")), format!("{id}.gz"));
    }

    #[test]
    fn local_fs_round_trip() {
        let dir = tempdir().unwrap();
        let storage = LocalFsStorage::new(dir.path()).unwrap();

        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let key = "abc.m4a";
            storage.create_upload(key).await.unwrap();
            assert_eq!(storage.upload_offset(key).await.unwrap(), 0);

            let new = storage
                .append_chunk(key, UploadChunk { offset: 0, bytes: b"hello".to_vec() })
                .await
                .unwrap();
            assert_eq!(new, 5);
            assert_eq!(storage.upload_offset(key).await.unwrap(), 5);

            // Wrong offset must error.
            let err = storage
                .append_chunk(key, UploadChunk { offset: 0, bytes: b"x".to_vec() })
                .await
                .unwrap_err();
            assert!(matches!(err, StorageError::Io(_)));

            storage.finish_upload(key).await.unwrap();
            let bytes = storage.read(key).await.unwrap();
            assert_eq!(bytes, b"hello");
        });
    }

    /// Minimal local tempdir equivalent to avoid pulling in the `tempfile` crate.
    fn tempdir() -> std::io::Result<TempDir> {
        use std::time::{SystemTime, UNIX_EPOCH};
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!("buddywize-test-{nonce}"));
        std::fs::create_dir_all(&path)?;
        Ok(TempDir(path))
    }

    struct TempDir(std::path::PathBuf);
    impl TempDir {
        fn path(&self) -> &std::path::Path {
            &self.0
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }
}
