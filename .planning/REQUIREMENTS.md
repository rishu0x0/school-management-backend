# Requirements: School Management App — Attendance Module

**Defined:** 2026-05-19  
**Core Value:** A teacher can open the app, swipe through their class in under 2 minutes, and have attendance recorded — with monthly reports generated automatically on the 1st of each month.

---

## v1 Requirements

### Authentication (AUTH)

- [ ] **AUTH-01**: Teacher can register with full name, mobile number, school name, and password — form validates all fields inline
- [ ] **AUTH-02**: Registration triggers OTP sent to mobile via MSG91; account is created only after successful OTP verification (no partial accounts)
- [ ] **AUTH-03**: OTP screen shows 6-digit input, 60-second resend timer, max 3 resends per session; OTP expires in 10 minutes
- [ ] **AUTH-04**: 3 incorrect OTP attempts lock the session with clear error message
- [ ] **AUTH-05**: After successful OTP verification, teacher is auto-logged in (tokens returned) and taken to Home Screen — no manual login step
- [ ] **AUTH-06**: Teacher can log in with mobile number and password; valid credentials return JWT + refresh token and navigate to Home Screen
- [ ] **AUTH-07**: Invalid login shows generic error ("Invalid mobile number or password") without revealing which field is wrong
- [ ] **AUTH-08**: On every app launch, app silently uses stored refresh token to obtain fresh access token — teacher sees Home Screen without Login screen
- [ ] **AUTH-09**: On network error during silent refresh, app shows a retry screen — teacher is NOT redirected to Login
- [ ] **AUTH-10**: Teacher is redirected to Login only when server explicitly rejects the refresh token (tampered or blacklisted)
- [ ] **AUTH-11**: Teacher can log out from Settings; logout clears tokens from Flutter Secure Storage and invalidates refresh token server-side
- [ ] **AUTH-12**: Multiple device logins supported — logging out on one device does not affect other device sessions
- [ ] **AUTH-13**: Duplicate mobile number registration blocked with inline error: "This mobile number is already registered. Please login."

### Classes (CLS)

- [ ] **CLS-01**: Teacher can view a list of all their classes from the home/navigation entry point
- [ ] **CLS-02**: Teacher can create a new class with name (required), section (optional), and subject (optional)
- [ ] **CLS-03**: Teacher can edit a class name after creation
- [ ] **CLS-04**: Teacher can delete a class; deletion shows confirmation warning that all student and attendance data will be permanently lost
- [ ] **CLS-05**: Class names are unique within a teacher's account; teacher can have unlimited classes

### Students (STU)

- [ ] **STU-01**: Teacher can view a list of all students in a class, ordered by roll number
- [ ] **STU-02**: Teacher can add a single student to a class with full name (required) and optional roll number (auto-assigned if omitted) and photo
- [ ] **STU-03**: Teacher can edit a student's name, roll number, or photo
- [ ] **STU-04**: Teacher can remove a student from a class; removal does not delete historical attendance records (student shown as "(Removed)" in past reports)
- [ ] **STU-05**: Teacher can generate N dummy students for a class via "Generate Test Students" button (default 30); each gets auto-incremented roll number and dummy name
- [ ] **STU-06**: Each student belongs to exactly one class; roll numbers are unique within a class

### Attendance — Swipe (ATT)

- [ ] **ATT-01**: Teacher can select a class to take attendance; if today's attendance is already submitted, app shows read-only summary with an "Edit" option
- [ ] **ATT-02**: Attendance swipe screen shows one student card at a time (Tinder-style stack); card shows student photo/avatar, full name, roll number, and class name
- [ ] **ATT-03**: Left swipe marks student as Present with green card overlay and ✓ icon at 60fps with no jank
- [ ] **ATT-04**: Right swipe marks student as Absent with red card overlay and ✗ icon at 60fps
- [ ] **ATT-05**: Swipe Up marks student as Leave with yellow/orange card overlay and beach icon at 60fps
- [ ] **ATT-06**: Tap buttons (Present / Absent / Leave) below the card produce the same result as corresponding swipes
- [ ] **ATT-07**: A floating Undo button reverts the last swipe action (single level of undo)
- [ ] **ATT-08**: Swipe gesture hints shown on first launch (dismissable); hint icons always visible at bottom of screen
- [ ] **ATT-09**: Progress indicator ("Student X of Y") shown at top of screen throughout swiping
- [ ] **ATT-10**: All students must be acted upon before proceeding to summary; students ordered by roll number ascending

### Attendance — Summary & Submission (SUB)

- [ ] **SUB-01**: After all students are swiped, summary screen shows all students with color-coded status tags (Present / Absent / Leave)
- [ ] **SUB-02**: Summary screen shows total counts at top: Present: X | Absent: Y | Leave: Z
- [ ] **SUB-03**: Teacher can tap any student row on summary to change their status via a bottom-sheet 3-option picker
- [ ] **SUB-04**: "Submit Attendance" button shows confirmation dialog: "Submit attendance for [Class] on [Date]? This cannot be edited after midnight."
- [ ] **SUB-05**: On confirmed submit, all records are saved to backend in a single transaction; teacher is navigated to Statistics screen on success
- [ ] **SUB-06**: A class can have only one attendance submission per calendar day; subsequent same-day views show the existing record with edit option
- [ ] **SUB-07**: Teacher can edit submitted attendance until 11:59 PM IST on the submission date; records are locked after midnight IST
- [ ] **SUB-08**: Attendance data is held in local state during swiping session; no partial API saves mid-session

### Statistics (STAT)

- [ ] **STAT-01**: Statistics screen shows today's summary card: total students, present count+%, absent count+%, on-leave count+%, and a donut/pie chart
- [ ] **STAT-02**: Statistics screen shows monthly overview: number of days attendance was recorded, average attendance %, and list of students below 75% highlighted in red (as named list, not just %)
- [ ] **STAT-03**: Statistics screen is shown immediately after submission and accessible from the class view anytime

### Reports (RPT)

- [ ] **RPT-01**: Teacher can manually trigger PDF or Excel generation for any class and any month from the Reports section
- [ ] **RPT-02**: PDF report contains: cover page (school name, class, month, teacher, generated date), data pages (25 students × all days in month as columns with P/A/L/— cells, landscape A4), and summary page (per-student totals and attendance %)
- [ ] **RPT-03**: "—" appears in cells where no attendance session was recorded for that date
- [ ] **RPT-04**: Excel report contains: Sheet 1 "Attendance Data" (same structure as PDF data pages), Sheet 2 "Summary" (per-student totals), with conditional formatting (Green=Present, Red=Absent, Yellow=Leave)
- [ ] **RPT-05**: Backend cron job runs on 1st of each month (00:05 IST) and auto-generates reports for all classes with at least one attendance record in the prior month
- [ ] **RPT-06**: Generated files are stored in a private Supabase Storage bucket with 90-day expiry; download served via signed URLs
- [ ] **RPT-07**: File naming: `[SchoolName]_[ClassName]_Attendance_[YYYY-MM].pdf` / `.xlsx`
- [ ] **RPT-08**: Manual report generation completes within 30 seconds; teacher sees loading state and then download link
- [ ] **RPT-09**: Teacher receives in-app notification when auto-generated report is ready

### Infrastructure & Security (INFRA)

- [x] **INFRA-01**: All API endpoints except auth require valid JWT Bearer token; expired access tokens are silently refreshed using the stored refresh token
- [x] **INFRA-02**: Passwords stored as bcrypt hashes (cost factor 12); mobile numbers not logged in plaintext
- [x] **INFRA-03**: Supabase RLS enforced: teachers can only access data owned by their account (classes → students → attendance)
- [ ] **INFRA-04**: App shows "No internet connection" with retry button when offline; no data loss during network interruption
- [ ] **INFRA-05**: App cold start under 3 seconds; API read responses under 500ms; write operations under 1 second
- [ ] **INFRA-06**: App supports Android 6.0+ and iOS 13+; generated files compatible with standard viewers and MS Excel / Google Sheets

---

## v2 Requirements (Deferred)

### Multi-Teacher Accounts
- **TEAM-01**: School admin teacher can invite sub-teachers
- **TEAM-02**: Role-based access control (admin vs sub-teacher)
- **TEAM-03**: Sub-teacher can only access assigned classes

### Student Import
- **IMP-01**: Teacher can upload Excel sheet to bulk-import students
- **IMP-02**: Teacher can photograph printed register to OCR-import students

### Offline Sync
- **OFF-01**: Full offline-first with local SQLite database and background sync
- **OFF-02**: Attendance can be marked without internet; syncs when connection restored

### Push Notifications
- **PUSH-01**: Push notification when monthly report is auto-generated
- **PUSH-02**: Configurable notification preferences

---

## Out of Scope (Phase 1)

| Feature | Reason |
|---------|--------|
| Multi-teacher school accounts with roles | Phase 2 — foundation built but roles deferred |
| Student Excel/OCR import | Phase 2 — dummy seeding sufficient for Phase 1 testing |
| Offline-first SQLite sync | Phase 2 — graceful degradation only in Phase 1 |
| Push notifications | Phase 2 — in-app notifications only |
| Custom date-range exports (non-monthly) | Phase 3 |
| Holiday calendar / working day rules | Phase 3 |
| Subject-wise attendance | Phase 3 — one attendance record per class per day |
| Parent portal / student access | Phase 3+ |
| Fee management, marks, timetable | Phase 4+ |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-03 | Phase 1 — Database Foundation | Complete (01-02) |
| AUTH-01 | Phase 2 — Go Auth API | Pending |
| AUTH-02 | Phase 2 — Go Auth API | Pending |
| AUTH-03 | Phase 2 — Go Auth API | Pending |
| AUTH-04 | Phase 2 — Go Auth API | Pending |
| AUTH-05 | Phase 2 — Go Auth API | Pending |
| AUTH-06 | Phase 2 — Go Auth API | Pending |
| AUTH-07 | Phase 2 — Go Auth API | Pending |
| AUTH-11 | Phase 2 — Go Auth API | Pending |
| AUTH-12 | Phase 2 — Go Auth API | Pending |
| AUTH-13 | Phase 2 — Go Auth API | Pending |
| INFRA-01 | Phase 2 — Go Auth API | Complete |
| INFRA-02 | Phase 2 — Go Auth API | Complete |
| CLS-01 | Phase 3 — Go CRUD API | Pending |
| CLS-02 | Phase 3 — Go CRUD API | Pending |
| CLS-03 | Phase 3 — Go CRUD API | Pending |
| CLS-04 | Phase 3 — Go CRUD API | Pending |
| CLS-05 | Phase 3 — Go CRUD API | Pending |
| STU-01 | Phase 3 — Go CRUD API | Pending |
| STU-02 | Phase 3 — Go CRUD API | Pending |
| STU-03 | Phase 3 — Go CRUD API | Pending |
| STU-04 | Phase 3 — Go CRUD API | Pending |
| STU-05 | Phase 3 — Go CRUD API | Pending |
| STU-06 | Phase 3 — Go CRUD API | Pending |
| ATT-01 | Phase 3 — Go CRUD API | Pending |
| SUB-05 | Phase 3 — Go CRUD API | Pending |
| SUB-06 | Phase 3 — Go CRUD API | Pending |
| SUB-07 | Phase 3 — Go CRUD API | Pending |
| SUB-08 | Phase 3 — Go CRUD API | Pending |
| AUTH-08 | Phase 4 — Flutter Auth Shell | Pending |
| AUTH-09 | Phase 4 — Flutter Auth Shell | Pending |
| AUTH-10 | Phase 4 — Flutter Auth Shell | Pending |
| INFRA-04 | Phase 4 — Flutter Auth Shell | Pending |
| CLS-01 | Phase 5 — Flutter Class + Student Management | Pending |
| CLS-02 | Phase 5 — Flutter Class + Student Management | Pending |
| CLS-03 | Phase 5 — Flutter Class + Student Management | Pending |
| CLS-04 | Phase 5 — Flutter Class + Student Management | Pending |
| CLS-05 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-01 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-02 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-03 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-04 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-05 | Phase 5 — Flutter Class + Student Management | Pending |
| STU-06 | Phase 5 — Flutter Class + Student Management | Pending |
| ATT-01 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-02 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-03 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-04 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-05 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-06 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-07 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-08 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-09 | Phase 6 — Flutter Attendance Swipe | Pending |
| ATT-10 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-01 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-02 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-03 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-04 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-05 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-06 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-07 | Phase 6 — Flutter Attendance Swipe | Pending |
| SUB-08 | Phase 6 — Flutter Attendance Swipe | Pending |
| STAT-01 | Phase 6 — Flutter Attendance Swipe | Pending |
| STAT-02 | Phase 6 — Flutter Attendance Swipe | Pending |
| STAT-03 | Phase 6 — Flutter Attendance Swipe | Pending |
| RPT-01 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-02 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-03 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-04 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-05 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-06 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-07 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-08 | Phase 7 — Reports (Backend + Flutter) | Pending |
| RPT-09 | Phase 7 — Reports (Backend + Flutter) | Pending |
| INFRA-05 | Phase 8 — Integration, QA + Hardening | Pending |
| INFRA-06 | Phase 8 — Integration, QA + Hardening | Pending |

**Coverage:**
- v1 requirements: 56 total
- Mapped to phases: 56
- Unmapped: 0 ✓

**Notes on cross-phase requirements:**
- CLS-01 to CLS-05 and STU-01 to STU-06 each appear in Phase 3 (API) and Phase 5 (Flutter UI) — the API is the backend implementation, the Flutter screens are the delivery vehicle. Both phases must complete for the feature to be user-facing.
- ATT-01 and SUB-05 through SUB-08 are backed by Phase 3 API endpoints and delivered through Phase 6 Flutter screens.
- AUTH-08 through AUTH-10 are Flutter behaviors (silent refresh, network error routing) assigned to Phase 4; the underlying `/auth/refresh` endpoint is built in Phase 2.
- INFRA-01 spans Phase 2 (JWT middleware on Go) and Phase 4 (Dio interceptor on Flutter); assigned to Phase 2 as the authoritative implementation.

---

*Requirements defined: 2026-05-19*  
*Last updated: 2026-05-19 — INFRA-03 marked complete after 01-02 RLS policies migration*
