-- Structured learning content and offline-first, idempotent quiz attempts.

ALTER TABLE summaries
    ADD COLUMN structured_content JSONB;

ALTER TABLE quiz_attempts
    ADD COLUMN client_uuid UUID;

UPDATE quiz_attempts
   SET client_uuid = gen_random_uuid()
 WHERE client_uuid IS NULL;

ALTER TABLE quiz_attempts
    ALTER COLUMN client_uuid SET NOT NULL;

CREATE UNIQUE INDEX quiz_attempts_client_uuid_unique
    ON quiz_attempts (client_uuid);

CREATE INDEX quiz_attempts_user_taken_at
    ON quiz_attempts (user_id, taken_at DESC);
