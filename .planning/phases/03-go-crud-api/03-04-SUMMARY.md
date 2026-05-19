---
phase: 03-go-crud-api
plan: "04"
subsystem: api
tags: [go, chi, pgx, stats, analytics, ist-timezone, attendance-percentage, removed-students]

# Dependency graph
requires:
  - phase: 03-go-crud-api
    plan: "03"
    provides: JWT-protected r.Group; attendance_sessions + attendance_records populated; timezone.TodayIST(); TeacherIDFromContext
  - phase: 01-database-foundation
    plan: "01"
    provides: students.is_active column; attendance_sessions.date (DATE); attendance_records.status enum
provides:
  - Stats today endpoint (GET /classes/{classID}/stats/today) — present/absent/leave/total counts for today IST
  - Stats monthly endpoint (GET /classes/{classID}/stats/monthly?month=YYYY-MM) — days recorded, average %, below-75% student list
  - (Removed) display for inactive students in stats responses
affects: [04-flutter-auth-shell, 06-flutter-swipe-ui, 07-report-generation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Stats today uses timezone.TodayIST().Format("2006-01-02") for IST date — consistent with attendance IST pattern
    - Monthly LEFT JOIN via IN subquery on attendance_sessions — students with zero records get 0/days_recorded = 0%
    - CASE WHEN is_active THEN full_name ELSE '(Removed)' END — preserves historical records while masking PII for removed students
    - attendance_percentage = present_days / days_recorded * 100 (not present/student_total_days) — normalized to session days

key-files:
  created:
    - backend/internal/stats/service.go
    - backend/internal/stats/handler.go
  modified:
    - backend/cmd/server/main.go

key-decisions:
  - "Monthly query uses IN subquery (not LEFT JOIN on sessions) to avoid Cartesian product from joining attendance_records + attendance_sessions across month range"
  - "attendance_percentage denominator is days_recorded (total session days), not per-student observed days — ensures consistent cross-student comparison"
  - "TodaySummary returns zeros + submitted=false (not 404) when no session exists — consistent with GetByDate null-session pattern from plan 03-03"
  - "verifyClassOwnership shared helper in stats service — same pattern as classes/students/attendance services; teacher_id check in every service"

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 3 Plan 04: Stats Endpoints Summary

**Stats today (present/absent/leave counts for IST today) and monthly analytics (days recorded, average %, below-75% student list with (Removed) display for inactive students)**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T16:39:43Z
- **Completed:** 2026-05-19T16:41:29Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `backend/internal/stats/service.go`: TodaySummary (checks today IST via timezone.TodayIST(), queries attendance_records grouped by status), MonthlySummary (counts distinct session days, LEFT JOIN via IN subquery for per-student present_days, CASE WHEN is_active for (Removed) display, 75% threshold filter)
- `backend/internal/stats/handler.go`: Today handler (GET /classes/{classID}/stats/today, 404 on class not found, 500 on internal error), Monthly handler (GET /classes/{classID}/stats/monthly?month=YYYY-MM, 400 on missing/invalid month, 404 on class not found)
- `backend/cmd/server/main.go`: stats service/handler wired; 2 routes appended inside JWT-protected r.Group — Phase 3 Go CRUD API complete

## Task Commits

1. **Task 1: Write stats service** — `8303416` (feat)
2. **Task 2: Write stats handler, wire routes, final build verification** — `000d37e` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `backend/internal/stats/service.go` — verifyClassOwnership (teacher_id check); TodaySummary (timezone.TodayIST(), session lookup, status GROUP BY count); MonthlySummary (month parse → date range, COUNT(DISTINCT date), LEFT JOIN IN subquery, CASE WHEN display_name, 75% threshold)
- `backend/internal/stats/handler.go` — Today handler and Monthly handler; writeJSON/writeError scoped to stats package; auth.TeacherIDFromContext for JWT extraction; chi.URLParam for classID
- `backend/cmd/server/main.go` — Added stats import; statsSvc/statsHandler initialization; GET /classes/{classID}/stats/today and GET /classes/{classID}/stats/monthly routes in JWT-protected group

## Routes Registered (Complete Phase 3 List)

| Method | Path | Handler | Plan |
|--------|------|---------|------|
| GET | /classes | classHandler.List | 03-01 |
| POST | /classes | classHandler.Create | 03-01 |
| PUT | /classes/{classID} | classHandler.Update | 03-01 |
| DELETE | /classes/{classID} | classHandler.Delete | 03-01 |
| GET | /classes/{classID}/students | studentHandler.List | 03-02 |
| POST | /classes/{classID}/students | studentHandler.Create | 03-02 |
| PUT | /classes/{classID}/students/{studentID} | studentHandler.Update | 03-02 |
| DELETE | /classes/{classID}/students/{studentID} | studentHandler.SoftRemove | 03-02 |
| POST | /classes/{classID}/students/seed | studentHandler.Seed | 03-02 |
| GET | /classes/{classID}/attendance | attendanceHandler.GetByDate | 03-03 |
| POST | /classes/{classID}/attendance | attendanceHandler.SubmitBatch | 03-03 |
| PUT | /classes/{classID}/attendance/{sessionID} | attendanceHandler.EditRecords | 03-03 |
| GET | /classes/{classID}/stats/today | statsHandler.Today | 03-04 |
| GET | /classes/{classID}/stats/monthly | statsHandler.Monthly | 03-04 |

## Monthly Stats Query Approach

1. **Days recorded:** `COUNT(DISTINCT date) FROM attendance_sessions WHERE class_id = $1 AND date >= $2 AND date < $3`
2. **Per-student present days:** LEFT JOIN `attendance_records` where `session_id IN (SELECT id FROM attendance_sessions WHERE class_id... AND date range)` — ensures students with zero records still appear with 0 present_days
3. **Attendance percentage:** `present_days / days_recorded * 100` — denominator is session days (not student-observed days) for consistent cross-student comparison
4. **Below threshold:** `st.AttendancePercent < 75.0` filter applied in Go after scanning

## (Removed) Display Approach

SQL CASE expression in the SELECT:
```sql
CASE WHEN st.is_active THEN st.full_name ELSE '(Removed)' END AS display_name
```
- Active students: their full_name returned normally
- Removed students (is_active=false): literal string `(Removed)` returned in the full_name JSON field
- Attendance records for removed students are preserved — their historical session records still count toward class averages
- GROUP BY includes both `st.full_name` and `st.is_active` to avoid aggregation errors

## Final Build/Vet Results

```
go build ./...  → BUILD_OK (zero errors)
go vet ./...    → VET_OK (zero errors)
```

### Security Grep Confirmations

1. `grep -rn "Asia/Kolkata" pkg/timezone/` → `timezone.go:13: IST, err = time.LoadLocation("Asia/Kolkata")`
2. `grep -rn "teacher_id" internal/*/service.go` → teacher_id present in classes, students, attendance, and stats service files
3. `grep -rn "Removed" internal/stats/service.go` → Line 153: `CASE WHEN st.is_active THEN st.full_name ELSE '(Removed)' END`
4. `grep -rn "BeginTx\|\.Begin(" internal/attendance/service.go` → `attendance/service.go:82: tx, err := s.db.Begin(ctx)`

## Decisions Made

- **Monthly IN subquery (not LEFT JOIN on sessions table):** The original plan showed a LEFT JOIN from students to attendance_records to attendance_sessions. Using an IN subquery instead avoids a potential Cartesian product when joining two range-filtered tables and is semantically clearer — the subquery filters sessions once, then attendance_records JOIN is straightforward.
- **Percentage denominator is days_recorded:** Using `present_days / days_recorded` (not `present_days / student_total_observed_days`) ensures all students are compared on the same scale. A student who was absent for all sessions gets 0% — not a divide-by-zero from their observed days being 0.
- **TodaySummary returns 200 + zeros (not 404):** Consistent with GetByDate null-session pattern from plan 03-03. Flutter Statistics screen doesn't need to handle 404 — it sees `submitted: false` and shows "No attendance recorded today."

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Monthly query rewritten from LEFT JOIN chain to IN subquery**

- **Found during:** Task 1 (pre-write analysis)
- **Issue:** The plan's example query used `LEFT JOIN attendance_sessions s ON ar.session_id = s.id AND s.class_id = $1 AND s.date >= $2 AND s.date < $3` — this JOIN condition applies filters only to matched rows but the LEFT JOIN still returns all attendance_records rows regardless of date range, making the date filter ineffective for counting present_days within the month
- **Fix:** Rewrote as `LEFT JOIN attendance_records ar ON ar.student_id = st.id AND ar.session_id IN (SELECT id FROM attendance_sessions WHERE class_id = $1 AND date >= $2 AND date < $3)` — the IN subquery correctly scopes which session records are considered before the join
- **Files modified:** backend/internal/stats/service.go
- **Impact:** Correct monthly scoping — present_days reflects only the requested month's sessions

---

**Total deviations:** 1 auto-fixed (Rule 1 — LEFT JOIN date filter logic bug)
**Impact on plan:** Necessary correctness fix. The plan's original JOIN pattern would have silently returned incorrect attendance percentages by including records outside the requested month.

## Issues Encountered

None beyond the monthly query deviation (auto-fixed before writing).

## User Setup Required

None — stats endpoints are read-only; no migrations or external services required.

## Phase 3 Complete

All 4 plans of Phase 3 (Go CRUD API) are complete:
- 03-01: Classes CRUD (4 routes)
- 03-02: Students CRUD + seed (5 routes)
- 03-03: Attendance batch submit + IST lock (3 routes) + pkg/timezone
- 03-04: Stats today + monthly (2 routes)

**Total Phase 3 routes:** 14 JWT-protected routes + /health + 5 auth routes = 20 routes total

---
*Phase: 03-go-crud-api*
*Completed: 2026-05-19*
