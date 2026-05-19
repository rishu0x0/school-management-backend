-- supabase/seed.sql
-- Loaded automatically by `supabase db reset` after all migrations
-- Two deterministic test teachers for RLS isolation testing (plan 01-02)
-- Teacher 1 UUID: 00000000-0000-0000-0000-000000000001
-- Teacher 2 UUID: 00000000-0000-0000-0000-000000000002

-- Use ON CONFLICT DO NOTHING so seed.sql is idempotent (safe to re-run)
INSERT INTO teachers (id, name, mobile, school_name, password_hash, is_verified)
VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'Test Teacher One',
    '9876543210',
    'Green Valley School',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2QoCsec6Zm',
    TRUE
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'Test Teacher Two',
    '9876543211',
    'Blue Hills School',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj2QoCsec6Zm',
    TRUE
  )
ON CONFLICT (id) DO NOTHING;

-- Teacher 1 owns this class — used in isolation tests to confirm Teacher 2 cannot see it
INSERT INTO classes (id, teacher_id, name, section, subject)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001',
  'Class 5A',
  'A',
  'Mathematics'
)
ON CONFLICT (id) DO NOTHING;

-- Teacher 2 owns this class — used in isolation tests to confirm Teacher 1 cannot see it
INSERT INTO classes (id, teacher_id, name, section, subject)
VALUES (
  '00000000-0000-0000-0000-000000000020',
  '00000000-0000-0000-0000-000000000002',
  'Class 6B',
  'B',
  'Science'
)
ON CONFLICT (id) DO NOTHING;
