---
phase: 03-go-crud-api
plan: "02"
subsystem: api
tags: [go, chi, pgx, students, crud, soft-delete, seed, ownership-enforcement]

# Dependency graph
requires:
  - phase: 03-go-crud-api
    plan: "01"
    provides: JWT-protected r.Group in main.go; classes table with teacher_id FK; JWTMiddleware and TeacherIDFromContext
provides:
  - Students CRUD endpoints (GET/POST/PUT/DELETE /classes/{classID}/students)
  - Seed endpoint (POST /classes/{classID}/students/seed)
  - Soft-remove pattern (is_active=false) for attendance history preservation
affects: [03-03-attendance, 03-04-stats, flutter-crud-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Two-layer ownership safety — verifyClassOwnership + WHERE class_id=$N in every student query
    - Soft-remove (is_active=false) instead of DELETE — attendance_records.student_id has no CASCADE
    - Dynamic SET clause with argIdx counter — no fixed schema columns like updated_at assumed
    - ON CONFLICT (class_id, roll_number) DO NOTHING — idempotent seed; safe to call multiple times
    - Auto roll_number via COALESCE(MAX(roll_number), 0) + 1 — no gaps, no client burden

key-files:
  created:
    - backend/internal/students/service.go
    - backend/internal/students/handler.go
  modified:
    - backend/cmd/server/main.go

key-decisions:
  - "students table has NO updated_at column — Update builds SET clause from scratch with no assumed columns; only caller-provided fields are patched"
  - "SoftRemove sets is_active=false (not DELETE) — attendance_records.student_id has no ON DELETE CASCADE; deleting rows would orphan historical attendance"
  - "Seed uses ON CONFLICT DO NOTHING — idempotent; calling seed twice on same class doesn't error or duplicate; RowsAffected() used to count actual inserts"
  - "writeJSON/writeError helpers defined in handler.go (students package scope) — consistent with classes pattern; no shared utility package"

requirements-completed: [STU-01, STU-02, STU-03, STU-04, STU-05, STU-06]

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 3 Plan 02: Students CRUD Summary

**Students CRUD with two-layer ownership (verifyClassOwnership + WHERE class_id filter), soft-delete preserving attendance history, auto roll_number, and idempotent seed endpoint**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T16:29:50Z
- **Completed:** 2026-05-19T16:31:37Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Students service: List (ORDER BY roll_number ASC), Create (auto roll_number or explicit), Update (dynamic SET — only patched fields), SoftRemove (is_active=false), Seed (ON CONFLICT DO NOTHING)
- Every operation calls verifyClassOwnership before touching students — SELECT EXISTS from classes WHERE id=$1 AND teacher_id=$2
- handler.go: all 5 handlers with ownership and duplicate-roll error mapping to proper HTTP status codes
- main.go: 5 student routes appended to the existing JWT-protected r.Group; `go build ./...` passes with zero errors

## Task Commits

1. **Task 1: Write students service** — `5d62100` (feat)
2. **Task 2: Write students handler and wire routes** — `bd95f02` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `backend/internal/students/service.go` — List/Create/Update/SoftRemove/Seed; verifyClassOwnership on every method; no updated_at in UPDATE; ON CONFLICT DO NOTHING for Seed
- `backend/internal/students/handler.go` — HTTP handlers; reads teacherID from auth.TeacherIDFromContext; writeJSON/writeError scoped to package
- `backend/cmd/server/main.go` — Added studentSvc/studentHandler; 5 /classes/{classID}/students routes appended inside existing r.Group

## Decisions Made

- **No updated_at in students table:** The students schema (20260519000001_create_schema.sql) has columns id, class_id, roll_number, full_name, photo_url, is_active, created_at — no updated_at. The Update method's dynamic SET clause starts empty and only adds caller-provided fields, so no non-existent column is ever referenced.
- **Soft-remove (is_active=false):** The attendance_records.student_id FK has no ON DELETE CASCADE (intentional — decision from 01-01). A hard delete would leave orphaned attendance rows. SoftRemove sets is_active=false; the row persists so historical attendance keeps its student reference.
- **Auto roll_number:** COALESCE(MAX(roll_number), 0) + 1 assigns the next sequential roll in the class. No gap logic — teacher can explicitly pass roll_number to override.
- **Seed idempotency:** ON CONFLICT (class_id, roll_number) DO NOTHING makes the endpoint safe to call multiple times. RowsAffected() > 0 determines the actual insert count returned to the caller.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed `updated_at = NOW()` from Update setClauses initialization**

- **Found during:** Task 1 (pre-write schema review)
- **Issue:** Plan template included `setClauses := []string{"updated_at = NOW()"}` but the students table has no updated_at column — this would cause a runtime Postgres error on every UPDATE call
- **Fix:** Initialized setClauses as an empty slice `[]string{}`; added guard to return error if no fields are provided (prevents empty SET clause)
- **Files modified:** backend/internal/students/service.go
- **Commit:** 5d62100

## Issues Encountered

None beyond the updated_at deviation (auto-fixed before writing the file).

## User Setup Required

None.

## Next Phase Readiness

- Students are now the primary subjects of attendance — plan 03-03 (attendance) can reference student_id safely
- The soft-remove pattern (is_active=false) is established; 03-03 attendance list queries should filter WHERE is_active = true for the swipe UI
- The JWT-protected r.Group in main.go is ready for /attendance routes

---
*Phase: 03-go-crud-api*
*Completed: 2026-05-19*
