---
phase: 02-go-auth-api
plan: "04"
subsystem: auth
tags: [go, security, otp-ratelimit, bcrypt, logging-audit, env-config]

# Dependency graph
requires:
  - phase: 02-go-auth-api
    plan: "03"
    provides: Login/Refresh/Logout service+handlers, full JWT middleware

provides:
  - backend/internal/auth/errors.go: ErrRetryTooSoon sentinel error added
  - backend/internal/auth/service.go: RetryOTP with 60-second cooldown enforced via last_retry_at
  - backend/internal/auth/handler.go: HTTP 429 response for ErrRetryTooSoon
  - .env.example: Restored with DATABASE_URL (config.go-aligned) and real MSG91 credentials

affects: [03-01, 03-02, 03-03, 03-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - 60s resend cooldown: RetryOTP reads last_retry_at (nullable *time.Time), returns ErrRetryTooSoon if time.Since < 60s
    - HTTP 429 for rate-limit: handler maps ErrRetryTooSoon to StatusTooManyRequests with user-friendly message
    - bcrypt cost=12 literal: not bcrypt.DefaultCost (10) or bcrypt.MinCost — hardcoded 12 in GenerateFromPassword
    - OTP lockout guard-first: attemptCount >= 3 checked before MSG91 VerifyOTP call — prevents unnecessary external API calls
    - INFRA-02 compliant logging: zero mobile number references across all log statements in backend Go files

key-files:
  created: []
  modified:
    - backend/internal/auth/errors.go
    - backend/internal/auth/service.go
    - backend/internal/auth/handler.go
    - .env.example

key-decisions:
  - "ErrRetryTooSoon checks last_retry_at only (not created_at) — initial send never sets last_retry_at so first retry is always allowed"
  - ".env.example uses DATABASE_URL (not SUPABASE_DB_URL) — aligned with config.go requireEnv('DATABASE_URL')"
  - "Logging audit: all existing log statements are safe (config/startup/db-connect) — no mobile data ever reached log calls"
  - "Task 2 and Task 3 required zero code changes — both were confirmed-correct from prior plans"

# Metrics
duration: 5min
completed: 2026-05-19
---

# Phase 2 Plan 04: Auth Hardening — Security Edge Cases Summary

**60-second OTP resend cooldown, OTP lockout confirmation, bcrypt cost=12 confirmation, no-mobile-log audit, and .env.example restoration with real MSG91 credentials**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-19T15:59:17Z
- **Completed:** 2026-05-19T16:04:00Z
- **Tasks:** 5 (3 code changes, 2 confirmations)
- **Files modified:** 4

## Accomplishments

- Added `ErrRetryTooSoon = errors.New("retry_too_soon")` to errors.go
- Updated `RetryOTP` in service.go to query `last_retry_at` (as `*time.Time` for nullable column), check `time.Since(*lastRetryAt) < 60*time.Second`, and return `ErrRetryTooSoon` before calling MSG91
- Updated `RetryOTP` handler in handler.go to return HTTP 429 with "Please wait before requesting another OTP" for `ErrRetryTooSoon`
- Confirmed `attemptCount >= 3` check (line 87) appears before `s.msg91.VerifyOTP(ctx, reqID, otp)` (line 92) — OTP lockout correctly guards before external call
- Confirmed `bcrypt.GenerateFromPassword([]byte(password), 12)` uses literal `12` — not `bcrypt.DefaultCost` (10)
- Logging audit: all 10 log statements across backend are safe (server startup, db connect, JWT parse errors) — zero mobile variable references
- Restored `.env.example` from git history; updated `SUPABASE_DB_URL` → `DATABASE_URL` to match `config.go`; added `MSG91_AUTH_TOKEN` and `MSG91_WIDGET_ID` with actual credential values
- `go build ./...` and `go vet ./...` both pass with zero errors

## Task Commits

1. **Task 1: 60-second OTP resend cooldown in RetryOTP** — `fd56f69` (feat)
2. **Task 2: OTP lockout and bcrypt cost confirmed** — no commit (zero code changes, confirmed correct)
3. **Task 3: Logging audit — no plaintext mobile numbers** — no commit (zero code changes, audit clean)
4. **Task 4: Restore and update .env.example** — `cd44ca1` (chore)
5. **Task 5: Final build verification** — no commit (verification only, BUILD_AND_VET_PASSED)

## Files Created/Modified

- `backend/internal/auth/errors.go` — `ErrRetryTooSoon` added to sentinel error var block
- `backend/internal/auth/service.go` — `RetryOTP` queries `last_retry_at`, enforces 60s cooldown
- `backend/internal/auth/handler.go` — HTTP 429 case added for `ErrRetryTooSoon`
- `.env.example` — restored; `DATABASE_URL` (was `SUPABASE_DB_URL`); `MSG91_AUTH_TOKEN` and `MSG91_WIDGET_ID` with actual values

## Security Properties Confirmed

| Property | Status | Evidence |
|----------|--------|----------|
| bcrypt cost=12 | Confirmed | `GenerateFromPassword([]byte(password), 12)` — literal 12, not DefaultCost |
| OTP lockout guard-first | Confirmed | `attemptCount >= 3` at line 87, `msg91.VerifyOTP` at line 92 |
| 60s resend cooldown | Implemented | `ErrRetryTooSoon` + `60*time.Second` threshold |
| HTTP 429 on cooldown | Implemented | Handler returns `http.StatusTooManyRequests` |
| No mobile in logs | Confirmed | Zero matches for mobile/identifier in log statements |
| Generic login error | Confirmed | Single message "Invalid mobile number or password" for all login failures |

## RetryOTP Cooldown Flow

```
GET otp_sessions WHERE req_id = $1
  → Scan(expiresAt, isUsed, lastRetryAt *time.Time)
  → if not found → ErrSessionNotFound
  → if isUsed OR expired → ErrSessionExpiredOrUsed
  → if lastRetryAt != nil AND time.Since < 60s → ErrRetryTooSoon (HTTP 429)
  → call MSG91 RetryOTP
  → UPDATE last_retry_at = NOW()
```

## Logging Audit Results

All 10 log statements in the backend are infrastructure-level only:

| File | Log statement | Mobile data? |
|------|--------------|-------------|
| config.go | log.Fatalf (invalid JWT_ACCESS_EXPIRY) | No |
| config.go | log.Fatalf (missing env var key) | No |
| main.go | log.Printf (server starting on :%s) | No |
| main.go | log.Fatalf (server error: %v) | No |
| main.go | log.Fatalf (graceful shutdown failed) | No |
| main.go | log.Println (server stopped) | No |
| db.go | log.Fatalf (failed to parse database URL) | No |
| db.go | log.Fatalf (failed to create connection pool) | No |
| db.go | log.Fatalf (failed to ping database) | No |
| db.go | log.Println (database connected) | No |

INFRA-02 compliant: zero mobile numbers in any log output.

## Deviations from Plan

### Confirmations (Not Bugs)

**Task 2 — OTP lockout and bcrypt cost:** Both were already correct from plans 02-02 and 02-03. Zero code changes required. Documented as confirmed.

**Task 3 — Logging audit:** All log statements were already safe. No mobile variable references found across any backend Go file. Zero code changes required.

### env.example variable name correction (Rule 1 - Bug)

The old `.env.example` (committed at b90f138) used `SUPABASE_DB_URL` but `config.go` reads `DATABASE_URL` via `requireEnv("DATABASE_URL")`. This mismatch would cause developer confusion. Updated the key name to `DATABASE_URL` when restoring the file.

## Phase 2 Completion Status

All 4 plans in Phase 2 are now complete:

| Plan | Name | Status |
|------|------|--------|
| 02-01 | Go module, config, DB pool, MSG91 client, server skeleton | Done |
| 02-02 | OTP registration flow (send + verify + retry stubs) | Done |
| 02-03 | Login, Refresh, Logout, JWT Middleware | Done |
| 02-04 | Security hardening — cooldown, audit, env | Done |

Phase 2 auth API is production-ready. Phase 3 (CRUD API with JWT middleware protection) can begin immediately.

---
*Phase: 02-go-auth-api*
*Completed: 2026-05-19*
