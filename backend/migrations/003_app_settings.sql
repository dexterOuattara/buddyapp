-- Runtime-tunable application settings (admin can change from the UI
-- without a restart or rebuild). Hot path reads through SettingsCache in
-- buddywize-core; the cache is invalidated whenever a row is updated.
CREATE TABLE app_settings (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Seed the default reasoning model used by the pipeline's study-material
-- generator. The admin can swap to a different model at any time via
-- PUT /api/admin/study_generator.
INSERT INTO app_settings (key, value) VALUES
    ('study_generator_model', '@cf/deepseek-ai/deepseek-r1-distill-qwen-32b')
ON CONFLICT (key) DO NOTHING;