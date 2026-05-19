---
phase: 01-database-foundation
plan: "02"
subsystem: database
tags: [supabase, postgresql, rls, row-level-security, policies, auth.uid, initplan]

# Dependency graph
requires:
  - phase: 01-01
    provides: "All 7 tables (teachers, refresh_tokens, classes, students, attendance_sessions, attendance_records, generated_reports) and seed data with fixed UUIDs for RLS isolation testing"
provides:
  - RLS enabled on all 7 tables (ALTER TABLE ... ENABLE ROW LEVEL SECURITY)
  - 7 named isolation policies — one per table, FOR ALL, TO authenticated
  - initPlan-optimized USING/WITH CHECK clauses using (select auth.uid()) wrapper
  - Two-level ownership chain subqueries for students (via classes) and attendance_records (via attendance_sessions)
  - Two-teacher SQL isolation test script (supabase/tests/rls_isolation_test.sql)
  - Policy completeness verification script (supabase/tests/rls_policy_check.sql)
affects: [01-03-triggers, 02-go-auth, 03-go-crud, 04-flutter-auth]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "(select auth.uid()) wrapper on all RLS policy clauses — triggers PostgreSQL initPlan optimization, evaluates auth.uid() once per query not once per row"
    - "Subquery pattern (NOT JOIN) for two-level ownership chains — students via classes, attendance_records via attendance_sessions"
    - "Named policies follow _isolation suffix convention — one policy per table covering FOR ALL operations"
    - "Service role key bypasses RLS entirely — Go backend uses service role, RLS applies to dashboard/PostgREST/anon key access"

key-files:
  created:
    - supabase/migrations/20260519000002_rls_policies.sql
    - supabase/tests/rls_isolation_test.sql
    - supabase/tests/rls_policy_check.sql
  modified: []

key-decisions:
  - "(select auth.uid()) wrapper on all policies — initPlan optimization prevents O(n) auth.uid() evaluation; NEVER use bare auth.uid() in RLS policies"
  - "FOR ALL policies (not per-operation) — single policy per table covers SELECT/INSERT/UPDATE/DELETE; simpler to audit than per-operation policies"
  - "Subquery pattern over JOIN for students and attendance_records — auth.uid() placed in inner query, outer filter uses indexed FKs; O(log n) both ways"
  - "No anon policy on any table — anon role has no matching policy, RLS blocks all unauthenticated direct PostgREST access"
  - "Live db reset and psql isolation tests marked as requires-Docker — files are correct but live execution blocked until Docker Desktop is installed"

patterns-established:
  - "RLS policy naming: {table}_isolation — consistent naming for all 7 policies"
  - "initPlan wrapper: (select auth.uid()) in USING and WITH CHECK, never bare auth.uid()"
  - "Test scripts in supabase/tests/ — isolation tests and verification queries separated from migrations"

requirements-completed: [INFRA-03]

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 1 Plan 02: RLS Policies Summary

**Row Level Security enabled on all 7 tables with (select auth.uid()) initPlan-optimized isolation policies and a two-teacher SQL cross-access prevention test suite**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T05:02:23Z
- **Completed:** 2026-05-19T05:04:00Z
- **Tasks:** 3 (migration file + 2 test scripts; live db reset requires Docker)
- **Files modified:** 3

## Accomplishments

- Created `supabase/migrations/20260519000002_rls_policies.sql` — 7 ENABLE ROW LEVEL SECURITY statements and 7 CREATE POLICY statements covering all tables
- All 14 USING/WITH CHECK clauses use `(select auth.uid())` wrapper for initPlan optimization — zero bare `auth.uid()` calls in policy clauses
- Implemented two-level ownership chain subqueries: students (via classes.teacher_id) and attendance_records (via attendance_sessions.teacher_id)
- Created `supabase/tests/rls_isolation_test.sql` — 7 tests covering Teacher 1/2 cross-access prevention, anon role blocking, teachers table isolation, and service role bypass verification
- Created `supabase/tests/rls_policy_check.sql` — 3 verification checks for pg_tables rowsecurity, pg_policies count, and initPlan wrapper completeness

## Policy Names and USING Clause Patterns

| Table | Policy Name | USING Clause Pattern |
|---|---|---|
| teachers | teachers_isolation | `(select auth.uid()) = id` |
| refresh_tokens | refresh_tokens_isolation | `teacher_id = (select auth.uid())` |
| classes | classes_isolation | `teacher_id = (select auth.uid())` |
| students | students_isolation | `class_id IN (SELECT id FROM classes WHERE teacher_id = (select auth.uid()))` |
| attendance_sessions | attendance_sessions_isolation | `teacher_id = (select auth.uid())` |
| attendance_records | attendance_records_isolation | `session_id IN (SELECT id FROM attendance_sessions WHERE teacher_id = (select auth.uid()))` |
| generated_reports | generated_reports_isolation | `teacher_id = (select auth.uid())` |

## Task Commits

Each task was committed atomically:

1. **Task 1: Write RLS policies migration for all 7 tables** - `3d2334b` (feat)
2. **Task 2: Two-teacher RLS isolation test script** - `4bf07ad` (test)
3. **Task 3: RLS policy completeness verification script** - `f956d9b` (test)

## Files Created/Modified

- `supabase/migrations/20260519000002_rls_policies.sql` — RLS ENABLE + CREATE POLICY statements for all 7 tables with (select auth.uid()) wrapper
- `supabase/tests/rls_isolation_test.sql` — 7 SQL tests for two-teacher cross-access prevention (requires Docker to execute)
- `supabase/tests/rls_policy_check.sql` — 3 pg_tables/pg_policies verification queries (requires Docker to execute)

## Isolation Test Results

Live test execution is blocked (requires Docker Desktop). Tests are written to `supabase/tests/rls_isolation_test.sql` and verified correct via static analysis. Expected results when run:

| Test | As Teacher | Query | Expected Count |
|---|---|---|---|
| Test 1 | Teacher 1 | SELECT FROM classes | 1 (Class 5A) |
| Test 2 | Teacher 1 | SELECT FROM classes WHERE id = Teacher 2's class | 0 |
| Test 3 | Teacher 2 | SELECT FROM classes | 1 (Class 6B) |
| Test 4 | Teacher 2 | SELECT FROM classes WHERE id = Teacher 1's class | 0 |
| Test 5 | anon | SELECT FROM classes | 0 |
| Test 6 | Teacher 1 | SELECT FROM teachers | 1 (own row only) |
| Test 7 | postgres (service) | SELECT count(*) FROM classes | 2 (bypasses RLS) |

## Decisions Made

- **(select auth.uid()) wrapper required on all policies**: initPlan optimization evaluates auth.uid() once per query (not per row). Supabase docs report 94-99% performance improvement. NEVER remove this wrapper.
- **FOR ALL policies over per-operation policies**: Single policy per table is simpler to audit. Go backend uses service role key and bypasses RLS anyway, so per-operation granularity provides no benefit.
- **Subquery pattern (not JOIN) for two-level chains**: `class_id IN (SELECT id FROM classes WHERE teacher_id = ...)` keeps auth.uid() in the inner query. Both classes(teacher_id) and students(class_id) are indexed, so both parts are O(log n).

## Deviations from Plan

### Modified Execution (Context-Driven)

**1. [Context - No Docker] Test scripts written to files instead of executed live**
- **Found during:** Task 2 and Task 3
- **Context:** Docker Desktop not installed on this machine (documented in STATE.md and 01-01-SUMMARY.md)
- **Adaptation:** Tasks 2 and 3 SQL is written to `supabase/tests/rls_isolation_test.sql` and `supabase/tests/rls_policy_check.sql` rather than executed via psql
- **Static verification:** Migration file verified correct via grep — 7 ENABLE statements, 7 CREATE POLICY statements, 15 `(select auth.uid())` usages, zero bare `auth.uid()` in USING/WITH CHECK clauses
- **Files created:** supabase/tests/rls_isolation_test.sql, supabase/tests/rls_policy_check.sql

---

**Total deviations:** 1 context-driven adaptation (no auto-fixes needed — migration SQL was correct as specified)
**Impact on plan:** Migration file is complete and correct. Live execution pending Docker install.

## Issues Encountered

**Docker Desktop not installed.** Same blocker as 01-01. `supabase db reset` and `psql` isolation tests cannot run locally.

- **Impact:** Live verification of RLS policies blocked; tests written to files for execution after Docker install
- **Resolution required:** Install Docker Desktop, then:
  ```bash
  cd "/Users/rishujain/Desktop/Everything/School Management"
  supabase start
  supabase db reset
  psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_isolation_test.sql
  psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_policy_check.sql
  ```

## User Setup Required (Requires Docker)

To run live verification after installing Docker Desktop:

1. Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/
2. Start Docker Desktop
3. From project root:
   ```bash
   supabase start
   supabase db reset
   ```
4. Run isolation tests:
   ```bash
   psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_isolation_test.sql
   ```
5. Run policy completeness check:
   ```bash
   psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_policy_check.sql
   ```
6. Expected: all 7 isolation tests pass, pg_tables shows 7 rowsecurity=true, pg_policies shows 7 policies, initPlan wrapper check returns 0 rows

## Next Phase Readiness

- Migration file `20260519000002_rls_policies.sql` is complete and correct — applies immediately after Docker install
- Plan 01-03 (triggers) can proceed: trigger migration will be 20260519000003_triggers.sql, applied after the RLS migration
- RLS isolation test scripts are ready for live execution when Docker is available
- Go backend (Phase 2) uses service role key and bypasses RLS — no changes needed to backend code for RLS

## Self-Check: PASSED

- FOUND: supabase/migrations/20260519000002_rls_policies.sql
- FOUND: supabase/tests/rls_isolation_test.sql
- FOUND: supabase/tests/rls_policy_check.sql
- FOUND: .planning/phases/01-database-foundation/01-02-SUMMARY.md
- FOUND: commit 3d2334b (Task 1 — RLS migration)
- FOUND: commit 4bf07ad (Task 2 — isolation test script)
- FOUND: commit f956d9b (Task 3 — policy completeness script)

---
*Phase: 01-database-foundation*
*Completed: 2026-05-19*
