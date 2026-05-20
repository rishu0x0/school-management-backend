# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-19)

**Core value:** A teacher can open the app, swipe through their class in under 2 minutes, and have attendance recorded — with monthly reports generated automatically on the 1st of each month.
**Current focus:** Phase 5 — Flutter Class & Student Management (Phase 4 complete)

## Current Position

Phase: 5 of 8 (Flutter Class & Student Management) — In progress (2026-05-20)
Plan: 2 of 3 in phase 05 (plan 05-02 complete — StudentRepository, StudentsNotifier, StudentListScreen, StudentFormSheet)
Status: Phase 5 plan 2 complete — 1 plan remains (05-03 swipe attendance)
Last activity: 2026-05-20 — Completed plan 05-02 (StudentRepository Dio CRUD, StudentsNotifier family pattern, StudentListScreen Slidable soft-remove, StudentFormSheet, flutter analyze zero errors)

Progress: [██████████] 70%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 2 min
- Total execution time: 0.13 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-database-foundation | 3 | 6 min | 2 min |
| 02-go-auth-api | 4 | 14 min | 3.5 min |
| 03-go-crud-api | 4 | 8 min | 2 min |
| 04-flutter-auth-shell | 2 | 22 min | 11 min |

**Recent Trend:**
- Last 5 plans: 02-01 (3 min), 02-02 (4 min), 02-03 (2 min), 02-04 (5 min), 03-01 (2 min)
- Trend: stable ~2-3 min/plan

*Updated after each plan completion*
| Phase 03-go-crud-api P02 | 2 | 2 tasks | 3 files |
| Phase 03-go-crud-api P03 | 2 | 3 tasks | 4 files |
| Phase 05-flutter-class-student-management P01 | 525199 | 4 tasks | 12 files |

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
- 02-03: Two-step Refresh query (UPDATE then SELECT) chosen over subquery RETURNING — more portable and readable
- 02-03: Login validates mobile format before DB query — avoids unnecessary query on obviously invalid input
- 02-03: JWTMiddleware returns 401 (not 403) for all token failures — prevents route existence leakage
- 02-03: contextKey typed string (not plain string) — compile-time safety for context key lookups
- 02-04: ErrRetryTooSoon checks last_retry_at only (not created_at) — initial send never sets last_retry_at so first retry is always allowed
- 02-04: .env.example uses DATABASE_URL (not SUPABASE_DB_URL) — aligned with config.go requireEnv("DATABASE_URL")
- 02-04: Logging audit: all existing log statements are safe (config/startup/db-connect) — no mobile data reaches log calls (INFRA-02 compliant)
- [Phase 03-go-crud-api]: Duplicate name detection via Postgres error string matching — avoids TOCTOU race from separate existence check
- [Phase 03-go-crud-api]: DELETE without confirm=true returns HTTP 200 with warning body (student count) — Flutter client shows dialog before retrying
- [Phase 03-go-crud-api]: Classes CRUD in separate r.Group (not nested in /auth) — allows subsequent plans to append routes to same JWT-protected group
- [Phase 03-go-crud-api]: students table has no updated_at column — Update builds empty setClauses and only appends caller-provided fields
- [Phase 03-go-crud-api]: SoftRemove sets is_active=false (not DELETE) — attendance_records.student_id has no CASCADE; deleting rows would orphan history
- [Phase 03-go-crud-api]: Seed uses ON CONFLICT (class_id, roll_number) DO NOTHING — idempotent; RowsAffected() counts actual inserts
- [Phase 03-go-crud-api]: IST lock enforced in Go (timezone.IsLocked) before any DB write — triggers also lock at DB level but Go check is the primary API enforcement
- [Phase 03-go-crud-api]: Postgres DATE column scanned as time.Time (pgx behavior) — formatted as YYYY-MM-DD string for JSON response
- [Phase 03-go-crud-api]: GetByDate returns HTTP 200 with null session for empty days — Flutter swipe UI handles no-attendance state gracefully without 404 error handling
- [Phase 03-go-crud-api 03-04]: Monthly IN subquery (not LEFT JOIN on sessions) — avoids date filter being ineffective in LEFT JOIN ON condition; IN subquery correctly scopes present_days to the requested month
- [Phase 03-go-crud-api 03-04]: attendance_percentage denominator is days_recorded (session days for month) not student-observed days — consistent cross-student comparison, avoids divide-by-zero
- [Phase 03-go-crud-api 03-04]: TodaySummary returns 200 + zeros (not 404) when no session exists — Flutter Statistics screen uses submitted:false flag to show "No attendance recorded" state
- [Phase 04-flutter-auth-shell 04-01]: sendotp_flutter_sdk ^1.0.4 not on pub.dev; resolved to 0.0.2 (latest available); OTPWidget.initializeWidget confirmed present in 0.0.2 source — import kept in main.dart unchanged
- [Phase 04-flutter-auth-shell 04-01]: analysis_options.yaml enables custom_lint plugin and suppresses invalid_annotation_target (required for riverpod_annotation codegen)
- [Phase 04-flutter-auth-shell 04-02]: Use bare Ref (not deprecated RouterRef/SecureStorageRef) in @riverpod provider functions — riverpod_generator 2.x emits deprecated typedefs; using Ref directly eliminates warnings
- [Phase 04-flutter-auth-shell 04-02]: silentRefresh distinguishes SocketException/DioExceptionType.connectionError from HTTP 401 — network error → AuthNetworkError, 401 → AuthUnauthenticated (teachers never logged out by network glitch)
- [Phase 04-flutter-auth-shell 04-02]: RouterNotifier (ChangeNotifier) bridges Riverpod authNotifierProvider to GoRouter refresh cycle via ref.listen → notifyListeners()
- [Phase 04-flutter-auth-shell 04-04]: QueuedInterceptorsWrapper chosen over plain Interceptor — queues parallel 401 requests so only one /auth/refresh fires; others retry after refresh completes
- [Phase 04-flutter-auth-shell 04-04]: Fresh Dio used for /auth/refresh POST and for retry — avoids re-entering _JwtInterceptor chain, prevents infinite refresh loops
- [Phase 04-flutter-auth-shell 04-04]: NetworkNotifier initialises to true (assume connected); connectivity_plus stream corrects state; offline banner is a Stack overlay not a route redirect
- [Phase 04-flutter-auth-shell 04-04]: connectivity_plus v6+ emits List<ConnectivityResult> — listener uses .any((r) => r != ConnectivityResult.none) to derive bool
- [Phase 05-flutter-class-student-management]: Renamed ClassesNotifier.update to updateClass to avoid AsyncNotifierBase.update collision
- [Phase 05-flutter-class-student-management]: showDeleteClassFlow as top-level function (not widget class) for clean delete-warning two-step flow
- [Phase 05-flutter-class-student-management 05-02]: Renamed StudentsNotifier.update to updateStudent — same AsyncNotifierBase.update collision pattern
- [Phase 05-flutter-class-student-management 05-02]: Undo SnackBar dismisses only — soft-remove is server-side committed; true undo requires re-activate endpoint (out of scope)

### Pending Todos

None yet.

### Blockers/Concerns

- MSG91 DLT registration must be initiated immediately — it blocks all OTP production testing in Phase 2
- Docker Desktop not installed — required for supabase db reset to run locally; blocks live schema verification and plan 01-02/01-03 live execution

## Session Continuity

Last session: 2026-05-20
Stopped at: Completed 05-02-PLAN.md — StudentRepository (list/create/update/softRemove via Dio), StudentsNotifier (family pattern with classID, updateStudent to avoid collision), StudentListScreen (Slidable edit+remove, grey-italic removed entries, empty state, pull-to-refresh, undo SnackBar), StudentFormSheet (name required, roll optional), flutter analyze zero errors.
Resume file: None
