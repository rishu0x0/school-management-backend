# Supabase Runbook — Phase 1 Database Foundation

**Using Supabase Cloud (not local Docker).** Credentials are in `.env`.

To apply migrations to the cloud project:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

---

## Step 1 (Cloud): Apply Migrations

```bash
cd "/Users/rishujain/Desktop/Everything/School Management"
supabase start
```

Expected output includes URLs for the local dashboard, API, DB, and inbucket.
Note the DB URL printed: `postgresql://postgres:postgres@localhost:54322/postgres`

---

## Step 2: Apply All Migrations from Scratch (Full Reset)

```bash
supabase db reset
```

Expected output:
```
Resetting database...
Initialising schema...
Applying migration 20260519000001_create_schema.sql...
Applying migration 20260519000002_rls_policies.sql...
Applying migration 20260519000003_triggers.sql...
Seeding data...
Finished supabase db reset.
```

Zero errors. If any migration errors appear, fix the offending SQL and re-run.

---

## Step 3: Verify Schema — Tables, Policies, Triggers

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -c "
SELECT 'tables' AS type, count(*) FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name IN
    ('teachers','refresh_tokens','classes','students','attendance_sessions','attendance_records','generated_reports')
UNION ALL
SELECT 'rls_policies', count(*) FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'triggers', count(*) FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid
  WHERE c.relname IN ('attendance_records','attendance_sessions') AND NOT t.tgisinternal;
"
```

Expected result:
```
   type     | count
------------+-------
 tables     |     7
 rls_policies |   7
 triggers   |     2
```

---

## Step 4: Run RLS Isolation Tests

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_isolation_test.sql
```

Expected: all 7 NOTICE lines with "PASS" — no "FAIL" lines.

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/rls_policy_check.sql
```

Expected: 7 tables with rowsecurity=true, 7 policies in pg_policies, zero bare auth.uid() calls.

---

## Step 5: Run Trigger Lock Tests

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -f supabase/tests/trigger_lock_test.sql
```

Expected output:
```
NOTICE:  TEST PASSED: attendance_record trigger fired correctly
NOTICE:  TEST PASSED: attendance_session trigger fired correctly
NOTICE:  TEST CLEANUP COMPLETE
```

Also verify trigger definitions exist:
```
      trigger_name         |      table_name       |         function_name
---------------------------+-----------------------+-------------------------------
 attendance_record_lock_check  | attendance_records  | check_attendance_not_locked
 attendance_session_lock_check | attendance_sessions | check_session_not_locked
```

---

## Step 6: Link to Remote Supabase Project

If not already linked:

```bash
supabase login
# Opens browser for auth

supabase projects list
# Find your project ref (e.g., abcdefghijklmnop)

supabase link --project-ref <your-project-ref>
# Prompts for DB password — find at: Dashboard -> Project Settings -> Database -> Database password
```

---

## Step 7: Push All Migrations to Remote

```bash
supabase migration list
# Shows which migrations are applied locally vs remotely
# Before push: local = 3 checked, remote = 0 (or fewer)

supabase db push
# Applies un-applied migrations to remote DB in order
```

Expected push output:
```
Applying migration 20260519000001_create_schema.sql...
Applying migration 20260519000002_rls_policies.sql...
Applying migration 20260519000003_triggers.sql...
Finished supabase db push.
```

---

## Step 8: Verify Remote State

```bash
supabase migration list
```

Expected: all 3 migrations show checkmarks in BOTH the local and remote columns.

Then verify in Supabase Dashboard:
- https://app.supabase.com/project/<your-project-ref>/database/tables
  - Confirm all 7 tables are visible
- https://app.supabase.com/project/<your-project-ref>/auth/policies
  - Confirm all 7 RLS policies are listed
- https://app.supabase.com/project/<your-project-ref>/database/functions
  - Confirm check_attendance_not_locked and check_session_not_locked appear

---

## Troubleshooting

**"Cannot connect to the remote database"**
Re-run `supabase link --project-ref <ref>` with the correct project ref from `supabase projects list`.

**"Schema mismatch" on db push**
The remote DB was modified outside migrations (e.g. via Dashboard).
Run `supabase db diff --use-migra` to see the diff.
Create a repair migration if needed.

**Migration applies out of order**
Check filenames — must be `YYYYMMDDNNNNNN_description.sql`.
Supabase CLI applies strictly by timestamp prefix order.
NEVER rename a migration file after it has been applied.

**trigger_lock_test.sql fails with "TEST FAILED"**
Verify migration 20260519000003_triggers.sql was applied:
```bash
psql postgresql://postgres:postgres@localhost:54322/postgres -c "
SELECT tgname FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname IN ('attendance_records','attendance_sessions') AND NOT t.tgisinternal;
"
```
If empty, run `supabase db reset` again.
