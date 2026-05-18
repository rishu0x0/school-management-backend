# Roadmap: School Management App — Attendance Module

## Overview

Eight phases take this project from a blank Supabase schema to a production-ready attendance app on the App Store and Play Store. The database schema and RLS policies are the foundation everything else builds on. Go handles all business logic and report generation server-side. Flutter delivers the Tinder-style swipe interface. The critical path is: schema → Go auth → Go CRUD (parallel with Flutter auth shell) → Flutter features → reports → QA and ship.

## Phases

**Phase Numbering:**
- Integer phases (1–8): Planned milestone work
- Decimal phases (e.g., 2.1): Urgent insertions via `/gsd:insert-phase`

Phases execute in numeric order. Phase 3 and Phase 4 can be developed in parallel.

- [ ] **Phase 1: Database Foundation** - Supabase schema, RLS policies, and migrations — everything else builds on this
- [ ] **Phase 2: Go Auth API** - JWT authentication, MSG91 OTP, refresh token table, and all auth endpoints
- [ ] **Phase 3: Go CRUD API** - Classes, students, attendance endpoints, IST midnight lock, and report generation backend
- [ ] **Phase 4: Flutter Auth Shell** - Routing, auth guard, JWT refresh interceptor, login and registration screens
- [ ] **Phase 5: Flutter Class + Student Management** - Class list, CRUD screens, student list, dummy seed button
- [ ] **Phase 6: Flutter Attendance Swipe** - Swipe cards, summary screen, submission flow, and statistics screen
- [ ] **Phase 7: Reports (Backend + Flutter)** - PDF/Excel generation, cron auto-export, Supabase Storage, Flutter download UI
- [ ] **Phase 8: Integration, QA + Hardening** - IST timezone integration tests, RLS multi-teacher isolation tests, platform compatibility, App Store build

## Phase Details

### Phase 1: Database Foundation
**Goal**: A fully migrated Supabase schema with all tables, indexes, constraints, and RLS policies — every subsequent phase has a stable, secure data layer to build against
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-03
**Success Criteria** (what must be TRUE):
  1. All tables (teachers, refresh_tokens, classes, students, attendance_records, reports) exist in Supabase with correct columns, types, and constraints
  2. RLS is enabled on every table and a teacher can only read/write rows they own — verified by running queries as two different teacher IDs
  3. Migration files are version-controlled and `supabase db reset` reproduces the full schema cleanly
  4. All foreign key constraints, unique constraints (e.g., roll number unique per class, class name unique per teacher), and check constraints are in place
  5. Service role key grants full access (used by Go backend); anon key is restricted to zero rows by RLS
**Plans**: TBD

Plans:
- [ ] 01-01: Design and write all table migrations (teachers, refresh_tokens, classes, students, attendance_records, reports)
- [ ] 01-02: Write and apply RLS policies for all tables; verify isolation with two-teacher test queries
- [ ] 01-03: Version-control migrations, validate schema with `supabase db reset`, document connection string setup

### Phase 2: Go Auth API
**Goal**: A running Go server that handles teacher registration with MSG91 OTP, login, silent refresh, logout, and all JWT middleware — teachers can create accounts and authenticate
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09, AUTH-10, AUTH-11, AUTH-12, AUTH-13, INFRA-01, INFRA-02
**Success Criteria** (what must be TRUE):
  1. A teacher can POST to `/auth/register`, receive an OTP on their mobile (via MSG91), verify it, and get back a JWT access token + refresh token
  2. A teacher can POST to `/auth/login` with mobile + password and receive valid tokens; wrong credentials return a generic error without revealing which field failed
  3. POST to `/auth/refresh` with a valid refresh token returns a new access token; a blacklisted or tampered token returns 401
  4. POST to `/auth/logout` invalidates only the current device's refresh token; other device tokens remain active
  5. Duplicate mobile registration returns a clear error; OTP sessions expire in 10 minutes and lock after 3 wrong attempts; passwords stored as bcrypt cost-12 hashes
**Plans**: TBD

Plans:
- [ ] 02-01: Go project scaffold — Chi router, pgx pool, sqlc codegen, config, health endpoint; MSG91 DLT registration confirmed as pre-requisite action before this plan
- [ ] 02-02: Registration flow — validate fields, send MSG91 OTP, store session_id, verify OTP, create teacher row, return tokens
- [ ] 02-03: Login, refresh, logout endpoints; JWT middleware; refresh token table (device_hint, last_used_at, blacklisted flag)
- [ ] 02-04: Auth edge cases — duplicate mobile check, 3-attempt OTP lockout, 60s resend timer enforcement, bcrypt cost-12, no plaintext mobile logging

### Phase 3: Go CRUD API
**Goal**: All class, student, and attendance business logic is exposed via authenticated API endpoints — Flutter can perform any data operation, and the midnight IST lock is enforced at the API layer
**Depends on**: Phase 2
**Requirements**: CLS-01, CLS-02, CLS-03, CLS-04, CLS-05, STU-01, STU-02, STU-03, STU-04, STU-05, STU-06, ATT-01, SUB-05, SUB-06, SUB-07, SUB-08
**Success Criteria** (what must be TRUE):
  1. Authenticated teacher can create, list, edit, and delete classes; class names are unique per teacher; deletion cascades with a warning (enforced by API)
  2. Authenticated teacher can add, list, edit, and soft-remove students; roll numbers auto-assign if omitted and are unique per class; removed students show as "(Removed)" in attendance history
  3. Teacher can seed N dummy students into a class via a single endpoint; default is 30
  4. Attendance can be submitted as a batch transaction for a class on a given date; duplicate same-day submissions are rejected with a clear error
  5. Attendance edit requests after midnight IST are rejected with a clear error; `time.LoadLocation("Asia/Kolkata")` used — not UTC offset arithmetic
**Plans**: TBD

Plans:
- [ ] 03-01: Classes CRUD endpoints (list, create, edit, delete) with unique-name constraint and cascade-delete confirmation flag
- [ ] 03-02: Students CRUD endpoints (list, add, edit, soft-remove, seed-dummy); auto roll-number assignment; uniqueness enforcement
- [ ] 03-03: Attendance endpoints (submit batch, get by date, edit); IST midnight lock in `pkg/timezone`; single-transaction batch save; duplicate-day rejection
- [ ] 03-04: Statistics endpoints (today summary counts, monthly overview, students below 75%); integration tests for IST lock boundary

### Phase 4: Flutter Auth Shell
**Goal**: Flutter app launches, silently restores sessions from secure storage, routes teachers to the correct screen, and handles all auth flows including network errors — no teacher is ever accidentally logged out
**Depends on**: Phase 2 (can be developed in parallel with Phase 3)
**Requirements**: AUTH-08, AUTH-09, AUTH-10, INFRA-04
**Success Criteria** (what must be TRUE):
  1. On app launch with a stored refresh token, the teacher sees the Home Screen directly — the Login screen never flashes
  2. On network failure during silent refresh, the teacher sees a "No internet connection" retry screen — they are NOT redirected to Login
  3. The app redirects to Login only when the server explicitly rejects the refresh token (401 from `/auth/refresh`)
  4. Dio interceptor queues parallel requests during a token refresh — no duplicate refresh calls and no request is lost
  5. All protected routes require a valid token; unauthenticated deep links redirect to Login, then resume intended destination after auth
**Plans**: TBD

Plans:
- [ ] 04-01: Flutter project scaffold — feature-first structure, Riverpod 2.x with codegen, go_router, flutter_secure_storage; CI lint/test pipeline
- [ ] 04-02: Auth state notifier and go_router auth guard; silent refresh on launch; network error vs 401 routing logic
- [ ] 04-03: Login screen, registration screen, OTP verification screen — connected to Phase 2 Go API
- [ ] 04-04: Dio QueuedInterceptorsWrapper for JWT refresh; "No internet" overlay with retry; INFRA-04 network state detection

### Phase 5: Flutter Class + Student Management
**Goal**: Teachers can manage all their classes and students through the Flutter UI — including creating classes, seeding dummy students, and editing the roster — giving them something meaningful to attend before the swipe feature exists
**Depends on**: Phase 3, Phase 4
**Requirements**: CLS-01, CLS-02, CLS-03, CLS-04, CLS-05, STU-01, STU-02, STU-03, STU-04, STU-05, STU-06
**Success Criteria** (what must be TRUE):
  1. Teacher sees their class list on the home screen; an empty state prompts class creation with a clear call to action
  2. Teacher can create a class (name required, section and subject optional), edit its name, and delete it with a confirmation warning about data loss
  3. Teacher can view students in a class ordered by roll number, add a student (name required, roll optional, photo optional), edit, and soft-remove
  4. Teacher can tap "Generate Test Students" and get 30 dummy students with sequential roll numbers — immediately visible in the list
  5. Roll numbers are unique per class and auto-assigned if omitted; class names are unique per teacher account
**Plans**: TBD

Plans:
- [ ] 05-01: Class list screen (home), create/edit class bottom sheet, delete confirmation dialog; empty state design
- [ ] 05-02: Student list screen (ordered by roll), add/edit student form, soft-remove with undo toast, "(Removed)" display for past records
- [ ] 05-03: "Generate Test Students" flow; roll number auto-assignment logic; photo upload via image_picker to Supabase Storage

### Phase 6: Flutter Attendance Swipe
**Goal**: Teachers can take attendance for a full class in under 2 minutes using swipe gestures or tap buttons, review the summary, edit any status, and submit — the core product value is delivered and working
**Depends on**: Phase 5
**Requirements**: ATT-02, ATT-03, ATT-04, ATT-05, ATT-06, ATT-07, ATT-08, ATT-09, ATT-10, SUB-01, SUB-02, SUB-03, SUB-04, SUB-05, SUB-06, SUB-07, SUB-08, ATT-01, STAT-01, STAT-02, STAT-03
**Success Criteria** (what must be TRUE):
  1. Swipe left marks Present (green overlay + checkmark), swipe right marks Absent (red overlay + X), swipe up marks Leave (yellow overlay + icon) — all at 60fps with no jank; tap buttons produce identical results
  2. Progress indicator ("Student X of Y") is always visible; first-launch gesture hints are shown and dismissable; all students must be acted upon before proceeding
  3. Summary screen shows all students with color-coded status tags and aggregate counts (Present X | Absent Y | Leave Z); any status can be changed via a bottom-sheet picker
  4. "Submit Attendance" shows a confirmation dialog mentioning the midnight lock, then saves all records in a single transaction and navigates to Statistics
  5. Statistics screen shows today's donut chart with counts and percentages, monthly attendance day count, average %, and a named list of students below 75% highlighted in red
**Plans**: TBD

Plans:
- [ ] 06-01: Swipe card stack widget — evaluate `flutter_card_swiper v7` (1-day spike); implement card with photo/avatar, name, roll, class; Left/Right/Up gestures at 60fps with colored overlays
- [ ] 06-02: Tap button alternatives (Present / Absent / Leave), undo button (single level), progress indicator, first-launch hint overlay
- [ ] 06-03: Summary screen — color-coded list, aggregate counts, bottom-sheet status picker, submit confirmation dialog
- [ ] 06-04: Submission API call (single batch transaction), success navigation to Statistics, read-only summary with Edit option for already-submitted days
- [ ] 06-05: Statistics screen — today summary card with donut/pie chart (fl_chart), monthly overview, students below 75% named list

### Phase 7: Reports (Backend + Flutter)
**Goal**: Teachers can download PDF and Excel attendance reports for any class and month; reports are also auto-generated on the 1st of every month and stored in Supabase Storage with signed download URLs
**Depends on**: Phase 6
**Requirements**: RPT-01, RPT-02, RPT-03, RPT-04, RPT-05, RPT-06, RPT-07, RPT-08, RPT-09
**Success Criteria** (what must be TRUE):
  1. Teacher can trigger manual PDF or Excel generation from the Reports screen for any class and any month; generation completes within 30 seconds and a download link appears
  2. PDF contains a cover page, data pages (25 students per page × all month days as columns, A4 landscape, P/A/L/— cells), and a summary page with per-student totals and attendance percentages
  3. Excel file has two sheets: "Attendance Data" with the same grid structure, and "Summary" with per-student totals; conditional formatting applies green/red/yellow cell colors; file opens correctly in both MS Excel and Google Sheets
  4. On the 1st of each month at 00:05 IST, a cron job generates reports for all eligible classes; teacher receives an in-app notification when their reports are ready
  5. Generated files are stored in a private Supabase Storage bucket, served via signed URLs, and cleaned up by a Go cron job after 90 days; file names follow the `[SchoolName]_[ClassName]_Attendance_[YYYY-MM]` convention
**Plans**: TBD

Plans:
- [ ] 07-01: PDF generation with maroto v2 — cover page, data pages (25-student pagination, 31-column A4 landscape layout prototype first), summary page; `—` for missing days
- [ ] 07-02: Excel generation with excelize v2 — two-sheet structure, conditional formatting (green/red/yellow); test output in both MS Excel and Google Sheets
- [ ] 07-03: Monthly cron job (`35 18 1 * *` UTC = 00:05 IST) with bounded worker pool (max 10 concurrent); Supabase Storage upload; 90-day cleanup cron; signed URL generation
- [ ] 07-04: Manual report trigger endpoint (`POST /reports/generate`); loading state; in-app notification on completion (RPT-09)
- [ ] 07-05: Flutter Reports screen — class/month selector, trigger button, loading indicator, download link display; open/share file via `open_filex`

### Phase 8: Integration, QA + Hardening
**Goal**: The full system works end-to-end under realistic conditions — IST midnight lock is correct, RLS prevents cross-teacher data access, the app meets performance targets, and production builds are submitted to both app stores
**Depends on**: Phase 7
**Requirements**: INFRA-05, INFRA-06
**Success Criteria** (what must be TRUE):
  1. IST midnight lock integration test passes: attendance submitted at 23:59 IST is editable; a request at 00:01 IST the next day is rejected with a clear error
  2. RLS multi-teacher isolation test passes: Teacher A cannot read, write, or delete any data owned by Teacher B — verified against all tables
  3. App cold start is under 3 seconds; all read API responses are under 500ms; write operations are under 1 second (measured on mid-range Android and iPhone)
  4. Generated PDF opens correctly in Apple Preview, Adobe Acrobat, and Android PDF viewer; Excel opens with correct formatting in MS Excel 2019+ and Google Sheets
  5. Production builds pass App Store Connect and Google Play pre-launch review; Android 6.0 and iOS 13 minimum versions enforced in build configs
**Plans**: TBD

Plans:
- [ ] 08-01: IST timezone integration tests (midnight boundary ±1 minute); RLS multi-teacher data isolation tests for all tables
- [ ] 08-02: Performance profiling — Flutter DevTools frame analysis (60fps swipe), API response time benchmarks under load
- [ ] 08-03: Cross-platform compatibility — PDF in Preview/Acrobat/Android viewer; Excel in MS Excel + Google Sheets; Android 6.0 minimum build test; iOS 13 simulator test
- [ ] 08-04: Production build pipeline — App Store Connect submission (TestFlight), Google Play internal test track; crash reporting setup (Sentry or Firebase Crashlytics)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
Note: Phase 3 and Phase 4 can be developed in parallel — Flutter Auth Shell does not depend on Go CRUD API.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Database Foundation | 0/3 | Not started | - |
| 2. Go Auth API | 0/4 | Not started | - |
| 3. Go CRUD API | 0/4 | Not started | - |
| 4. Flutter Auth Shell | 0/4 | Not started | - |
| 5. Flutter Class + Student Management | 0/3 | Not started | - |
| 6. Flutter Attendance Swipe | 0/5 | Not started | - |
| 7. Reports (Backend + Flutter) | 0/5 | Not started | - |
| 8. Integration, QA + Hardening | 0/4 | Not started | - |
