---
phase: 03-go-crud-api
plan: "03"
subsystem: api
tags: [go, chi, pgx, attendance, transaction, ist-timezone, midnight-lock, batch-submit]

# Dependency graph
requires:
  - phase: 03-go-crud-api
    plan: "02"
    provides: JWT-protected r.Group in main.go; students table with student_id FK; TeacherIDFromContext
  - phase: 01-database-foundation
    plan: "01"
    provides: attendance_sessions + attendance_records schema; updated_at on attendance_records; UNIQUE(class_id, date) constraint
provides:
  - IST timezone package (pkg/timezone) with time.LoadLocation("Asia/Kolkata") and IsLocked()
  - Attendance batch submit endpoint (POST /classes/{classID}/attendance) — single pgx transaction
  - Attendance fetch endpoint (GET /classes/{classID}/attendance?date=YYYY-MM-DD)
  - Attendance edit endpoint (PUT /classes/{classID}/attendance/{sessionID}) — IST midnight lock
affects: [03-04-stats, 04-flutter-auth-shell, 06-flutter-swipe-ui, 07-report-generation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - IST midnight lock in Go (not SQL) — time.LoadLocation("Asia/Kolkata") in pkg/timezone.IsLocked()
    - Single pgx transaction for batch saves — db.Begin / defer tx.Rollback / tx.Commit
    - Postgres DATE column scanned as time.Time then formatted as YYYY-MM-DD string for JSON
    - Graceful null session response — GetByDate returns ErrSessionNotFound; handler returns {session: null, records: []} with 200
    - Duplicate detection via Postgres unique constraint error string matching ("unique"/"duplicate")

key-files:
  created:
    - backend/pkg/timezone/timezone.go
    - backend/internal/attendance/service.go
    - backend/internal/attendance/handler.go
  modified:
    - backend/cmd/server/main.go

key-decisions:
  - "IST lock enforced in Go (timezone.IsLocked) before any DB write — triggers also lock at DB level but Go check is the primary API enforcement"
  - "Postgres DATE column scanned as time.Time (pgx behavior) — formatted as YYYY-MM-DD string for JSON, not stored as string in struct"
  - "GetByDate returns ErrSessionNotFound (nil session) — handler returns HTTP 200 with {session: null} so Flutter swipe UI doesn't need to handle 404 on empty day"
  - "attendance_records.updated_at used in UPDATE SET clause — confirmed in schema; attendance_sessions has no updated_at"
  - "SubmitBatch returns full session via GetByDate after commit — single source of truth for response shape"

patterns-established:
  - "pkg/timezone pattern: shared timezone utilities live in pkg/ (not internal/) — reusable across future packages (stats, reports)"
  - "IST lock: timezone.IsLocked(sessionDate, time.Now()) called before any DB mutation — pattern for any future time-gated business rule"
  - "Batch transaction pattern: Begin / defer Rollback / loop Exec / Commit — atomic all-or-nothing for multi-row writes"

requirements-completed: [ATT-01, SUB-05, SUB-06, SUB-07, SUB-08]

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 3 Plan 03: Attendance CRUD Summary

**Attendance batch submit (single pgx transaction), IST midnight lock via time.LoadLocation("Asia/Kolkata"), and graceful null-session response for empty days**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T16:33:58Z
- **Completed:** 2026-05-19T16:35:58Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- pkg/timezone/timezone.go: IST loaded with time.LoadLocation, IsLocked() checks midnight boundary, NowIST/TodayIST helpers
- attendance/service.go: SubmitBatch (single transaction — Begin/defer Rollback/loop INSERT/Commit), GetByDate (returns ErrSessionNotFound for empty days), EditRecords (IST lock check before any DB write)
- attendance/handler.go: GetByDate returns HTTP 200 + {session: null} when no session exists, SubmitBatch returns 409 on duplicate, EditRecords returns 403 "attendance_locked" when past midnight IST
- main.go: 3 attendance routes wired in JWT-protected r.Group; `go build ./...` passes with zero errors

## Task Commits

1. **Task 1: Write IST timezone package** — `51c3720` (feat)
2. **Task 2: Write attendance service** — `2488999` (feat)
3. **Task 3: Write attendance handler and wire routes** — `fa8d668` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `backend/pkg/timezone/timezone.go` — IST via time.LoadLocation("Asia/Kolkata"); IsLocked() midnight boundary check; NowIST() and TodayIST() helpers
- `backend/internal/attendance/service.go` — SubmitBatch single-transaction batch save; GetByDate with graceful ErrSessionNotFound; EditRecords with IST lock enforcement; Postgres DATE column handled as time.Time
- `backend/internal/attendance/handler.go` — HTTP handlers; GetByDate returns 200+null for missing sessions; SubmitBatch returns 409 for duplicates; EditRecords returns 403 for locked sessions; writeJSON/writeError scoped to package
- `backend/cmd/server/main.go` — Added attendanceSvc/attendanceHandler; 3 /classes/{classID}/attendance routes appended inside existing JWT-protected r.Group

## Decisions Made

- **IST lock in Go, not SQL:** The DB trigger (01-03) also locks at the DB level, but the Go check via timezone.IsLocked() is the primary API enforcement. This gives a clean 403 error code ("attendance_locked") before any DB round trip.
- **Postgres DATE as time.Time:** pgx scans DATE columns as time.Time, not string. The service scans into a `time.Time` temp variable and formats it as "2006-01-02" for the JSON response. This avoids runtime scan errors.
- **Null session on empty day:** GetByDate returns ErrSessionNotFound when no attendance exists for a date. The handler maps this to HTTP 200 + `{session: null, records: []}` — Flutter swipe UI doesn't need to handle 404 as an error state; it just shows "no attendance recorded" UI.
- **attendance_records.updated_at confirmed:** Schema review (20260519000001_create_schema.sql line 99) confirmed updated_at exists on attendance_records — used in UPDATE SET clause. attendance_sessions has no updated_at — not referenced.
- **SubmitBatch returns full session:** After committing the transaction, SubmitBatch calls GetByDate to build the response. Single source of truth for the response shape; avoids duplicating scan logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Postgres DATE column scanned as time.Time, not string**

- **Found during:** Task 2 (writing service.go, pre-write schema review)
- **Issue:** The plan's service template used `&session.Date` where `Session.Date` is `string`. pgx returns DATE columns as `time.Time`, not `string` — scanning directly into string would panic at runtime.
- **Fix:** Introduced a `var sessionDate time.Time` temp variable in both GetByDate and EditRecords. After scanning, formatted as `sessionDate.Format("2006-01-02")` for the JSON string field. Similarly `marked_at` TIMESTAMPTZ scanned as `time.Time` and formatted as RFC3339.
- **Files modified:** backend/internal/attendance/service.go
- **Verification:** go build ./internal/attendance/... passes; no scan type mismatch
- **Committed in:** 2488999 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — type mismatch bug)
**Impact on plan:** Necessary correctness fix — the plan template assumed string scan behavior but pgx always returns DATE as time.Time. No scope creep.

## Issues Encountered

None beyond the DATE scan type deviation (auto-fixed before writing).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Attendance endpoints are fully operational; plan 03-04 (stats/analytics) can query attendance_records and attendance_sessions
- The IST lock pattern (timezone.IsLocked) is established in pkg/timezone — stats queries referencing dates should use the same package
- The JWT-protected r.Group in main.go is ready for /classes/{classID}/stats routes

---
*Phase: 03-go-crud-api*
*Completed: 2026-05-19*
