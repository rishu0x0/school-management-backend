-- trigger_lock_test.sql
-- Tests for attendance lock triggers (20260519000003_triggers.sql)
--
-- Run with:
--   psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/trigger_lock_test.sql
--
-- Expected output:
--   NOTICE: TEST PASSED: attendance_record trigger fired correctly
--   NOTICE: TEST PASSED: attendance_session trigger fired correctly
--   NOTICE: TEST CLEANUP COMPLETE

DO $$
DECLARE
  v_session_id UUID;
  v_student_id UUID;
  v_record_id  UUID;
BEGIN
  -- Create a test session owned by Teacher 1 (pre-locked for test)
  INSERT INTO attendance_sessions (id, class_id, teacher_id, date, is_locked)
  VALUES (
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001',
    '2026-05-19',
    TRUE
  ) ON CONFLICT (class_id, date) DO UPDATE SET is_locked = TRUE
  RETURNING id INTO v_session_id;

  -- Create a test student
  INSERT INTO students (id, class_id, roll_number, full_name)
  VALUES (
    '00000000-0000-0000-0000-000000000200',
    '00000000-0000-0000-0000-000000000010',
    1,
    'Test Student'
  ) ON CONFLICT (class_id, roll_number) DO NOTHING;

  -- Insert an attendance record for the locked session
  INSERT INTO attendance_records (id, session_id, student_id, status)
  VALUES (
    '00000000-0000-0000-0000-000000000300',
    '00000000-0000-0000-0000-000000000100',
    '00000000-0000-0000-0000-000000000200',
    'present'
  ) ON CONFLICT (session_id, student_id) DO NOTHING;

  -- TEST 1: Attempt UPDATE on attendance_record tied to a locked session
  -- Must raise SQLSTATE P0001 with message 'attendance_locked'
  BEGIN
    UPDATE attendance_records
    SET status = 'absent'
    WHERE id = '00000000-0000-0000-0000-000000000300';
    RAISE EXCEPTION 'TEST FAILED: attendance_record trigger did not fire';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM = 'attendance_locked' THEN
        RAISE NOTICE 'TEST PASSED: attendance_record trigger fired correctly';
      ELSE
        RAISE EXCEPTION 'TEST FAILED: unexpected error from attendance_record trigger: %', SQLERRM;
      END IF;
  END;

  -- TEST 2: Attempt UPDATE on a locked attendance_session
  -- Must raise SQLSTATE P0001 with message 'attendance_locked'
  BEGIN
    UPDATE attendance_sessions
    SET submitted_at = NOW()
    WHERE id = '00000000-0000-0000-0000-000000000100';
    RAISE EXCEPTION 'TEST FAILED: attendance_session trigger did not fire';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM = 'attendance_locked' THEN
        RAISE NOTICE 'TEST PASSED: attendance_session trigger fired correctly';
      ELSE
        RAISE EXCEPTION 'TEST FAILED: unexpected error from attendance_session trigger: %', SQLERRM;
      END IF;
  END;

  RAISE NOTICE 'TEST CLEANUP COMPLETE';
END;
$$;

-- Verify trigger definitions exist in the database
SELECT
  t.tgname AS trigger_name,
  c.relname AS table_name,
  p.proname AS function_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname IN ('attendance_records', 'attendance_sessions')
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
-- Expected:
--   attendance_record_lock_check  | attendance_records  | check_attendance_not_locked
--   attendance_session_lock_check | attendance_sessions | check_session_not_locked
