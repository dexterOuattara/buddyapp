-- Durable, observable recording processing.
--
-- The coarse `recordings.status` remains the compatibility/terminal state,
-- while these fields expose the current pipeline step to mobile clients.
ALTER TABLE recordings
    ADD COLUMN pipeline_stage TEXT NOT NULL DEFAULT 'queued',
    ADD COLUMN progress_percent INT NOT NULL DEFAULT 0,
    ADD COLUMN stage_current INT,
    ADD COLUMN stage_total INT,
    ADD COLUMN status_message TEXT,
    ADD COLUMN retryable BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN attempt_count INT NOT NULL DEFAULT 0,
    ADD COLUMN next_retry_at TIMESTAMPTZ,
    ADD COLUMN error_code TEXT,
    ADD COLUMN stage_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN last_progress_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE recordings
    ADD CONSTRAINT recordings_progress_percent_check
    CHECK (progress_percent BETWEEN 0 AND 100);

UPDATE recordings
SET pipeline_stage = CASE status
        WHEN 'ready' THEN 'ready'
        WHEN 'failed' THEN 'failed'
        WHEN 'blocked' THEN 'blocked'
        WHEN 'processing' THEN 'queued'
        ELSE 'queued'
    END,
    progress_percent = CASE status
        WHEN 'ready' THEN 100
        WHEN 'failed' THEN 0
        WHEN 'blocked' THEN 0
        WHEN 'processing' THEN 45
        ELSE 40
    END,
    status_message = CASE status
        WHEN 'ready' THEN 'Matériel d’étude prêt'
        WHEN 'failed' THEN 'Le traitement a échoué'
        WHEN 'blocked' THEN 'Traitement indisponible'
        WHEN 'processing' THEN 'Reprise du traitement en attente'
        ELSE 'En attente de traitement'
    END,
    retryable = status NOT IN ('ready', 'blocked');

-- PostgreSQL is the durable queue. A process restart cannot lose a job and
-- stale `running` jobs can safely be reclaimed after their lease expires.
CREATE TABLE recording_jobs (
    recording_id UUID PRIMARY KEY REFERENCES recordings(id) ON DELETE CASCADE,
    state TEXT NOT NULL DEFAULT 'queued',
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_at TIMESTAMPTZ,
    worker_id UUID,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT recording_jobs_state_check
        CHECK (state IN ('queued', 'running', 'retry_wait', 'done', 'failed'))
);
CREATE INDEX idx_recording_jobs_ready
    ON recording_jobs (state, next_attempt_at, created_at);

INSERT INTO recording_jobs (recording_id, state)
SELECT id, 'queued'
FROM recordings
WHERE status IN ('uploaded', 'processing')
ON CONFLICT (recording_id) DO NOTHING;

-- Append-only diagnostic timeline. It deliberately contains only operational
-- metadata, never audio or transcript text.
CREATE TABLE recording_processing_events (
    id BIGSERIAL PRIMARY KEY,
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    stage TEXT NOT NULL,
    progress_percent INT NOT NULL,
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_recording_processing_events_recording
    ON recording_processing_events (recording_id, id);
