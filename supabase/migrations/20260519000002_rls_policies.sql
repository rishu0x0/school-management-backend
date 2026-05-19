-- Migration: 20260519000002_rls_policies.sql
-- Row Level Security policies for all tables
--
-- Architecture note: The Go backend connects with the SERVICE ROLE KEY which
-- bypasses RLS entirely. These policies apply to:
--   (a) Supabase Dashboard access
--   (b) Direct PostgREST (anon key) queries
--   (c) Any future code using a non-service-role key
--
-- Performance: ALL auth.uid() calls use (select auth.uid()) wrapper.
-- This triggers PostgreSQL's initPlan optimization: auth.uid() is evaluated
-- ONCE per query (not once per row). Supabase docs report 94-99% improvement.
-- NEVER remove the (select ...) wrapper -- bare auth.uid() causes O(n) evaluation.
--
-- RLS ownership chain:
--   teachers.id = teacher_id
--   -> classes.teacher_id
--   -> students.class_id (subquery via classes)
--   -> attendance_sessions.teacher_id (direct FK)
--   -> attendance_records.session_id (subquery via attendance_sessions)
--   -> generated_reports.teacher_id (direct FK)

-- ============================================================
-- Enable RLS on all tables
-- ============================================================
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_reports ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- teachers: each teacher can only see and modify their own row
-- ============================================================
CREATE POLICY "teachers_isolation" ON teachers
  FOR ALL
  TO authenticated
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

-- ============================================================
-- refresh_tokens: teacher sees only their own device tokens
-- ============================================================
CREATE POLICY "refresh_tokens_isolation" ON refresh_tokens
  FOR ALL
  TO authenticated
  USING (teacher_id = (select auth.uid()))
  WITH CHECK (teacher_id = (select auth.uid()));

-- ============================================================
-- classes: teacher sees only their own classes
-- ============================================================
CREATE POLICY "classes_isolation" ON classes
  FOR ALL
  TO authenticated
  USING (teacher_id = (select auth.uid()))
  WITH CHECK (teacher_id = (select auth.uid()));

-- ============================================================
-- students: teacher sees students in classes they own
-- Subquery pattern (NOT a join) -- put auth.uid() in inner query
-- classes(teacher_id) has a B-tree index -- this subquery is O(log n)
-- ============================================================
CREATE POLICY "students_isolation" ON students
  FOR ALL
  TO authenticated
  USING (
    class_id IN (
      SELECT id FROM classes
      WHERE teacher_id = (select auth.uid())
    )
  )
  WITH CHECK (
    class_id IN (
      SELECT id FROM classes
      WHERE teacher_id = (select auth.uid())
    )
  );

-- ============================================================
-- attendance_sessions: direct teacher_id FK -- simple ownership check
-- attendance_sessions(teacher_id) is indexed
-- ============================================================
CREATE POLICY "attendance_sessions_isolation" ON attendance_sessions
  FOR ALL
  TO authenticated
  USING (teacher_id = (select auth.uid()))
  WITH CHECK (teacher_id = (select auth.uid()));

-- ============================================================
-- attendance_records: two-level chain -- record -> session -> teacher
-- attendance_sessions(teacher_id) is indexed (inner query is O(log n))
-- attendance_records(session_id) is indexed (outer filter is O(log n))
-- ============================================================
CREATE POLICY "attendance_records_isolation" ON attendance_records
  FOR ALL
  TO authenticated
  USING (
    session_id IN (
      SELECT id FROM attendance_sessions
      WHERE teacher_id = (select auth.uid())
    )
  )
  WITH CHECK (
    session_id IN (
      SELECT id FROM attendance_sessions
      WHERE teacher_id = (select auth.uid())
    )
  );

-- ============================================================
-- generated_reports: direct teacher_id FK -- simple ownership check
-- generated_reports(teacher_id) is indexed
-- ============================================================
CREATE POLICY "generated_reports_isolation" ON generated_reports
  FOR ALL
  TO authenticated
  USING (teacher_id = (select auth.uid()))
  WITH CHECK (teacher_id = (select auth.uid()));
