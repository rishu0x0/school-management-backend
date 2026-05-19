-- Migration: 20260519000003_triggers.sql
-- Database-level attendance lock triggers (defense-in-depth)
--
-- PRIMARY enforcement is in the Go API (Phase 3) using IST timezone logic:
--   time.LoadLocation("Asia/Kolkata") to determine midnight IST.
-- These triggers are the SECONDARY layer — they check the is_locked BOOLEAN
-- flag set by the Go API. They do NOT perform timezone math.
--
-- Why defense-in-depth: If the Go API has a timezone bug or is bypassed,
-- these triggers prevent data corruption at the DB level.
-- The trigger only checks is_locked = TRUE — it does not need to know
-- about IST vs UTC. That complexity lives entirely in Go.

-- ============================================================
-- Trigger 1: Block UPDATE on attendance_records if session is locked
-- ============================================================
CREATE OR REPLACE FUNCTION check_attendance_not_locked()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM attendance_sessions
    WHERE id = NEW.session_id
      AND is_locked = TRUE
  ) THEN
    RAISE EXCEPTION 'attendance_locked'
      USING DETAIL = 'This attendance session is locked and cannot be modified.',
            HINT = 'Attendance can only be edited on the day of submission before midnight IST.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER attendance_record_lock_check
  BEFORE UPDATE ON attendance_records
  FOR EACH ROW EXECUTE FUNCTION check_attendance_not_locked();

-- ============================================================
-- Trigger 2: Block UPDATE on attendance_sessions if already locked
-- Prevents the Go API from accidentally unlocking a session
-- ============================================================
CREATE OR REPLACE FUNCTION check_session_not_locked()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_locked = TRUE THEN
    RAISE EXCEPTION 'attendance_locked'
      USING DETAIL = 'This attendance session is already locked and cannot be modified.',
            HINT = 'Locked sessions cannot be unlocked. Contact support if this is an error.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER attendance_session_lock_check
  BEFORE UPDATE ON attendance_sessions
  FOR EACH ROW EXECUTE FUNCTION check_session_not_locked();
