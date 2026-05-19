-- Migration: 20260519000001_create_schema.sql
-- All table DDL, constraints, and indexes for School Management App
-- WARNING: Never rename this file after it is applied — Supabase CLI applies in timestamp order

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- teachers
-- ============================================================
CREATE TABLE teachers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  mobile        TEXT UNIQUE NOT NULL,
  school_name   TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- No teacher_id FK here — teachers is the root of the ownership chain

-- ============================================================
-- refresh_tokens
-- ============================================================
CREATE TABLE refresh_tokens (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id   UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  token_hash   TEXT NOT NULL,
  device_hint  TEXT,
  last_used_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON refresh_tokens(teacher_id);
CREATE UNIQUE INDEX ON refresh_tokens(token_hash);
-- token_hash UNIQUE INDEX: every /auth/refresh call queries by token_hash;
-- UNIQUE ensures no duplicate token collisions; indexed for O(log n) lookup

-- ============================================================
-- classes
-- ============================================================
CREATE TABLE classes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  section    TEXT,
  subject    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(teacher_id, name)
-- UNIQUE(teacher_id, name): class names unique per teacher, not globally
);
CREATE INDEX ON classes(teacher_id);

-- ============================================================
-- students
-- ============================================================
CREATE TABLE students (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id    UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  roll_number INTEGER NOT NULL,
  full_name   TEXT NOT NULL,
  photo_url   TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(class_id, roll_number)
-- UNIQUE(class_id, roll_number): roll numbers unique per class, not globally
);
CREATE INDEX ON students(class_id);

-- ============================================================
-- attendance_sessions
-- ============================================================
CREATE TABLE attendance_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id     UUID NOT NULL REFERENCES classes(id),
  -- NOTE: NO CASCADE on class_id — orphan sessions kept for audit trail
  teacher_id   UUID NOT NULL REFERENCES teachers(id),
  date         DATE NOT NULL,
  submitted_at TIMESTAMPTZ,
  is_locked    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(class_id, date)
-- UNIQUE(class_id, date): one attendance session per class per calendar day
);
CREATE INDEX ON attendance_sessions(teacher_id);
-- Supports RLS policy subquery: WHERE teacher_id = auth.uid()
CREATE INDEX ON attendance_sessions(class_id, date);
-- Covers both the UNIQUE constraint and date-range queries from the Go API

-- ============================================================
-- attendance_records
-- ============================================================
CREATE TABLE attendance_records (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id),
  -- NOTE: NO CASCADE on student_id — deleted students remain in records as history
  status     TEXT NOT NULL CHECK (status IN ('present', 'absent', 'leave')),
  marked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  UNIQUE(session_id, student_id)
-- UNIQUE(session_id, student_id): one record per student per session
);
CREATE INDEX ON attendance_records(session_id);
CREATE INDEX ON attendance_records(student_id);
-- student_id index: supports statistics queries (all records for a student across sessions)

-- ============================================================
-- generated_reports
-- ============================================================
CREATE TABLE generated_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id     UUID NOT NULL REFERENCES classes(id),
  teacher_id   UUID NOT NULL REFERENCES teachers(id),
  month        DATE NOT NULL,
  -- month stored as first day of month: e.g. '2026-04-01' for April 2026
  file_type    TEXT NOT NULL CHECK (file_type IN ('pdf', 'excel')),
  file_url     TEXT NOT NULL,
  -- IMPORTANT: store Supabase Storage object PATH, not a signed URL
  -- Signed URLs expire; generate fresh signed URL on each download request
  generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ,
  -- expires_at: set to NOW() + 90 days on insert; cleanup cron queries this column
  UNIQUE(class_id, month, file_type)
-- UNIQUE(class_id, month, file_type): prevents duplicate report generation (idempotency)
-- Cron restart on the 1st won't create duplicate rows
);
CREATE INDEX ON generated_reports(teacher_id);
CREATE INDEX ON generated_reports(class_id, month);
CREATE INDEX ON generated_reports(expires_at);
-- expires_at index: cleanup cron runs DELETE WHERE expires_at < NOW()
