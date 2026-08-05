-- BuddyWize initial schema.
-- Offline-first sync contract:
--   * every syncable row carries client_uuid (client-generated, UNIQUE => idempotent upserts)
--   * every syncable row carries sync_version drawn from a single global sequence,
--     so clients can delta-pull with ?since=<cursor> across all resource types
--   * deletions are soft (deleted_at) so deltas can propagate them

CREATE SEQUENCE IF NOT EXISTS sync_version_seq;

-- ---------------------------------------------------------------- users/auth

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'student', -- student | admin
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);

-- ---------------------------------------------------------------- content

CREATE TABLE institutions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE courses (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    institution_id UUID REFERENCES institutions(id),
    client_uuid    UUID UNIQUE,
    title          TEXT NOT NULL,
    description    TEXT,
    deleted_at     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version   BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_courses_user_sync ON courses (user_id, sync_version);

CREATE TABLE lessons (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id    UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    client_uuid  UUID UNIQUE,
    title        TEXT NOT NULL,
    position     INT NOT NULL DEFAULT 0,
    deleted_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_lessons_sync ON lessons (sync_version);

CREATE TABLE chapters (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lesson_id    UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    client_uuid  UUID UNIQUE,
    title        TEXT NOT NULL,
    position     INT NOT NULL DEFAULT 0,
    deleted_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_chapters_sync ON chapters (sync_version);

CREATE TABLE agenda_items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_uuid  UUID UNIQUE,
    title        TEXT NOT NULL,
    notes        TEXT,
    starts_at    TIMESTAMPTZ,
    ends_at      TIMESTAMPTZ,
    deleted_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_agenda_user_sync ON agenda_items (user_id, sync_version);

-- ---------------------------------------------------------------- recordings

CREATE TABLE upload_sessions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_uuid    UUID NOT NULL UNIQUE, -- client uuid of the future recording
    chapter_id     UUID NOT NULL REFERENCES chapters(id),
    path           TEXT NOT NULL,
    received_bytes BIGINT NOT NULL DEFAULT 0,
    duration_secs  INT,
    completed_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recordings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    chapter_id    UUID NOT NULL REFERENCES chapters(id),
    client_uuid   UUID UNIQUE,
    storage_path  TEXT NOT NULL,
    duration_secs INT,
    -- uploaded | processing | ready | failed | blocked
    status        TEXT NOT NULL DEFAULT 'uploaded',
    error         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version  BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_recordings_user_sync ON recordings (user_id, sync_version);

CREATE TABLE transcripts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL UNIQUE REFERENCES recordings(id) ON DELETE CASCADE,
    provider     TEXT NOT NULL,
    content      TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- study material

CREATE TABLE summaries (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    chapter_id   UUID NOT NULL REFERENCES chapters(id),
    content_md   TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'pending_review', -- pending_review | approved | rejected
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_summaries_sync ON summaries (sync_version);

CREATE TABLE exercises (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    chapter_id   UUID NOT NULL REFERENCES chapters(id),
    items        JSONB NOT NULL, -- [{ prompt, guidance, answer }]
    status       TEXT NOT NULL DEFAULT 'pending_review',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_exercises_sync ON exercises (sync_version);

CREATE TABLE quizzes (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    chapter_id   UUID NOT NULL REFERENCES chapters(id),
    questions    JSONB NOT NULL, -- [{ prompt, choices, correct_index, explanation }]
    status       TEXT NOT NULL DEFAULT 'pending_review',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq')
);
CREATE INDEX idx_quizzes_sync ON quizzes (sync_version);

CREATE TABLE quiz_attempts (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quiz_id    UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score      INT NOT NULL,
    total      INT NOT NULL,
    answers    JSONB,
    taken_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- billing

CREATE TABLE subscriptions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan       TEXT NOT NULL, -- trial | monthly | annual
    status     TEXT NOT NULL DEFAULT 'active', -- active | expired | cancelled
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_subscriptions_user ON subscriptions (user_id);

CREATE TABLE discount_codes (
    code       TEXT PRIMARY KEY,
    kind       TEXT NOT NULL, -- percent | fixed
    value      INT NOT NULL,
    max_uses   INT,
    used       INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
