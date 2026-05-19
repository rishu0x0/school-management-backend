# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-19)

**Core value:** A teacher can open the app, swipe through their class in under 2 minutes, and have attendance recorded — with monthly reports generated automatically on the 1st of each month.
**Current focus:** Phase 2 — Go Auth API

## Current Position

Phase: 2 of 8 (Go Auth API)
Plan: 2 of 4 in current phase (plan 02-02 complete)
Status: Phase 2 in progress — plans 02-01 and 02-02 done, plans 02-03 and 02-04 remaining
Last activity: 2026-05-19 — Completed plan 02-02 (MSG91 OTP client, JWT service, registration endpoints, auth routes wired)

Progress: [███░░░░░░░] 22%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 2 min
- Total execution time: 0.13 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-database-foundation | 3 | 6 min | 2 min |
| 02-go-auth-api | 2 | 7 min | 3.5 min |

**Recent Trend:**
- Last 5 plans: 01-01 (2 min), 01-02 (2 min), 01-03 (2 min), 02-01 (3 min), 02-02 (4 min)
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
- 02-01: tools.go with //go:build tools retains golang-jwt/jwt/v5 and golang.org/x/crypto in go.mod before any source file imports them — go mod tidy prunes unused deps
- 02-01: otp_sessions has no FK to teachers table — teacher row does not exist yet during registration flow
- 02-01: req_id UNIQUE INDEX on otp_sessions — prevents duplicate MSG91 reqId inserts and allows fast verifyOTP lookup
- 02-01: requireEnv() fatals at startup — server must not silently run with missing credentials
- 02-02: Country code (91) prepended in service layer, not handler — keeps HTTP API mobile-format-agnostic (10 digits)
- 02-02: OTP attempt lockout checked before calling MSG91 VerifyOTP — avoids unnecessary external API calls on locked sessions
- 02-02: JWTMiddleware stub in middleware.go allows /auth/logout route to compile; full enforcement in 02-03
- 02-02: Refresh token stored as SHA-256 hash only — raw token returned to client once, never persisted

### Pending Todos

None yet.

### Blockers/Concerns

- MSG91 DLT registration must be initiated immediately — it blocks all OTP production testing in Phase 2
- Docker Desktop not installed — required for supabase db reset to run locally; blocks live schema verification and plan 01-02/01-03 live execution

## Session Continuity

Last session: 2026-05-19
Stopped at: Completed 02-02-PLAN.md — MSG91 OTP client, JWT service, registration flow endpoints, auth routes wired in main.go; Phase 2 plan 2 of 4 complete
Resume file: None
