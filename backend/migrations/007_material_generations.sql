-- Every AI run creates one immutable, internally consistent study pack.
-- The shared generation id lets clients switch between historical summary,
-- exercise, and quiz versions without mixing rows from different sessions.

ALTER TABLE summaries ADD COLUMN generation_id UUID;
ALTER TABLE exercises ADD COLUMN generation_id UUID;
ALTER TABLE quizzes ADD COLUMN generation_id UUID;

CREATE INDEX summaries_chapter_generation_idx
    ON summaries (chapter_id, generation_id);
CREATE INDEX exercises_chapter_generation_idx
    ON exercises (chapter_id, generation_id);
CREATE INDEX quizzes_chapter_generation_idx
    ON quizzes (chapter_id, generation_id);
