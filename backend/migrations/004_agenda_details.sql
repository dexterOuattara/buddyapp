ALTER TABLE agenda_items
    ADD COLUMN kind TEXT NOT NULL DEFAULT 'course',
    ADD COLUMN subject TEXT,
    ADD COLUMN location TEXT,
    ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'none',
    ADD COLUMN recurrence_until TIMESTAMPTZ,
    ADD COLUMN reminder_minutes INT,
    ADD COLUMN chapter_client_uuid UUID;

ALTER TABLE agenda_items
    ADD CONSTRAINT agenda_items_kind_check
        CHECK (kind IN ('course', 'revision', 'reminder')),
    ADD CONSTRAINT agenda_items_recurrence_check
        CHECK (recurrence IN ('none', 'weekly')),
    ADD CONSTRAINT agenda_items_reminder_check
        CHECK (reminder_minutes IS NULL OR reminder_minutes >= 0);
