-- Migration: 20260519000004_otp_sessions.sql
-- OTP session storage for the registration flow
--
-- When Go calls MSG91 sendOTP, MSG91 returns a reqId.
-- We store reqId here (NOT the OTP itself) to:
--   1. Track which mobile is waiting for verification
--   2. Enforce 10-minute OTP expiry server-side
--   3. Count wrong OTP attempts (lockout at 3)
--   4. Enforce 60-second resend timer
--
-- No FK to teachers table: teacher may not exist yet (registration creates them)

CREATE TABLE otp_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mobile          TEXT NOT NULL,
  req_id          TEXT NOT NULL,
  attempt_count   INTEGER NOT NULL DEFAULT 0,
  last_retry_at   TIMESTAMPTZ,
  -- last_retry_at: set on each retry; checked for 60s cooldown enforcement
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
  is_used         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON otp_sessions(mobile);
CREATE UNIQUE INDEX ON otp_sessions(req_id);
-- req_id UNIQUE INDEX: verifyOTP looks up by req_id; unique prevents accidental duplicates
