---
phase: 03-go-crud-api
plan: "01"
subsystem: api
tags: [go, chi, pgx, classes, crud, ownership-enforcement]

# Dependency graph
requires:
  - phase: 02-go-auth-api
    provides: JWTMiddleware and TeacherIDFromContext for ownership enforcement on every request
provides:
  - Classes CRUD endpoints (GET/POST/PUT/DELETE /classes) with teacher ownership enforcement
  - Delete-with-confirmation pattern reusable for students and sessions in subsequent plans
affects: [03-02-students, 03-03-attendance, 03-04-stats, flutter-crud-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - App-layer ownership filter (teacher_id = $N on every query) — service role key bypasses Supabase RLS so Go must enforce at query time
    - Nullable optional fields via nullableString helper returning interface{} nil for empty strings
    - Confirm-gate delete pattern — returns student count warning at HTTP 200; actual delete only when confirm=true query param present

key-files:
  created:
    - backend/internal/classes/service.go
    - backend/internal/classes/handler.go
  modified:
    - backend/cmd/server/main.go

key-decisions:
  - "Duplicate name detection via Postgres error string matching ('unique'/'duplicate') — no separate SELECT before INSERT, avoids TOCTOU race"
  - "Delete without confirm=true returns HTTP 200 with warning body (not 4xx) — caller can inspect student_count and decide"
  - "New r.Group block in main.go (separate from /auth) holds all CRUD routes protected by JWTMiddleware — allows future plans to append routes to same group"
  - "writeError/writeJSON helpers defined in handler.go (not a shared pkg) — scoped to classes package, each domain package will define its own helpers"

patterns-established:
  - "Ownership filter: every service method receives teacherID and appends WHERE teacher_id = $N — mandatory for service-role-key backends"
  - "Confirm-gate delete: service returns (*DeleteWarning, ErrConfirmRequired) tuple; handler maps to 200+warning; actual delete only on confirm=true"
  - "Context extraction: auth.TeacherIDFromContext(r.Context()) called at top of every handler before any business logic"

requirements-completed: [CLS-01, CLS-02, CLS-03, CLS-04, CLS-05]

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 3 Plan 01: Classes CRUD Summary

**Go classes CRUD with app-layer teacher ownership (teacher_id filter on every query) and a confirm-gate delete that returns student count before cascade**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-19T16:26:10Z
- **Completed:** 2026-05-19T16:27:34Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Classes service with List, Create, Update, Delete — all queries filter by teacher_id (critical: service role key bypasses Supabase RLS)
- DELETE endpoint returns a warning with student count when confirm=true is absent; actual cascade delete only on explicit confirmation
- main.go wired with a new JWT-protected r.Group registering GET/POST/PUT/DELETE /classes; go build ./... passes with zero errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Write classes service** - `1091387` (feat)
2. **Task 2: Write classes handler and wire routes** - `8cd478c` (feat)

**Plan metadata:** _(this commit)_ (docs: complete plan)

## Files Created/Modified

- `backend/internal/classes/service.go` — Classes CRUD business logic; List/Create/Update/Delete all enforce teacher ownership via WHERE teacher_id = $N
- `backend/internal/classes/handler.go` — HTTP handlers; reads teacherID from auth.TeacherIDFromContext on every request; writeJSON/writeError helpers
- `backend/cmd/server/main.go` — Added classSvc/classHandler setup; new r.Group with JWTMiddleware protecting /classes routes

## Decisions Made

- Duplicate name detection reads the Postgres error string for "unique"/"duplicate" — avoids a separate existence check and the TOCTOU race that comes with it.
- DELETE without confirm=true returns HTTP 200 with a `{"confirm_required": true, "warning": {...}}` body rather than a 4xx, so the Flutter client can display the student count in a confirmation dialog before retrying.
- A separate r.Group block (not nested inside /auth) holds all CRUD routes — this keeps the auth routing clean and lets plans 03-02 through 03-04 append their routes to the same protected group.
- writeJSON/writeError helpers live in handler.go inside the classes package rather than a shared utility package — each domain keeps its own helpers, avoids premature abstraction.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Classes CRUD is the root of the data hierarchy; students (03-02) and attendance (03-03) can now reference class_id.
- The confirm-gate delete pattern is established and should be replicated for student deletion in 03-02.
- The JWT-protected r.Group in main.go is ready to accept /students and /attendance routes without modification.

---
*Phase: 03-go-crud-api*
*Completed: 2026-05-19*
