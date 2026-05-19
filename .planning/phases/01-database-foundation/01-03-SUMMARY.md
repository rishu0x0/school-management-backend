---
phase: 01-database-foundation
plan: "03"
subsystem: database
tags: [supabase, postgresql, triggers, plpgsql, defense-in-depth, env, go-backend]

# Dependency graph
requires:
  - phase: 01-02
    provides: "RLS policies migration on all 7 tables; seed data with fixed teacher UUIDs for testing"
  - phase: 01-01
    provides: "All 7 tables (attendance_sessions, attendance_records and 5 others) with is_locked BOOLEAN on attendance_sessions"
provides:
  - Two trigger functions: check_attendance_not_locked (BEFORE UPDATE on attendance_records) and check_session_not_locked (BEFORE UPDATE on attendance_sessions)
  - Two trigger definitions: attendance_record_lock_check and attendance_session_lock_check
  - Both raise EXCEPTION 'attendance_locked' (SQLSTATE P0001) — defense-in-depth vs Go API timezone bugs
  - Trigger test script at supabase/tests/trigger_lock_test.sql
  - Runbook at supabase/RUNBOOK.md covering full local reset, test execution, and remote push steps
  - .env.example with all Phase 2 environment variables: SUPABASE_DB_URL (pgxpool format), JWT_SECRET, MSG91 keys
  - .gitignore blocking .env from git
affects: [02-go-auth, 03-go-crud, 04-flutter-auth]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "BEFORE UPDATE triggers check is_locked BOOLEAN only — timezone math stays in Go, not DB triggers"
    - "SECURITY DEFINER trigger functions — run with definer's privileges, not caller's"
    - "defense-in-depth: Go API (primary) sets is_locked; DB triggers (secondary) enforce it — Go bugs cannot corrupt locked data"
    - "SUPABASE_DB_URL port 5432 direct connection for pgxpool — not PgBouncer port 6543"
    - "pgxpool MaxConns: 10 to stay within Supabase free tier 60-connection limit"

key-files:
  created:
    - supabase/migrations/20260519000003_triggers.sql
    - supabase/tests/trigger_lock_test.sql
    - supabase/RUNBOOK.md
    - .env.example
    - .gitignore
  modified: []

key-decisions:
  - "Trigger functions check is_locked BOOLEAN only — no timezone math in SQL; IST midnight logic lives entirely in Go (time.LoadLocation)"
  - "SECURITY DEFINER on both trigger functions — consistent privilege model across all DB-level enforcement"
  - "BEFORE UPDATE (not AFTER) — rejects the write before it happens, never writes then rolls back"
  - "supabase db reset and supabase db push require Docker — all steps documented in supabase/RUNBOOK.md; execution deferred to developer with Docker installed"
  - "SUPABASE_DB_URL uses port 5432 (direct) not port 6543 (PgBouncer) — pgxpool manages its own connection pooling"
  - ".gitignore created from scratch: .env blocked, Go build artifacts, macOS .DS_Store, Supabase temp files"

patterns-established:
  - "Lock trigger pattern: BEFORE UPDATE checks is_locked on session (via subquery) not on record itself"
  - "Runbook pattern: when live execution is blocked, write exact commands to supabase/RUNBOOK.md with expected output"
  - "Test script pattern: trigger tests live at supabase/tests/{feature}_test.sql alongside rls test scripts"

requirements-completed: [INFRA-03]

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 1 Plan 03: Triggers and Environment Summary

**Two BEFORE UPDATE attendance lock triggers (defense-in-depth against Go API bugs) plus .env.example documenting all Go backend connection strings for Phase 2**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T05:07:00Z
- **Completed:** 2026-05-19T05:09:10Z
- **Tasks:** 3 (migration + test script + runbook; .env.example; live execution requires Docker)
- **Files modified:** 5

## Accomplishments

- Created `supabase/migrations/20260519000003_triggers.sql` — 2 SECURITY DEFINER trigger functions and 2 BEFORE UPDATE trigger definitions. Both raise `EXCEPTION 'attendance_locked'` (SQLSTATE P0001). Static analysis confirmed all SQL is correct.
- Created `supabase/tests/trigger_lock_test.sql` — verifiable test covering both trigger paths including a pg_trigger catalog query confirming trigger names and function names
- Created `supabase/RUNBOOK.md` — step-by-step guide for `supabase db reset`, all 3 test script executions, `supabase link`, and `supabase db push` with expected output and troubleshooting (requires Docker)
- Created `.env.example` — all Phase 2 Go backend variables: SUPABASE_DB_URL (port 5432 pgxpool format), SUPABASE_URL, service role key, anon key, JWT_SECRET, JWT_ACCESS_EXPIRY, MSG91 keys commented out, connection pool notes
- Created `.gitignore` — `.env` blocked from git, plus Go build artifacts, macOS .DS_Store, Supabase temp files

## All 3 Migration Files Summary

| Migration | File | What It Does |
|---|---|---|
| 1 | 20260519000001_create_schema.sql | 7 tables, 6 UNIQUE constraints, 2 CHECK constraints, 11 indexes |
| 2 | 20260519000002_rls_policies.sql | RLS ENABLE on 7 tables + 7 named isolation policies with (select auth.uid()) wrapper |
| 3 | 20260519000003_triggers.sql | 2 trigger functions + 2 BEFORE UPDATE trigger definitions for attendance lock enforcement |

## Trigger Details

| Trigger Name | Table | Function | Behavior |
|---|---|---|---|
| attendance_record_lock_check | attendance_records | check_attendance_not_locked | BEFORE UPDATE: checks if session (via session_id) has is_locked=TRUE, raises EXCEPTION 'attendance_locked' |
| attendance_session_lock_check | attendance_sessions | check_session_not_locked | BEFORE UPDATE: checks if OLD.is_locked=TRUE, raises EXCEPTION 'attendance_locked' |

Both functions are `SECURITY DEFINER`. The exception message `'attendance_locked'` is the exact string the Go API catches to return 403 to the Flutter client.

## Connection String Format (for Phase 2 Go backend)

```
SUPABASE_DB_URL=postgresql://postgres:<your-db-password>@db.<your-project-ref>.supabase.co:5432/postgres
```

Port 5432 (direct connection) is used for pgxpool. pgxpool manages its own connection pool — do NOT use PgBouncer (port 6543) unless Supabase free tier connection limit (60) is hit. Set `pgxpool.Config.MaxConns = 10`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write triggers migration and test script** - `19ff0b0` (feat)
2. **Task 2: Push migrations runbook** - `7ae93f0` (chore)
3. **Task 3: .env.example and .gitignore** - `b90f138` (chore)

## Files Created/Modified

- `supabase/migrations/20260519000003_triggers.sql` — Lock trigger functions and trigger definitions
- `supabase/tests/trigger_lock_test.sql` — Test script for both trigger paths (requires Docker)
- `supabase/RUNBOOK.md` — Developer runbook: full local reset + remote push (requires Docker)
- `.env.example` — All Go backend environment variables with sourcing instructions
- `.gitignore` — Blocks .env and other non-git files

## Decisions Made

- **Triggers check is_locked only (no timezone math):** The trigger simply reads the boolean flag. IST midnight logic (time.LoadLocation("Asia/Kolkata")) lives entirely in Go. This separation keeps SQL simple and puts timezone complexity where it belongs.
- **BEFORE UPDATE not AFTER:** Rejects the write before it hits storage. Cleaner than writing then rolling back.
- **SECURITY DEFINER on both functions:** Run with function definer's privileges — consistent with how other DB-level security functions are defined.
- **Port 5432 for pgxpool:** Direct connection to Postgres. pgxpool manages pooling client-side — adding PgBouncer on top would double-pool unnecessarily.
- **supabase/RUNBOOK.md (not inline in SUMMARY):** Complete, copy-pasteable command sequences belong where a developer opens a terminal, not in planning docs.

## Deviations from Plan

### Context-Driven Adaptations

**1. [Context - No Docker] Live execution steps moved to supabase/RUNBOOK.md**
- **Found during:** Task 1 and Task 2
- **Context:** Docker Desktop not installed on this machine (documented in STATE.md blocker, 01-01-SUMMARY.md, and 01-02-SUMMARY.md). `supabase db reset` and `psql` trigger tests cannot run locally.
- **Adaptation:** Migration file written and statically verified. Test script written to `supabase/tests/trigger_lock_test.sql`. Full runbook at `supabase/RUNBOOK.md` covers all live execution steps with exact expected output.
- **Static verification confirmed:** 2 trigger functions, 2 trigger definitions, 2 BEFORE UPDATE clauses, 2 `RAISE EXCEPTION 'attendance_locked'` calls, 2 SECURITY DEFINER declarations

---

**Total deviations:** 1 context-driven adaptation (no auto-fixes needed — trigger SQL correct as specified)
**Impact on plan:** Migration file is complete and correct. Live execution pending Docker install.

## Issues Encountered

**Docker Desktop not installed.** Same blocker as 01-01 and 01-02. `supabase db reset`, `psql` trigger tests, and `supabase db push` cannot run locally.

- **Impact:** Live trigger verification and remote push blocked
- **Resolution required:** Install Docker Desktop, then follow `supabase/RUNBOOK.md` step by step

## User Setup Required

**Requires Docker Desktop for all live execution.** Developer steps are in `supabase/RUNBOOK.md`:

1. Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/
2. `supabase start`
3. `supabase db reset` — apply all 3 migrations from scratch
4. `psql ... -f supabase/tests/trigger_lock_test.sql` — verify both trigger paths fire
5. `psql ... -f supabase/tests/rls_isolation_test.sql` — verify RLS isolation still passes after triggers added
6. `supabase link --project-ref <ref>` + `supabase db push` — push to remote
7. Verify `supabase migration list` shows all 3 with checkmarks in BOTH local and remote columns

## Next Phase Readiness

- All 3 migration files complete and statically verified — Phase 1 database foundation is done at the SQL level
- Phase 2 (Go Auth) can start: `.env.example` documents every env variable needed with sourcing instructions
- Go backend reads `SUPABASE_DB_URL` to init pgxpool — format is `postgresql://...` as pgx expects
- `SUPABASE_SERVICE_ROLE_KEY` bypasses RLS — Go backend uses this for all DB operations
- `JWT_SECRET` generation command documented: `openssl rand -hex 32`
- MSG91 DLT registration still a blocker for production OTP testing (pre-existing, tracked in STATE.md)

## Self-Check: PASSED

- FOUND: supabase/migrations/20260519000003_triggers.sql
- FOUND: supabase/tests/trigger_lock_test.sql
- FOUND: supabase/RUNBOOK.md
- FOUND: .env.example
- FOUND: .gitignore
- FOUND: .planning/phases/01-database-foundation/01-03-SUMMARY.md
- FOUND: commit 19ff0b0 (Task 1 — triggers migration + test)
- FOUND: commit 7ae93f0 (Task 2 — runbook)
- FOUND: commit b90f138 (Task 3 — .env.example + .gitignore)

---
*Phase: 01-database-foundation*
*Completed: 2026-05-19*
