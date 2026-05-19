# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-19)

**Core value:** A teacher can open the app, swipe through their class in under 2 minutes, and have attendance recorded — with monthly reports generated automatically on the 1st of each month.
**Current focus:** Phase 1 — Database Foundation

## Current Position

Phase: 1 of 8 (Database Foundation)
Plan: 3 of 3 in current phase (phase complete)
Status: Phase 1 complete — all 3 plans done
Last activity: 2026-05-19 — Completed plan 01-03 (triggers migration + .env.example)

Progress: [█░░░░░░░░░] 12%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 2 min
- Total execution time: 0.10 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-database-foundation | 3 | 6 min | 2 min |

**Recent Trend:**
- Last 5 plans: 01-01 (2 min), 01-02 (2 min), 01-03 (2 min)
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Phase 2 pre-requisite: MSG91 DLT template registration takes 3–14 days — must be started before Phase 2 coding begins
- Phase 3/4 parallel: Flutter Auth Shell (Phase 4) can be built in parallel with Go CRUD API (Phase 3) — Flutter uses stub data
- Phase 6: 1-day spike on `flutter_card_swiper v7` before committing to custom swipe widget
- Phase 7: Prototype PDF 31-column A4 landscape layout before full implementation; validate format with a real school admin
- 01-01: UNIQUE INDEX (not plain index) on refresh_tokens(token_hash) to prevent token hash collisions at DB level
- 01-01: attendance_sessions.class_id has no ON DELETE CASCADE — orphan sessions intentionally preserved as audit trail
- 01-01: attendance_records.student_id has no ON DELETE CASCADE — deleted students remain in historical attendance records
- 01-02: (select auth.uid()) wrapper required on ALL RLS policy USING/WITH CHECK clauses — initPlan optimization; NEVER use bare auth.uid()
- 01-02: FOR ALL policies (not per-operation) — single policy per table, Go backend bypasses RLS via service role key
- 01-02: Subquery pattern (not JOIN) for two-level chains — students via classes, attendance_records via attendance_sessions
- 01-03: Triggers check is_locked BOOLEAN only — IST midnight timezone math lives in Go (time.LoadLocation), not SQL triggers
- 01-03: BEFORE UPDATE (not AFTER) triggers — reject write before storage, not write-then-rollback
- 01-03: SUPABASE_DB_URL uses port 5432 direct connection for pgxpool — pgxpool manages pooling, PgBouncer (6543) only if free tier limit hit
- 01-03: pgxpool MaxConns=10 to stay within Supabase free tier 60-connection limit

### Pending Todos

None yet.

### Blockers/Concerns

- MSG91 DLT registration must be initiated immediately — it blocks all OTP production testing in Phase 2
- Docker Desktop not installed — required for supabase db reset to run locally; blocks live schema verification and plan 01-02/01-03 live execution

## Session Continuity

Last session: 2026-05-19
Stopped at: Completed 01-03-PLAN.md — triggers migration + .env.example + .gitignore + runbook created; Phase 1 complete (Docker required for live execution)
Resume file: None
