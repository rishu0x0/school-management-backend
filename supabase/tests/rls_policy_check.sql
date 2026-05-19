-- RLS Policy Completeness Verification
-- Plan: 01-02 (Task 3)
--
-- REQUIRES DOCKER: Run this after `supabase start` and `supabase db reset`
--
-- Run via:
--   psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_policy_check.sql
--
-- All three checks must return the expected results.

-- ============================================================
-- Check 1: RLS enabled on all 7 tables
-- Expected: 7 rows, all with rowsecurity = true
-- ============================================================
\echo '--- Check 1: RLS enabled on all 7 tables (expected: 7 rows, all rowsecurity=true) ---'
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'teachers', 'refresh_tokens', 'classes', 'students',
    'attendance_sessions', 'attendance_records', 'generated_reports'
  )
ORDER BY tablename;

-- Quick count assertion:
SELECT count(*) AS rls_enabled_count
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'teachers', 'refresh_tokens', 'classes', 'students',
    'attendance_sessions', 'attendance_records', 'generated_reports'
  )
  AND rowsecurity = TRUE;
-- Expected: 7

-- ============================================================
-- Check 2: All 7 policies exist with correct names
-- Expected: 7 rows, one per table, all FOR ALL
-- ============================================================
\echo '--- Check 2: All 7 named policies exist (expected: 7 rows) ---'
SELECT tablename, policyname, cmd, roles, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;
-- Expected policies:
--   attendance_records:  "attendance_records_isolation"  FOR ALL
--   attendance_sessions: "attendance_sessions_isolation" FOR ALL
--   classes:             "classes_isolation"             FOR ALL
--   generated_reports:   "generated_reports_isolation"  FOR ALL
--   refresh_tokens:      "refresh_tokens_isolation"     FOR ALL
--   students:            "students_isolation"            FOR ALL
--   teachers:            "teachers_isolation"            FOR ALL

SELECT count(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public';
-- Expected: 7

-- ============================================================
-- Check 3: initPlan wrapper verification
-- All policies must use (select auth.uid()) NOT bare auth.uid()
-- Expected: 0 rows (any row = a policy missing the wrapper)
-- ============================================================
\echo '--- Check 3: initPlan wrapper check (expected: 0 rows) ---'
SELECT tablename, policyname, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND qual NOT LIKE '%(select auth.uid())%'
  AND qual IS NOT NULL;
-- Expected: 0 rows
-- If any rows appear, open supabase/migrations/20260519000002_rls_policies.sql
-- and fix the affected policy to use (select auth.uid()) instead of auth.uid()

SELECT count(*) AS policies_missing_wrapper
FROM pg_policies
WHERE schemaname = 'public'
  AND qual NOT LIKE '%(select auth.uid())%'
  AND qual IS NOT NULL;
-- Expected: 0
