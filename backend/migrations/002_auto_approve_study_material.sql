-- Auto-approve all study material: the admin moderation gate has been
-- removed (see commit `feat: auto-approve AI study material`). Existing
-- rows still sitting in `pending_review` are surfaced to mobile on the
-- next delta sync.
UPDATE summaries  SET status = 'approved' WHERE status = 'pending_review';
UPDATE exercises  SET status = 'approved' WHERE status = 'pending_review';
UPDATE quizzes    SET status = 'approved' WHERE status = 'pending_review';