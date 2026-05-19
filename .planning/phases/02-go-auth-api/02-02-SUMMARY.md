---
phase: 02-go-auth-api
plan: "02"
subsystem: auth
tags: [go, msg91, jwt, bcrypt, otp, registration]

# Dependency graph
requires:
  - phase: 02-go-auth-api
    plan: "01"
    provides: Go scaffold with Chi router, pgx pool, config (MSG91_AUTH_TOKEN, MSG91_WIDGET_ID, JWT_SECRET, JWT_ACCESS_EXPIRY), otp_sessions table

provides:
  - backend/internal/msg91/client.go: MSG91 Widget OTP client (SendOTP, VerifyOTP, RetryOTP)
  - backend/pkg/jwt/jwt.go: JWT generation (HS256), ParseAccessToken, GenerateRefreshToken (SHA-256 hash), HashToken
  - backend/internal/auth/errors.go: Sentinel errors and ValidationError type used across service and handler
  - backend/internal/auth/service.go: Registration business logic (SendRegistrationOTP, VerifyRegistrationOTP, RetryOTP, issueTokens)
  - backend/internal/auth/handler.go: HTTP handlers for 3 registration endpoints + 3 stubs for 02-03
  - backend/internal/auth/middleware.go: JWTMiddleware stub (pass-through; full implementation in 02-03)
  - backend/cmd/server/main.go: Updated with auth routes fully wired

affects: [02-03, 02-04, 03-01, 03-02, 03-03, 03-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - MSG91 Widget API: POST /sendOTP, /verifyOTP, /retryOTP with authkey header and widgetId in JSON body
    - Country code prepended in service layer ("91" + 10-digit mobile) — Flutter SDK handles this client-side, Go does it server-side
    - bcrypt cost=12 for password hashing (OWASP recommended minimum)
    - Refresh token: 32-byte crypto/rand, stored as SHA-256 hex hash only — raw token sent to client once, never stored
    - JWT access token: HS256 with teacher_id, mobile, school_name custom claims + standard RegisteredClaims (exp, iat, sub)
    - OTP lockout: attempt_count >= 3 blocks verify before calling MSG91; prevents brute-force without MSG91 rate limit dependency
    - errors.Is/errors.As pattern in handler for typed error → HTTP status mapping

key-files:
  created:
    - backend/internal/msg91/client.go
    - backend/pkg/jwt/jwt.go
    - backend/internal/auth/errors.go
    - backend/internal/auth/service.go
    - backend/internal/auth/handler.go
    - backend/internal/auth/middleware.go
  modified:
    - backend/cmd/server/main.go

key-decisions:
  - "errors.go written before service.go so service.go can reference ValidationError — Go compilation requires all package symbols available"
  - "Country code (91) prepended in service.SendRegistrationOTP, not in handler — keeps HTTP API mobile-format-agnostic (10 digits)"
  - "OTP attempt lockout checked before calling MSG91 VerifyOTP — avoids unnecessary external API calls on locked sessions"
  - "JWTMiddleware stub in middleware.go lets /auth/logout route compile and register in main.go; full enforcement implemented in 02-03"
  - "refresh_tokens.device_hint is nullable — nullableString() helper converts empty string to nil for pgx"

# Metrics
duration: 4min
completed: 2026-05-19
---

# Phase 2 Plan 02: Auth Registration Flow Summary

**MSG91 Widget OTP client + JWT service + teacher registration endpoints (send-otp, verify-otp, retry-otp) — complete registration flow from mobile number to JWT token pair**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-19T15:44:24Z
- **Completed:** 2026-05-19T15:48:01Z
- **Tasks:** 4
- **Files modified:** 6 created, 1 modified

## Accomplishments

- MSG91 Widget OTP client in `internal/msg91` with `SendOTP`, `VerifyOTP`, `RetryOTP` — calls `control.msg91.com/api/v5/widget/*` with `authkey` header and `widgetId` in JSON body
- JWT service in `pkg/jwt` with HS256 access token (teacher_id, mobile, school_name claims, 24h expiry), `ParseAccessToken`, 32-byte `GenerateRefreshToken` with SHA-256 hash for DB storage
- Auth service in `internal/auth` with full registration flow: field validation, duplicate mobile check, MSG91 sendOTP, otp_sessions insert, verifyOTP with attempt counting, bcrypt(cost=12) password hash, teacher INSERT, token issuance
- HTTP handlers for all 3 registration endpoints with typed error → HTTP status mapping (409 for duplicate, 403 for locked, 400 for invalid/expired)
- JWTMiddleware stub in middleware.go enables main.go to compile the /auth/logout protected route
- main.go fully wired: jwtSvc and msg91Client constructed from cfg, all 6 auth routes registered

## Task Commits

1. **Task 1: Write MSG91 Widget OTP client** — `1a247dd` (feat)
2. **Task 2: Write JWT package** — `b14ce7d` (feat)
3. **Task 3: Write auth service (registration business logic)** — `2c8b429` (feat)
4. **Task 4: Write auth errors, handler, and wire routes in main.go** — `7cdd88a` (feat)

## Files Created/Modified

- `backend/internal/msg91/client.go` — MSG91 Widget API client; post() shared helper with authkey header
- `backend/pkg/jwt/jwt.go` — JWT Service struct, GenerateAccessToken, ParseAccessToken, GenerateRefreshToken, HashToken
- `backend/internal/auth/errors.go` — Sentinel errors (ErrDuplicateMobile, ErrOTPInvalid, ErrOTPLocked, etc.) + ValidationError
- `backend/internal/auth/service.go` — Registration business logic: SendRegistrationOTP, VerifyRegistrationOTP, RetryOTP, issueTokens
- `backend/internal/auth/handler.go` — HTTP handlers; Login/Refresh/Logout stubs for 02-03
- `backend/internal/auth/middleware.go` — JWTMiddleware pass-through stub; full implementation in 02-03
- `backend/cmd/server/main.go` — Added imports, jwtSvc + msg91Client construction, auth route group

## MSG91 Widget API Endpoints Used

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Send OTP | POST https://control.msg91.com/api/v5/widget/sendOTP | Send OTP to mobile; returns reqId in Message field |
| Verify OTP | POST https://control.msg91.com/api/v5/widget/verifyOTP | Verify user-entered OTP; type=="success" = valid |
| Retry OTP | POST https://control.msg91.com/api/v5/widget/retryOTP | Resend via channel (11=SMS, 4=VOICE, 3=EMAIL, 12=WHATSAPP) |

All requests include `authkey: 509550TgxMsbOhd69e240dcP1` header and `widgetId: 3664716e6457393138393133` in JSON body.

## Registration Flow Sequence

1. `POST /auth/register/send-otp` with `{name, mobile, school_name, password}`
   - Validate: name not empty, mobile=10 digits, school_name not empty, password ≥8 chars with uppercase+digit
   - Check `teachers` table for duplicate mobile → 409 if exists
   - Call MSG91 SendOTP with "91"+mobile → receive reqId
   - Insert into `otp_sessions(mobile, req_id)` → 10-minute expiry set by migration default
   - Return `{req_id}`

2. `POST /auth/register/verify-otp` with `{req_id, otp, name, mobile, school_name, password}`
   - Load otp_sessions row by req_id → 400 if not found
   - Check is_used, expires_at, attempt_count ≥ 3 → appropriate error
   - Call MSG91 VerifyOTP → increment attempt_count on failure; lock at 3
   - Mark session is_used=TRUE
   - bcrypt hash password at cost 12
   - INSERT teacher row with is_verified=TRUE → return id
   - Generate access token (HS256, 24h) + refresh token (32-byte random)
   - Store SHA-256 hash of refresh token in refresh_tokens table
   - Return `{access_token, refresh_token}` → HTTP 201

3. `POST /auth/otp/retry` with `{req_id, retry_channel?}`
   - Validate session alive (not expired, not used)
   - Call MSG91 RetryOTP with channel (default 11=SMS)
   - Update last_retry_at
   - Return `{success: true}`

## JWT Claims Structure

```json
{
  "teacher_id": "<uuid>",
  "mobile": "9876543210",
  "school_name": "Springfield High",
  "exp": 1779291000,
  "iat": 1779204600,
  "sub": "<uuid>"
}
```

Signing: HS256 with JWT_SECRET env var. Expiry: JWT_ACCESS_EXPIRY env var (default 24h).

## Refresh Token Storage

- **Generation:** `crypto/rand` 32 bytes → hex-encoded 64-char raw string
- **Client receives:** Raw 64-char hex string (returned once in registration response)
- **DB stores:** SHA-256(raw) hex string in `refresh_tokens.token_hash`
- **Verification (02-03):** Hash incoming token, compare to stored hash

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] errors.go written as part of Task 3, not Task 4**
- **Found during:** Task 3 (writing service.go)
- **Issue:** service.go references `ErrDuplicateMobile`, `ErrSessionNotFound`, `ErrOTPInvalid`, etc. and `ValidationError` — all defined in errors.go. Go requires all package symbols to be available at compile time. Writing service.go without errors.go would fail `go build`.
- **Fix:** Wrote `errors.go` before `service.go` within Task 3 execution. This is an ordering fix, not scope creep — errors.go was already planned as part of Task 4. Committed both files together in Task 3 commit.
- **Files modified:** `backend/internal/auth/errors.go` (created early)
- **Impact:** None — errors.go contents unchanged from plan; just executed one task earlier.

---

**Total deviations:** 1 auto-fixed (ordering)
**Impact on plan:** Zero scope change; go build ./... passes with zero errors.

## Issues Encountered

None. All 4 tasks executed cleanly. `go build ./...` and `go vet ./...` both pass.

## Next Phase Readiness

- Plan 02-03 (Login + Refresh + Logout + full JWTMiddleware) can begin immediately
- `pkg/jwt.Service.ParseAccessToken` and `pkg/jwt.HashToken` are ready for 02-03 to use in middleware and refresh token verification
- `auth.Handler` Login/Refresh/Logout stubs are already registered on the router — 02-03 just replaces the 501 implementations

---
*Phase: 02-go-auth-api*
*Completed: 2026-05-19*
