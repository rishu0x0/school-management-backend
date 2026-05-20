-- Reports table for tracking generated PDF/Excel files
CREATE TABLE IF NOT EXISTS reports (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id    UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    class_id      UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    month         TEXT NOT NULL,        -- YYYY-MM
    format        TEXT NOT NULL CHECK (format IN ('pdf', 'excel')),
    storage_path  TEXT,                 -- relative path in Supabase Storage bucket
    file_name     TEXT,                 -- display file name
    status        TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'processing', 'ready', 'error')),
    error_msg     TEXT,
    signed_url    TEXT,
    signed_url_expires_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '90 days')
);

CREATE INDEX IF NOT EXISTS reports_teacher_id_idx ON reports(teacher_id);
CREATE INDEX IF NOT EXISTS reports_class_id_month_idx ON reports(class_id, month);
CREATE INDEX IF NOT EXISTS reports_expires_at_idx ON reports(expires_at);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "teachers_own_reports" ON reports
    FOR ALL
    USING (teacher_id = (current_setting('request.jwt.claims', true)::jsonb->>'teacher_id')::uuid);
