---
phase: 02-go-auth-api
plan: "03"
subsystem: auth
tags: [go, jwt, bcrypt, login, refresh, logout, middleware]

# Dependency graph
requires:
  - phase: 02-go-auth-api
    plan: "02"
    provides: service.go with issueTokens, handler.go stubs, middleware.go stub, pkg/jwt with ParseAccessToken and HashToken

provides:
  - backend/internal/auth/service.go: Login (bcrypt verify), Refresh (hash-based token update), Logout (hash-based delete) — all three methods appended
  - backend/internal/auth/handler.go: Real Login/Refresh/Logout handlers replacing 501 stubs
  - backend/internal/auth/middleware.go: Full JWTMiddleware with Bearer token extraction, ParseAccessToken, context injection; TeacherIDFromContext helper

affects: [02-04, 03-01, 03-02, 03-03, 03-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Generic credential error: all Login failures (wrong mobile, wrong password, unverified) return same ErrInvalidCredentials — handler maps to "Invalid mobile number or password" (AUTH-07)
    - Two-step Refresh: UPDATE refresh_tokens RETURNING teacher_id, then SELECT mobile/school_name FROM teachers — avoids subquery RETURNING complexity
    - Non-rotating refresh tokens: last_used_at updated on Refresh but token hash not changed — client keeps same token indefinitely until Logout
    - Multi-device Logout: DELETE WHERE token_hash = SHA256(incoming) — only current device's row deleted (AUTH-12)
    - contextKey typed string: prevents context key collisions across packages
    - TeacherIDFromContext helper: safe type assertion with zero value on miss — downstream handlers never panic on missing context

key-files:
  created: []
  modified:
    - backend/internal/auth/service.go
    - backend/internal/auth/handler.go
    - backend/internal/auth/middleware.go

key-decisions:
  - "Two-step Refresh query (UPDATE then SELECT) chosen over subquery RETURNING — more portable and readable"
  - "Login validates mobile format before DB query — avoids unnecessary query on obviously invalid input"
  - "JWTMiddleware returns 401 (not 403) for all token failures — prevents route existence leakage"
  - "contextKey typed string (not plain string) — compile-time safety for context key lookups"

# Metrics
duration: 2min
completed: 2026-05-19
---

# Phase 2 Plan 03: Login, Refresh, Logout, and JWT Middleware Summary

**Login/Refresh/Logout service+handler methods with full JWT Bearer middleware — entire auth API operational end-to-end**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-19T15:53:42Z
- **Completed:** 2026-05-19T15:55:24Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Login service method: validates 10-digit mobile, fetches teacher row, checks is_verified, calls bcrypt.CompareHashAndPassword, returns ErrInvalidCredentials for all failure modes without revealing which field failed (AUTH-07)
- Refresh service method: two-step — UPDATE refresh_tokens SET last_used_at=NOW() WHERE token_hash=SHA256(token) RETURNING teacher_id, then SELECT mobile/school_name FROM teachers WHERE id=teacher_id — issues new access token; non-rotating (AUTH-10)
- Logout service method: DELETE FROM refresh_tokens WHERE token_hash=SHA256(token); only affects current device row; empty token is a no-op (AUTH-12)
- Login handler: decodes {mobile, password, device_hint}; maps ErrInvalidCredentials to HTTP 401 with "Invalid mobile number or password" — no field-specific message
- Refresh handler: decodes {refresh_token}; returns {access_token} on success; 401 on any error
- Logout handler: decodes {refresh_token}; returns {success:true} on success
- JWTMiddleware: extracts "Authorization: Bearer <token>", validates with ParseAccessToken, sets teacher_id/mobile/school_name in context via typed contextKey; returns 401 for missing/malformed/expired tokens
- TeacherIDFromContext: safe context value extraction for downstream Phase 3 handlers

## Task Commits

1. **Task 1: Add Login, Refresh, and Logout to auth service** — `c719b89` (feat)
2. **Task 2: Implement Login, Refresh, Logout handlers** — `d644913` (feat)
3. **Task 3: Implement JWT middleware (replace stub from 02-02)** — `ab8e56c` (feat)

## Files Created/Modified

- `backend/internal/auth/service.go` — Login, Refresh, Logout methods appended; existing registration methods untouched
- `backend/internal/auth/handler.go` — loginRequest/refreshRequest/logoutRequest types + real handler implementations replacing 501 stubs
- `backend/internal/auth/middleware.go` — Full JWTMiddleware with Bearer token validation + TeacherIDFromContext helper; replaced 02-02 pass-through stub

## Login Flow

1. Validate mobile format (mobileRe `^\d{10}$`) — reject before DB query
2. `SELECT id, school_name, password_hash, is_verified FROM teachers WHERE mobile = $1`
3. If row not found → ErrInvalidCredentials (same as wrong password — no field leak)
4. If is_verified = FALSE → ErrInvalidCredentials
5. `bcrypt.CompareHashAndPassword(stored_hash, incoming_password)` — bcrypt cost=12
6. `issueTokens(ctx, teacherID, mobile, schoolName, deviceHint)` → access+refresh tokens

## Refresh Token Design

- **Storage:** SHA-256(raw_token) in refresh_tokens.token_hash; raw never persisted
- **Validation:** HashToken(incoming) → UPDATE WHERE token_hash matches → RETURNING teacher_id
- **Non-rotating:** last_used_at updated, token_hash unchanged — client keeps same refresh token
- **Non-expiring:** no expires_at column on refresh_tokens; only deleted on explicit Logout
- **Multi-device:** each device has its own row; Logout deletes only the matching row

## JWT Middleware Context Keys

| Key | Type | Value |
|-----|------|-------|
| `ContextKeyTeacherID` | `contextKey("teacher_id")` | UUID string |
| `ContextKeyMobile` | `contextKey("mobile")` | 10-digit string |
| `ContextKeySchoolName` | `contextKey("school_name")` | School name string |

Access in downstream handlers: `auth.TeacherIDFromContext(r.Context())`

## Deviations from Plan

None — plan executed exactly as written. Two-step Refresh approach used as recommended in plan notes.

## Issues Encountered

None. `go build ./...` and `go vet ./...` both pass with zero errors after each task.

## Next Phase Readiness

- Plan 02-04 (integration or final wiring) can begin immediately
- All 6 auth endpoints fully functional: send-otp, verify-otp, retry-otp, login, refresh, logout
- JWTMiddleware is production-ready for Phase 3 route protection
- TeacherIDFromContext available for all Phase 3 protected handlers

---
*Phase: 02-go-auth-api*
*Completed: 2026-05-19*
