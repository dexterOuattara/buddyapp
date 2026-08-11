//! Background worker that consumes completed recordings and runs the
//! entitlement check → STT → study-material pipeline.

use std::sync::Arc;
use std::time::Duration;

use buddywize_core::active_entitlement;
use buddywize_core::storage::StorageBackend;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use tokio::time::Instant;
use uuid::Uuid;

use crate::providers::{
    GeneratedContent, SttProgressFuture, SttProvider, StudyGenerator, Transcript,
};

const MAX_CUMULATIVE_CONTEXT_CHARS: usize = 60_000;
const JOB_HEARTBEAT_INTERVAL: Duration = Duration::from_secs(30);
const JOB_LEASE_TIMEOUT: Duration = Duration::from_secs(2 * 60);
const STALE_JOB_SWEEP_INTERVAL: Duration = Duration::from_secs(30);

pub struct Pipeline {
    db: PgPool,
    storage: Arc<dyn StorageBackend>,
    stt: Arc<dyn SttProvider>,
    generator: Arc<dyn StudyGenerator>,
}

#[derive(Debug, sqlx::FromRow)]
struct RecordingJobRow {
    user_id: Uuid,
    user_role: String,
    chapter_id: Uuid,
    storage_path: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct ChapterTranscriptRow {
    recording_id: Uuid,
    content: String,
    language: Option<String>,
    created_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
struct ClaimedJob {
    recording_id: Uuid,
    attempts: i32,
}

impl Pipeline {
    pub fn new(
        db: PgPool,
        storage: Arc<dyn StorageBackend>,
        stt: Arc<dyn SttProvider>,
        generator: Arc<dyn StudyGenerator>,
    ) -> Self {
        Self {
            db,
            storage,
            stt,
            generator,
        }
    }

    /// Continuously drain the PostgreSQL-backed job queue. Queue ownership is
    /// leased so work survives API restarts and multiple API instances can
    /// safely cooperate without processing the same recording concurrently.
    pub async fn run(self) {
        let worker_id = Uuid::new_v4();
        if let Err(error) = self.recover_jobs().await {
            tracing::error!(%error, "failed to reconcile recording jobs at startup");
        }
        let mut last_stale_job_sweep = Instant::now();
        loop {
            if last_stale_job_sweep.elapsed() >= STALE_JOB_SWEEP_INTERVAL {
                if let Err(error) = self.requeue_stale_jobs().await {
                    tracing::error!(%error, "failed to recover stale recording jobs");
                }
                last_stale_job_sweep = Instant::now();
            }
            match self.claim_job(worker_id).await {
                Ok(Some(job)) => {
                    tracing::info!(
                        recording_id = %job.recording_id,
                        attempt = job.attempts,
                        %worker_id,
                        "recording pipeline job claimed"
                    );
                    let heartbeat = self.spawn_job_heartbeat(job.recording_id, worker_id);
                    let result = self.process(job.recording_id).await;
                    heartbeat.abort();
                    let _ = heartbeat.await;
                    match result {
                        Ok(()) => {
                            if let Err(error) = self.complete_job(job.recording_id).await {
                                tracing::error!(%error, recording_id = %job.recording_id, "failed to complete recording job");
                            }
                        }
                        Err(error) => {
                            tracing::error!(%error, recording_id = %job.recording_id, attempt = job.attempts, "pipeline failed");
                            if let Err(mark_error) = self
                                .fail_or_retry_job(job.recording_id, job.attempts, &error)
                                .await
                            {
                                tracing::error!(%mark_error, recording_id = %job.recording_id, "failed to persist pipeline failure");
                            }
                        }
                    }
                }
                Ok(None) => tokio::time::sleep(Duration::from_secs(1)).await,
                Err(error) => {
                    tracing::error!(%error, "recording queue claim failed");
                    tokio::time::sleep(Duration::from_secs(3)).await;
                }
            }
        }
    }

    async fn recover_jobs(&self) -> anyhow::Result<()> {
        self.requeue_stale_jobs().await?;
        sqlx::query(
            "INSERT INTO recording_jobs (recording_id, state)
             SELECT id, 'queued' FROM recordings
              WHERE status IN ('uploaded', 'processing')
             ON CONFLICT (recording_id) DO NOTHING",
        )
        .execute(&self.db)
        .await?;
        Ok(())
    }

    /// Reclaims jobs whose worker stopped renewing its lease. This must run
    /// periodically, not only at process startup: a quick restart sees the old
    /// lease as fresh, and without a later sweep that job would stay `running`
    /// forever. Active workers refresh `locked_at` in [spawn_job_heartbeat].
    async fn requeue_stale_jobs(&self) -> anyhow::Result<()> {
        let mut tx = self.db.begin().await?;
        sqlx::query(
            "WITH recovered AS (
                 UPDATE recording_jobs
                    SET state = 'queued', next_attempt_at = now(), locked_at = NULL,
                        worker_id = NULL,
                        last_error = COALESCE(last_error, 'worker lease expired'),
                        updated_at = now()
                  WHERE state = 'running'
                    AND (locked_at IS NULL OR
                         locked_at < now() - make_interval(secs => $1))
              RETURNING recording_id
             )
             UPDATE recordings r
                SET status = 'processing', pipeline_stage = 'retry_wait',
                    status_message = 'Reprise automatique du traitement',
                    retryable = TRUE, next_retry_at = now(),
                    stage_started_at = now(), last_progress_at = now(),
                    updated_at = now(), sync_version = nextval('sync_version_seq')
              WHERE r.id IN (SELECT recording_id FROM recovered)",
        )
        .bind(JOB_LEASE_TIMEOUT.as_secs() as f64)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    fn spawn_job_heartbeat(
        &self,
        recording_id: Uuid,
        worker_id: Uuid,
    ) -> tokio::task::JoinHandle<()> {
        let db = self.db.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(JOB_HEARTBEAT_INTERVAL);
            // `interval` ticks immediately once. The claim already wrote the
            // initial lease, so wait for the first real heartbeat interval.
            interval.tick().await;
            loop {
                interval.tick().await;
                match sqlx::query(
                    "UPDATE recording_jobs
                        SET locked_at = now(), updated_at = now()
                      WHERE recording_id = $1 AND worker_id = $2
                        AND state = 'running'",
                )
                .bind(recording_id)
                .bind(worker_id)
                .execute(&db)
                .await
                {
                    Ok(result) if result.rows_affected() == 0 => break,
                    Ok(_) => {}
                    Err(error) => {
                        tracing::warn!(%error, %recording_id, %worker_id, "recording job heartbeat failed");
                    }
                }
            }
        })
    }

    async fn claim_job(&self, worker_id: Uuid) -> anyhow::Result<Option<ClaimedJob>> {
        let job = sqlx::query_as::<_, ClaimedJob>(
            "WITH candidate AS (
                 SELECT recording_id
                   FROM recording_jobs
                  WHERE state IN ('queued', 'retry_wait')
                    AND next_attempt_at <= now()
                  ORDER BY next_attempt_at, created_at
                  FOR UPDATE SKIP LOCKED
                  LIMIT 1
             )
             UPDATE recording_jobs j
                SET state = 'running', attempts = j.attempts + 1,
                    locked_at = now(), worker_id = $1, updated_at = now()
               FROM candidate c
              WHERE j.recording_id = c.recording_id
          RETURNING j.recording_id, j.attempts",
        )
        .bind(worker_id)
        .fetch_optional(&self.db)
        .await?;
        if let Some(job) = &job {
            sqlx::query(
                "UPDATE recordings
                    SET attempt_count = $2, next_retry_at = NULL,
                        last_progress_at = now(), updated_at = now(),
                        sync_version = nextval('sync_version_seq')
                  WHERE id = $1",
            )
            .bind(job.recording_id)
            .bind(job.attempts)
            .execute(&self.db)
            .await?;
        }
        Ok(job)
    }

    async fn process(&self, recording_id: Uuid) -> anyhow::Result<()> {
        self.update_progress(
            recording_id,
            "checking_access",
            42,
            None,
            None,
            "Vérification du traitement",
        )
        .await?;
        let rec: RecordingJobRow = sqlx::query_as(
            "SELECT r.user_id, u.role AS user_role, r.chapter_id, r.storage_path
               FROM recordings r
               JOIN users u ON u.id = r.user_id
              WHERE r.id = $1",
        )
        .bind(recording_id)
        .fetch_one(&self.db)
        .await?;

        // Entitlement gate: lapsed users keep their content but get no NEW processing.
        // Admins always pass (synthetic entitlement).
        if active_entitlement(&self.db, rec.user_id, &rec.user_role)
            .await?
            .is_none()
        {
            tracing::info!(%recording_id, user_id = %rec.user_id, "no active entitlement; skipping processing");
            self.set_terminal_status(
                recording_id,
                "blocked",
                "blocked",
                42,
                Some("subscription or trial ended"),
                "Abonnement requis pour créer le matériel",
                false,
                Some("entitlement_required"),
            )
            .await?;
            return Ok(());
        }

        let chapter_title: String = sqlx::query_scalar("SELECT title FROM chapters WHERE id = $1")
            .bind(rec.chapter_id)
            .fetch_one(&self.db)
            .await?;

        // 1) Speech-to-text.
        self.update_progress(
            recording_id,
            "downloading_audio",
            45,
            None,
            None,
            "Préparation de l’audio",
        )
        .await?;
        let audio = self.storage.read(&rec.storage_path).await?;
        self.update_progress(
            recording_id,
            "transcribing",
            50,
            Some(0),
            Some(1),
            "Transcription de la séance",
        )
        .await?;
        let mut report_progress = |current: usize, total: usize| -> SttProgressFuture<'_> {
            Box::pin(async move {
                let bounded_total = total.max(1);
                let bounded_current = current.min(bounded_total);
                let progress_percent = 50 + (17 * bounded_current / bounded_total) as i32;
                let message = if bounded_total > 1 {
                    format!("Transcription audio {bounded_current}/{bounded_total}")
                } else {
                    "Transcription de la séance".to_string()
                };
                if let Err(error) = self
                    .update_progress(
                        recording_id,
                        "transcribing",
                        progress_percent,
                        Some(bounded_current as i32),
                        Some(bounded_total as i32),
                        &message,
                    )
                    .await
                {
                    tracing::warn!(%error, %recording_id, "failed to persist STT progress");
                }
            })
        };
        let transcript: Transcript = self
            .stt
            .transcribe_with_progress(&audio, &mut report_progress)
            .await?;
        if transcript.text.split_whitespace().count() == 0 {
            self.set_terminal_status(
                recording_id,
                "failed",
                "failed",
                50,
                Some("no speech detected — the recording is silent (check your microphone)"),
                "Aucune voix détectée dans cet enregistrement",
                false,
                Some("no_speech_detected"),
            )
            .await?;
            tracing::warn!(%recording_id, "pipeline rejected silent recording");
            return Ok(());
        }
        sqlx::query(
            "INSERT INTO transcripts (recording_id, provider, content, language, segments)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (recording_id) DO UPDATE
                SET provider = EXCLUDED.provider,
                    content = EXCLUDED.content,
                    language = EXCLUDED.language,
                    segments = EXCLUDED.segments,
                    sync_version = nextval('sync_version_seq')",
        )
        .bind(recording_id)
        .bind(self.stt.name())
        .bind(&transcript.text)
        .bind(&transcript.language)
        .bind(serde_json::to_value(&transcript.segments)?)
        .execute(&self.db)
        .await?;
        self.update_progress(
            recording_id,
            "transcription_ready",
            68,
            Some(1),
            Some(1),
            "Transcription terminée",
        )
        .await?;

        // 2) Regenerate the chapter pack from every session transcribed so
        // far. Each source recording and transcript remains independent for
        // playback, while the newest study pack reflects the whole chapter.
        let chapter_transcripts: Vec<ChapterTranscriptRow> = sqlx::query_as(
            "SELECT r.id AS recording_id, t.content, t.language, r.created_at
               FROM transcripts t
               JOIN recordings r ON r.id = t.recording_id
              WHERE r.user_id = $1 AND r.chapter_id = $2
                AND btrim(t.content) <> ''
              ORDER BY r.created_at ASC, r.id ASC",
        )
        .bind(rec.user_id)
        .bind(rec.chapter_id)
        .fetch_all(&self.db)
        .await?;
        self.update_progress(
            recording_id,
            "consolidating_chapter",
            72,
            Some(chapter_transcripts.len() as i32),
            Some(chapter_transcripts.len() as i32),
            &format!(
                "Consolidation de {} séance{}",
                chapter_transcripts.len(),
                if chapter_transcripts.len() > 1 {
                    "s"
                } else {
                    ""
                }
            ),
        )
        .await?;
        let previous_summary: Option<String> = sqlx::query_scalar(
            "SELECT content_md
               FROM summaries
              WHERE chapter_id = $1 AND status = 'approved'
              ORDER BY sync_version DESC
              LIMIT 1",
        )
        .bind(rec.chapter_id)
        .fetch_optional(&self.db)
        .await?;
        let cumulative_transcript = merge_chapter_transcripts(
            &chapter_transcripts,
            previous_summary.as_deref(),
            MAX_CUMULATIVE_CONTEXT_CHARS,
        );
        self.update_progress(
            recording_id,
            "generating_material",
            78,
            None,
            None,
            "Création du résumé, des fiches et du quiz",
        )
        .await?;
        let content: GeneratedContent = self
            .generator
            .generate(&chapter_title, &cumulative_transcript)
            .await?;
        let source_recording_ids = chapter_transcripts
            .iter()
            .map(|session| session.recording_id)
            .collect::<Vec<_>>();
        self.update_progress(
            recording_id,
            "saving_material",
            94,
            None,
            None,
            "Finalisation du nouveau matériel",
        )
        .await?;
        self.persist_study_material(
            recording_id,
            rec.chapter_id,
            &source_recording_ids,
            &content,
        )
        .await?;

        self.set_terminal_status(
            recording_id,
            "ready",
            "ready",
            100,
            None,
            "Matériel d’étude prêt",
            false,
            None,
        )
        .await?;
        tracing::info!(
            %recording_id,
            chapter_id = %rec.chapter_id,
            session_count = source_recording_ids.len(),
            "cumulative chapter pipeline complete"
        );
        Ok(())
    }

    async fn persist_study_material(
        &self,
        recording_id: Uuid,
        chapter_id: Uuid,
        source_recording_ids: &[Uuid],
        content: &GeneratedContent,
    ) -> anyhow::Result<()> {
        // Study material is append-only. A later session or an explicit
        // reprocess creates a new version; older packs and their quiz attempts
        // remain available for history, rollback, and offline flexibility.
        let generation_id = Uuid::new_v4();
        let structured_content = serde_json::json!({
            "key_points": content.key_points,
            "takeaway": content.takeaway,
            "flashcards": content.flashcards,
            "generation_kind": "chapter_cumulative",
            "session_count": source_recording_ids.len(),
            "source_recording_ids": source_recording_ids,
            "trigger_recording_id": recording_id,
            "generation_id": generation_id,
        });
        sqlx::query(
            "INSERT INTO summaries
                (recording_id, chapter_id, generation_id, content_md, structured_content, status)
             VALUES ($1, $2, $3, $4, $5, 'approved')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(generation_id)
        .bind(&content.summary_markdown)
        .bind(structured_content)
        .execute(&self.db)
        .await?;

        sqlx::query(
            "INSERT INTO exercises (recording_id, chapter_id, generation_id, items, status)
             VALUES ($1, $2, $3, $4, 'approved')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(generation_id)
        .bind(serde_json::to_value(&content.exercises)?)
        .execute(&self.db)
        .await?;

        sqlx::query(
            "INSERT INTO quizzes (recording_id, chapter_id, generation_id, questions, status)
             VALUES ($1, $2, $3, $4, 'approved')",
        )
        .bind(recording_id)
        .bind(chapter_id)
        .bind(generation_id)
        .bind(serde_json::to_value(&content.quiz)?)
        .execute(&self.db)
        .await?;

        Ok(())
    }

    async fn update_progress(
        &self,
        recording_id: Uuid,
        stage: &str,
        progress_percent: i32,
        stage_current: Option<i32>,
        stage_total: Option<i32>,
        message: &str,
    ) -> anyhow::Result<()> {
        let mut tx = self.db.begin().await?;
        sqlx::query(
            "UPDATE recordings
                SET status = 'processing', pipeline_stage = $2,
                    progress_percent = $3, stage_current = $4,
                    stage_total = $5, status_message = $6,
                    retryable = TRUE, next_retry_at = NULL,
                    error = NULL, error_code = NULL,
                    stage_started_at = CASE WHEN pipeline_stage <> $2
                                            THEN now() ELSE stage_started_at END,
                    last_progress_at = now(), updated_at = now(),
                    sync_version = nextval('sync_version_seq')
              WHERE id = $1",
        )
        .bind(recording_id)
        .bind(stage)
        .bind(progress_percent.clamp(0, 100))
        .bind(stage_current)
        .bind(stage_total)
        .bind(message)
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "INSERT INTO recording_processing_events
                (recording_id, stage, progress_percent, message)
             VALUES ($1, $2, $3, $4)",
        )
        .bind(recording_id)
        .bind(stage)
        .bind(progress_percent.clamp(0, 100))
        .bind(message)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        tracing::info!(
            %recording_id,
            %stage,
            progress_percent = progress_percent.clamp(0, 100),
            stage_current,
            stage_total,
            %message,
            "recording pipeline progress"
        );
        Ok(())
    }

    #[allow(clippy::too_many_arguments)]
    async fn set_terminal_status(
        &self,
        recording_id: Uuid,
        status: &str,
        stage: &str,
        progress_percent: i32,
        error: Option<&str>,
        message: &str,
        retryable: bool,
        error_code: Option<&str>,
    ) -> anyhow::Result<()> {
        let mut tx = self.db.begin().await?;
        sqlx::query(
            "UPDATE recordings
                SET status = $2, pipeline_stage = $3, progress_percent = $4,
                    stage_current = NULL, stage_total = NULL,
                    error = $5, status_message = $6, retryable = $7,
                    error_code = $8, next_retry_at = NULL,
                    stage_started_at = now(), last_progress_at = now(),
                    updated_at = now(), sync_version = nextval('sync_version_seq')
              WHERE id = $1",
        )
        .bind(recording_id)
        .bind(status)
        .bind(stage)
        .bind(progress_percent.clamp(0, 100))
        .bind(error)
        .bind(message)
        .bind(retryable)
        .bind(error_code)
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "INSERT INTO recording_processing_events
                (recording_id, stage, progress_percent, message)
             VALUES ($1, $2, $3, $4)",
        )
        .bind(recording_id)
        .bind(stage)
        .bind(progress_percent.clamp(0, 100))
        .bind(message)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    async fn complete_job(&self, recording_id: Uuid) -> anyhow::Result<()> {
        sqlx::query(
            "UPDATE recording_jobs
                SET state = 'done', locked_at = NULL, worker_id = NULL,
                    last_error = NULL, updated_at = now()
              WHERE recording_id = $1",
        )
        .bind(recording_id)
        .execute(&self.db)
        .await?;
        Ok(())
    }

    async fn fail_or_retry_job(
        &self,
        recording_id: Uuid,
        attempts: i32,
        error: &anyhow::Error,
    ) -> anyhow::Result<()> {
        let raw = error.to_string();
        let (retryable, code, user_message) = classify_pipeline_error(&raw);
        let should_retry = retryable && attempts < 6;
        let delay_seconds = (15_i32
            .saturating_mul(2_i32.saturating_pow(attempts.saturating_sub(1).clamp(0, 6) as u32)))
        .min(15 * 60);
        let mut tx = self.db.begin().await?;
        if should_retry {
            sqlx::query(
                "UPDATE recording_jobs
                    SET state = 'retry_wait',
                        next_attempt_at = now() + make_interval(secs => $2),
                        locked_at = NULL, worker_id = NULL, last_error = $3,
                        updated_at = now()
                  WHERE recording_id = $1",
            )
            .bind(recording_id)
            .bind(delay_seconds as f64)
            .bind(raw.chars().take(1000).collect::<String>())
            .execute(&mut *tx)
            .await?;
            sqlx::query(
                "UPDATE recordings
                    SET status = 'processing', pipeline_stage = 'retry_wait',
                        status_message = $2, retryable = TRUE,
                        next_retry_at = now() + make_interval(secs => $3),
                        error = $4, error_code = $5,
                        stage_started_at = now(), last_progress_at = now(),
                        updated_at = now(), sync_version = nextval('sync_version_seq')
                  WHERE id = $1",
            )
            .bind(recording_id)
            .bind(format!("{user_message} Nouvelle tentative automatique."))
            .bind(delay_seconds as f64)
            .bind(raw.chars().take(1000).collect::<String>())
            .bind(code)
            .execute(&mut *tx)
            .await?;
        } else {
            sqlx::query(
                "UPDATE recording_jobs
                    SET state = 'failed', locked_at = NULL, worker_id = NULL,
                        last_error = $2, updated_at = now()
                  WHERE recording_id = $1",
            )
            .bind(recording_id)
            .bind(raw.chars().take(1000).collect::<String>())
            .execute(&mut *tx)
            .await?;
            sqlx::query(
                "UPDATE recordings
                    SET status = 'failed', pipeline_stage = 'failed',
                        status_message = $2, retryable = $3, next_retry_at = NULL,
                        error = $4, error_code = $5, stage_started_at = now(),
                        last_progress_at = now(), updated_at = now(),
                        sync_version = nextval('sync_version_seq')
                  WHERE id = $1",
            )
            .bind(recording_id)
            .bind(user_message)
            .bind(retryable)
            .bind(raw.chars().take(1000).collect::<String>())
            .bind(code)
            .execute(&mut *tx)
            .await?;
        }
        sqlx::query(
            "INSERT INTO recording_processing_events
                (recording_id, stage, progress_percent, message)
             SELECT id, pipeline_stage, progress_percent, status_message
               FROM recordings WHERE id = $1",
        )
        .bind(recording_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }
}

fn classify_pipeline_error(raw: &str) -> (bool, &'static str, &'static str) {
    let lower = raw.to_lowercase();
    if lower.contains("no such file or directory")
        || lower.contains("ffprobe")
        || lower.contains("ffmpeg")
    {
        return (
            true,
            "media_runtime_unavailable",
            "Le service de transcription est temporairement indisponible.",
        );
    }
    if lower.contains("timeout")
        || lower.contains("timed out")
        || lower.contains("http 429")
        || lower.contains("http 500")
        || lower.contains("http 502")
        || lower.contains("http 503")
        || lower.contains("http 504")
        || lower.contains("connection")
        || lower.contains("storage backend")
    {
        return (
            true,
            "provider_temporarily_unavailable",
            "Le service distant ne répond pas encore.",
        );
    }
    (
        false,
        "processing_failed",
        "Le traitement de cet enregistrement a échoué.",
    )
}

/// Joins a chapter's independent recording transcripts into the chronological
/// source used for cumulative study-material generation. Timestamped audio
/// segments intentionally stay on their original transcript rows; mixing their
/// timelines would make synchronized playback incorrect.
fn merge_chapter_transcripts(
    sessions: &[ChapterTranscriptRow],
    previous_summary: Option<&str>,
    max_chars: usize,
) -> Transcript {
    let full_text = sessions
        .iter()
        .enumerate()
        .map(|(index, session)| {
            format!(
                "Session {} — {}\n{}",
                index + 1,
                session.created_at.format("%Y-%m-%d %H:%M UTC"),
                session.content.trim()
            )
        })
        .collect::<Vec<_>>()
        .join("\n\n");
    let text = if full_text.chars().count() <= max_chars {
        full_text
    } else {
        rolling_chapter_context(sessions, previous_summary, max_chars)
    };
    let language = sessions
        .iter()
        .rev()
        .find_map(|session| session.language.clone());
    Transcript {
        text,
        language,
        segments: Vec::new(),
    }
}

fn rolling_chapter_context(
    sessions: &[ChapterTranscriptRow],
    previous_summary: Option<&str>,
    max_chars: usize,
) -> String {
    let summary = previous_summary.unwrap_or_default().trim();
    let prefix = if summary.is_empty() {
        String::new()
    } else {
        format!("Previous consolidated chapter material:\n{summary}\n\n")
    };
    let remaining = max_chars.saturating_sub(prefix.chars().count());
    let mut selected = Vec::new();
    let mut used = 0_usize;
    for (index, session) in sessions.iter().enumerate().rev() {
        let block = format!(
            "Session {} — {}\n{}",
            index + 1,
            session.created_at.format("%Y-%m-%d %H:%M UTC"),
            session.content.trim()
        );
        let block_len = block.chars().count() + 2;
        if !selected.is_empty() && used + block_len > remaining {
            break;
        }
        let bounded = if block_len > remaining {
            block.chars().take(remaining).collect()
        } else {
            block
        };
        used += bounded.chars().count() + 2;
        selected.push(bounded);
        if used >= remaining {
            break;
        }
    }
    selected.reverse();
    format!(
        "{prefix}Most recent source-session transcripts:\n{}",
        selected.join("\n\n")
    )
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;

    use super::*;

    #[test]
    fn merges_chapter_sessions_chronologically_without_mixing_audio_timelines() {
        let first_id = Uuid::new_v4();
        let second_id = Uuid::new_v4();
        let sessions = vec![
            ChapterTranscriptRow {
                recording_id: first_id,
                content: "Introduction aux vecteurs.".into(),
                language: Some("fr".into()),
                created_at: Utc.with_ymd_and_hms(2026, 8, 3, 8, 0, 0).unwrap(),
            },
            ChapterTranscriptRow {
                recording_id: second_id,
                content: "Applications et exercices.".into(),
                language: Some("fr".into()),
                created_at: Utc.with_ymd_and_hms(2026, 8, 10, 8, 0, 0).unwrap(),
            },
        ];

        let merged = merge_chapter_transcripts(&sessions, None, 60_000);

        assert!(merged.text.starts_with("Session 1 — 2026-08-03"));
        assert!(merged.text.contains("Introduction aux vecteurs."));
        assert!(merged.text.contains("Session 2 — 2026-08-10"));
        assert!(merged.text.ends_with("Applications et exercices."));
        assert_eq!(merged.language.as_deref(), Some("fr"));
        assert!(merged.segments.is_empty());
    }

    #[test]
    fn bounds_large_chapters_using_the_previous_consolidated_material() {
        let sessions = (0..5)
            .map(|index| ChapterTranscriptRow {
                recording_id: Uuid::new_v4(),
                content: format!("Session {index} content {}", "x".repeat(200)),
                language: Some("en".into()),
                created_at: Utc.with_ymd_and_hms(2026, 8, index + 1, 8, 0, 0).unwrap(),
            })
            .collect::<Vec<_>>();

        let merged = merge_chapter_transcripts(
            &sessions,
            Some("Earlier concepts that must remain available."),
            500,
        );

        assert!(merged
            .text
            .contains("Previous consolidated chapter material"));
        assert!(merged
            .text
            .contains("Earlier concepts that must remain available."));
        assert!(merged.text.contains("Session 5"));
        assert!(merged.text.chars().count() <= 560);
    }
}
