-- RLS Isolation Test: Two-Teacher Cross-Access Prevention
-- Plan: 01-02 (Task 2)
--
-- REQUIRES DOCKER: Run this after `supabase start` and `supabase db reset`
--
-- Prerequisites (from seed.sql):
--   Teacher 1: id = 00000000-0000-0000-0000-000000000001, owns Class 5A (id = 00000000-0000-0000-0000-000000000010)
--   Teacher 2: id = 00000000-0000-0000-0000-000000000002, owns Class 6B (id = 00000000-0000-0000-0000-000000000020)
--
-- Run via:
--   psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_isolation_test.sql
--
-- All 6 tests must produce the expected row counts.

-- ============================================================
-- Test 1: Teacher 1 can see their own class
-- Expected: 1 row (Class 5A)
-- ============================================================
\echo '--- Test 1: Teacher 1 sees their own class (expected: 1 row) ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';
SELECT id, name, teacher_id FROM classes;
-- Expected: 1 row for Class 5A owned by Teacher 1
ROLLBACK;

-- ============================================================
-- Test 2: Teacher 1 cannot see Teacher 2's class
-- Expected: 0 rows
-- ============================================================
\echo '--- Test 2: Teacher 1 cannot see Teacher 2 class (expected: 0 rows) ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';
SELECT id, name FROM classes WHERE id = '00000000-0000-0000-0000-000000000020';
-- Expected: 0 rows (RLS filters out Teacher 2's class)
ROLLBACK;

-- ============================================================
-- Test 3: Teacher 2 can see their own class
-- Expected: 1 row (Class 6B)
-- ============================================================
\echo '--- Test 3: Teacher 2 sees their own class (expected: 1 row) ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}';
SELECT id, name, teacher_id FROM classes;
-- Expected: 1 row for Class 6B owned by Teacher 2
ROLLBACK;

-- ============================================================
-- Test 4: Teacher 2 cannot see Teacher 1's class
-- Expected: 0 rows
-- ============================================================
\echo '--- Test 4: Teacher 2 cannot see Teacher 1 class (expected: 0 rows) ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}';
SELECT id, name FROM classes WHERE id = '00000000-0000-0000-0000-000000000010';
-- Expected: 0 rows (RLS filters out Teacher 1's class)
ROLLBACK;

-- ============================================================
-- Test 5: Anon role (no JWT) sees zero rows from classes
-- Expected: 0 rows (anon role has no policy, RLS blocks all)
-- ============================================================
\echo '--- Test 5: Anon (no JWT) sees zero rows from classes (expected: 0 rows) ---'
BEGIN;
SET LOCAL role = anon;
SELECT id, name FROM classes;
-- Expected: 0 rows (anon role has no matching RLS policy)
ROLLBACK;

-- ============================================================
-- Test 6: Teachers table — Teacher 1 can only see their own row
-- Expected: 1 row (only Teacher 1's row, not Teacher 2's)
-- ============================================================
\echo '--- Test 6: Teacher 1 sees only their own teachers row (expected: 1 row) ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';
SELECT id, name FROM teachers;
-- Expected: 1 row (only Teacher 1's own row, not Teacher 2's)
ROLLBACK;

-- ============================================================
-- Test 7: Service role bypasses RLS — sees all rows
-- Expected: 2 rows (both Teacher 1 and Teacher 2 classes visible)
-- ============================================================
\echo '--- Test 7: Service role (postgres superuser) sees all rows (expected: 2 rows) ---'
-- Note: psql with postgres superuser role always bypasses RLS (service role behaviour)
SELECT count(*) AS total_classes FROM classes;
-- Expected: 2 rows (service/postgres role sees all — correct behaviour for Go backend)

-- ============================================================
-- Summary query: Validate row counts across all ownership chains
-- ============================================================
\echo '--- Summary: RLS ownership chain validation as Teacher 1 ---'
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';
SELECT
  (SELECT count(*) FROM classes)            AS my_classes,        -- Expected: 1
  (SELECT count(*) FROM students)           AS my_students,       -- Expected: 0 (no students in seed)
  (SELECT count(*) FROM attendance_sessions) AS my_sessions,      -- Expected: 0 (no sessions in seed)
  (SELECT count(*) FROM attendance_records) AS my_records,        -- Expected: 0 (no records in seed)
  (SELECT count(*) FROM generated_reports)  AS my_reports,        -- Expected: 0 (no reports in seed)
  (SELECT count(*) FROM refresh_tokens)     AS my_tokens;         -- Expected: 0 (no tokens in seed)
ROLLBACK;
