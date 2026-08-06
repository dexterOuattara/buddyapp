//! Background worker that consumes completed recordings and runs the
//! entitlement check → STT → study-material pipeline.

use std::sync::Arc;

use buddywize_core::storage::StorageBackend;
use buddywize_core::{active_entitlement, JobReceiver};
use sqlx::PgPool;
use uuid::Uuid;

use crate::providers::{GeneratedContent, SttProvider, StudyGenerator, Transcript};

pub struct Pipeline {
    db: PgPool,
    storage: Arc<dyn StorageBackend>,
    stt: Arc<dyn SttProvider>,
    generator: Arc<dyn StudyGenerator>,
}

#[derive(Debug, sqlx::FromRow)]
struct RecordingJobRow {
    id: Uuid,
    user_id: Uuid,
    user_role: String,
    chapter_id: Uuid,
    storage_path: String,
}

impl Pipeline {
    pub fn new(
        db: PgPool,
        storage: Arc<dyn StorageBackend>,
        stt: Arc<dyn SttProvider>,
        generator: Arc<dyn StudyGenerator>,
    ) -> Self {
        Self { db, storage, stt, generator }
    }

    /// Run until the channel closes.
    pub async fn run(self, mut rx: JobReceiver) {
        while let Some(recording_id) = rx.recv().await {
            if let Err(e) = self.process(recording_id).await {
                tracing::error!(error = %e, %recording_id, "pipeline failed");
                let _ = self.set_status(recording_id, "failed", Some(&e.to_string())).await;
            }
        }
    }

    async fn process(&self, recording_id: Uuid) -> anyhow::Result<()> {
        let rec: RecordingJobRow = sqlx::query_as(
            "SELECT r.id, r.user_id, u.role AS user_role, r.chapter_id, r.storage_path
               FROM recordings r
               JOIN users u ON u.id = r.user_id
              WHERE r.id = $1",
        )
        .bind(recording_id)
        .fetch_one(&self.db)
        .await?;

        // Entitlement gate: lapsed users keep their content but get no NEW processing.
        // Admins always pass (synthetic entitlement).
        if active_entitlement(&self.db, rec.user_id, &rec.user_role).await?.is_none() {
            tracing::info!(%recording_id, user_id = %rec.user_id, "no active entitlement; skipping processing");
            self.set_status(recording_id, "blocked", Some("subscription or trial ended"))
                .await?;
            return Ok(());
        }

        self.set_status(recording_id, "processing", None).await?;

        let chapter_title: String =
            sqlx::query_scalar("SELECT title FROM chapters WHERE id = $1")
                .bind(rec.chapter_id)
                .fetch_one(&self.db)
                .await?;

        // 1) Speech-to-text.
        let audio = self.storage.read(&rec.storage_path).await?;
        let transcript: Transcript = self.stt.transcribe(&audio).await?;
        sqlx::query(
            "INSERT INTO transcripts (recording_id, provider, content)
             VALUES ($1, $2, $3)
             ON CONFLICT (recording_id) DO UPDATE
                SET provider = EXCLUDED.provider, content = EXCLUDED.content",
        )
        .bind(recording_id)
        .bind(self.stt.name())
        .bind(&transcript.text)
        .execute(&self.db)
        .await?;

        // 2) Summary + exercises + quiz.
        let content: GeneratedContent = self
            .generator
            .generate(&chapter_title, &transcript)
            .await?;
        self.persist_study_material(recording_id, rec.chapter_id, &content)
            .await?;

        self.set_status(recording_id, "ready", None).await?;
        tracing::info!(%recording_id, chapter_id = %rec.chapter_id, "pipeline complete; awaiting moderation");
        Ok(())
    }

    async fn persist_study_material(
        &self,
        recording_id: Uuid,
        chapter_id: Uuid,
        content: &GeneratedContent,
    ) -> anyhow::Result<()> {
        // Reprocessing replaces previous results for the same recording.
        for table in ["summaries", "exercises", "quizzes"] {
            sqlx::query(&format!("DELETE FROM {table} WHERE recording_id = $1"))
                .bind(recording_id)
                .execute(&self.db)
                .await?;
        }

        sqlx::query(
            "INSERT INTO summaries (recording_id, chapter_id, content_md, status)
             VALUES ($1, $2, $3, 'pending_review')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(&content.summary_markdown)
        .execute(&self.db)
        .await?;

        sqlx::query(
            "INSERT INTO exercises (recording_id, chapter_id, items, status)
             VALUES ($1, $2, $3, 'pending_review')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(serde_json::to_value(&content.exercises)?)
        .execute(&self.db)
        .await?;

        sqlx::query(
            "INSERT INTO quizzes (recording_id, chapter_id, questions, status)
             VALUES ($1, $2, $3, 'pending_review')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(serde_json::to_value(&content.quiz)?)
        .execute(&self.db)
        .await?;

        Ok(())
    }

    async fn set_status(
        &self,
        recording_id: Uuid,
        status: &str,
        error: Option<&str>,
    ) -> anyhow::Result<()> {
        sqlx::query(
            "UPDATE recordings
                SET status = $2, error = $3, updated_at = now(),
                    sync_version = nextval('sync_version_seq')
              WHERE id = $1",
        )
        .bind(recording_id)
        .bind(status)
        .bind(error)
        .execute(&self.db)
        .await?;
        Ok(())
    }
}
