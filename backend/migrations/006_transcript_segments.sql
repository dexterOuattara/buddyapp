-- Persist sentence-level timecodes so the mobile player can display and
-- auto-scroll a transcript while remaining fully usable offline.

ALTER TABLE transcripts
    ADD COLUMN language TEXT,
    ADD COLUMN segments JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN sync_version BIGINT NOT NULL DEFAULT nextval('sync_version_seq');

CREATE INDEX transcripts_sync_version_idx
    ON transcripts (sync_version);
