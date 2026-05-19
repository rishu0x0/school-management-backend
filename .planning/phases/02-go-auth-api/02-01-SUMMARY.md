---
phase: 02-go-auth-api
plan: "01"
subsystem: infra
tags: [go, chi, pgx, jwt, bcrypt, godotenv, supabase, otp]

# Dependency graph
requires:
  - phase: 01-database-foundation
    provides: Supabase schema with all tables, RLS policies, and migrations

provides:
  - Go module school-management/backend with Chi router, pgx pool, env config, and /health endpoint
  - backend/cmd/server/main.go: runnable HTTP server with graceful shutdown
  - backend/internal/config/config.go: type-safe env var loading for all required vars
  - backend/internal/db/db.go: pgxpool with MaxConns=10 and connection Ping verification
  - backend/Makefile: run/build/test/lint/tidy targets
  - supabase/migrations/20260519000004_otp_sessions.sql: OTP session storage table for Plan 02-02
  - tools.go: //go:build tools stub retaining jwt+crypto in go.mod before business-logic usage

affects: [02-02, 02-03, 02-04, 03-01, 03-02, 03-03, 03-04]

# Tech tracking
tech-stack:
  added:
    - github.com/go-chi/chi/v5 v5.2.5 (HTTP router)
    - github.com/jackc/pgx/v5 v5.9.2 (PostgreSQL driver with pgxpool)
    - github.com/golang-jwt/jwt/v5 v5.3.1 (JWT signing/verification — used in 02-03)
    - golang.org/x/crypto v0.51.0 (bcrypt — used in 02-02/02-04)
    - github.com/joho/godotenv v1.5.1 (loads .env file on startup)
  patterns:
    - Module path: school-management/backend (all internal imports use this prefix)
    - pgxpool.NewWithConfig + MaxConns=10 to stay within Supabase free tier 60-connection limit
    - requireEnv() fatals on startup if a required var is missing (fail-fast config)
    - //go:build tools in tools.go to pin future-used deps in go.mod before they appear in source
    - Graceful shutdown via os.Signal channel with 30s timeout context

key-files:
  created:
    - backend/go.mod
    - backend/go.sum
    - backend/tools.go
    - backend/cmd/server/main.go
    - backend/internal/config/config.go
    - backend/internal/db/db.go
    - backend/Makefile
    - supabase/migrations/20260519000004_otp_sessions.sql
  modified: []

key-decisions:
  - "tools.go with //go:build tools retains golang-jwt/jwt/v5 and golang.org/x/crypto in go.mod before any source file imports them — go mod tidy would otherwise prune them"
  - "pgxpool MaxConns=10 matches the 01-03 decision; stays within Supabase free tier 60-connection limit"
  - "otp_sessions has no FK to teachers table — teacher row does not exist yet during registration flow"
  - "req_id UNIQUE INDEX on otp_sessions — prevents duplicate MSG91 reqId inserts and allows fast verifyOTP lookup"
  - "requireEnv() fatals at startup — server must not silently run with missing credentials"

patterns-established:
  - "Chi middleware stack order: RequestID → RealIP → Recoverer → Timeout(30s)"
  - "config.Load() called once in main() and passed down — no global state"
  - "db.NewPool() Pings on startup — connection failures are fatal at boot, not at first request"

requirements-completed: [INFRA-01, INFRA-02]

# Metrics
duration: 3min
completed: 2026-05-19
---

# Phase 2 Plan 01: Go Backend Scaffold Summary

**Chi router + pgx pool Go server scaffold with /health endpoint and otp_sessions migration — foundation for all Phase 2 auth endpoints**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-19T15:36:26Z
- **Completed:** 2026-05-19T15:39:00Z
- **Tasks:** 4
- **Files modified:** 8 created

## Accomplishments

- Go module `school-management/backend` initialized with all 5 required dependencies (chi/v5, pgx/v5, golang-jwt/jwt/v5, golang.org/x/crypto, godotenv)
- Chi HTTP server with /health endpoint, 4 middleware layers, and 30-second graceful shutdown at `cmd/server/main.go`
- Type-safe config loader with fail-fast `requireEnv()` reading DATABASE_URL, JWT_SECRET, JWT_ACCESS_EXPIRY, PORT, MSG91_AUTH_TOKEN, MSG91_WIDGET_ID
- pgxpool with MaxConns=10 and Ping-on-startup for database connection verification
- `otp_sessions` Supabase migration with MSG91 reqId storage, 10-minute expiry, 3-attempt lockout fields, and mobile + unique req_id indexes

## Task Commits

1. **Task 1: Initialize Go module and install dependencies** - `2f491a6` (chore)
2. **Task 2: Write config, db, and main packages** - `6e63eb9` (feat)
3. **Task 3: Write Makefile** - `c645e8d` (chore)
4. **Task 4: Add otp_sessions Supabase migration** - `90e9857` (feat)

**Plan metadata:** (docs commit — created after tasks)

## Files Created/Modified

- `backend/go.mod` — module school-management/backend with all 5 direct dependencies
- `backend/go.sum` — dependency checksums
- `backend/tools.go` — //go:build tools stub pinning jwt+crypto before business-logic imports
- `backend/cmd/server/main.go` — Chi router, middleware stack, /health endpoint, graceful shutdown
- `backend/internal/config/config.go` — Config struct + Load() with requireEnv/getEnv helpers
- `backend/internal/db/db.go` — NewPool() with pgxpool MaxConns=10 and Ping verification
- `backend/Makefile` — run/build/test/lint/tidy targets; `make lint` passes with zero errors
- `supabase/migrations/20260519000004_otp_sessions.sql` — otp_sessions table with all required columns and indexes

## Decisions Made

- `tools.go` with `//go:build tools` retains `golang-jwt/jwt/v5` and `golang.org/x/crypto` in go.mod. Without this, `go mod tidy` prunes them because no current source file imports them — they are needed in Plans 02-02 and 02-03.
- `otp_sessions` has no FK to `teachers` table: during registration the teacher row does not exist yet. The OTP session is validated first, then the teacher row is created.
- `req_id UNIQUE INDEX` on `otp_sessions` allows O(log n) verifyOTP lookup and prevents duplicate MSG91 reqId inserts.
- `requireEnv()` fatals on startup with a clear message — the server must not silently start with missing credentials.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added tools.go to retain future dependencies in go.mod**
- **Found during:** Task 1 (Go module initialization)
- **Issue:** `go mod tidy` pruned `golang-jwt/jwt/v5` and `golang.org/x/crypto` from go.mod because no source files import them yet. The plan's must_haves require all 5 deps present in go.mod.
- **Fix:** Created `backend/tools.go` with `//go:build tools` build tag and blank imports of jwt and bcrypt. This is a standard Go pattern for pinning tool/future dependencies.
- **Files modified:** `backend/tools.go`
- **Verification:** `go mod tidy` no longer prunes the deps; `go.mod` shows all 5 as direct requires.
- **Committed in:** `2f491a6` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug — go mod tidy pruning)
**Impact on plan:** Required for correctness — the plan's must_have truths require all 5 deps in go.mod. No scope creep.

## Issues Encountered

- `go mod tidy` pruned dependencies when no source files existed yet. Resolved by writing source files first (Task 2), then re-running `go get` for all deps, then tidy. The `tools.go` pattern permanently prevents future pruning.

## User Setup Required

None — no external service configuration required for this scaffold plan. The server requires env vars at runtime (DATABASE_URL etc.) but those already exist in `.env` from Phase 1 setup.

## Next Phase Readiness

- Go backend scaffold is ready for Plan 02-02 (registration flow with MSG91 OTP)
- `otp_sessions` migration is ready to be pushed to Supabase alongside the registration flow
- All auth route placeholders (`r.Route("/auth", ...)`) are in place for 02-02 and 02-03 to populate
- `go build ./...` and `go vet ./...` both pass with zero errors — clean compilation baseline

---
*Phase: 02-go-auth-api*
*Completed: 2026-05-19*
