# School Management App — Attendance Module

## What This Is

A cross-platform mobile application (Flutter) for school teachers to manage their classes, students, and daily attendance. Phase 1 focuses entirely on the Attendance Management module — a Tinder-style swipe interface that replaces paper registers and auto-generates monthly PDF/Excel reports. The backend is a Go REST API backed by Supabase (PostgreSQL).

## Core Value

A teacher can open the app, swipe through their class in under 2 minutes, and have attendance recorded — with monthly reports generated automatically on the 1st of each month.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Teacher registration with mobile OTP (MSG91) verification
- [ ] Persistent JWT session (stay logged in forever, logout invalidates token)
- [ ] Class creation and management (unlimited classes per teacher)
- [ ] Student management within classes (add/edit/remove, dummy seed for testing)
- [ ] Tinder-style swipe attendance: Left=Present, Right=Absent, Up=Leave
- [ ] Tap-button alternative for Present/Absent/Leave (accessibility)
- [ ] Attendance summary with per-student status editing before submission
- [ ] Same-day attendance editing (locked at midnight)
- [ ] Statistics screen: today's counts + monthly average + students below 75%
- [ ] PDF report: cover page + data pages (25 students × all days) + summary page
- [ ] Excel report: Attendance Data sheet + Summary sheet with conditional formatting
- [ ] Manual report export (any month) + automatic export on 1st of each month
- [ ] Supabase Storage for generated files (90-day retention)

### Out of Scope

- Multi-teacher school accounts / role management — Phase 2
- Excel student import / OCR — Phase 2
- Offline-first SQLite sync — Phase 2
- Push notifications (in-app only in Phase 1) — Phase 2
- Parent portal, fee management, marks, timetable — Phase 3+
- Custom date-range exports — Phase 3
- Holiday calendar / working day rules — Phase 3
- Subject-wise attendance (one attendance per class per day only) — Phase 3

## Context

- **Academic year:** Indian academic calendar (June–May)
- **Language:** English only
- **Student seeding:** Auto-generated dummy students for testing (no import in Phase 1)
- **Attendance ownership:** Only the teacher who created the class can mark attendance
- **Edit window:** Same-day edits allowed; record locked at midnight
- **Export triggers:** Both automatic (1st of month cron) and manual (anytime)
- **OTP:** MSG91 integration; session_id stored, OTP not stored in own DB
- **Auth:** JWT access token (24h) + non-expiring refresh token in Flutter Secure Storage
- **Multiple devices:** Each login creates a new refresh token row; logout only affects current device
- **PDF pagination:** 25 students per page × all days as columns (not one page per day)
- **UI inspiration:** Tinder-card swipe pattern with smooth 60fps animations and colored overlays

## Constraints

- **Tech Stack**: Flutter (iOS + Android), Go (Golang) REST API, Supabase (PostgreSQL + Storage), MSG91 OTP, JWT auth — locked
- **Performance**: App cold start < 3s, swipe animations at 60fps, API responses < 500ms reads / < 1s writes, PDF/Excel generation < 30s
- **Security**: bcrypt (cost 12), Supabase RLS enforced, OTP sessions single-use 10min TTL, mobile numbers not logged in plaintext
- **Compatibility**: Android 6.0+, iOS 13+; PDF viewable in standard viewers; Excel compatible with MS Excel and Google Sheets
- **Data**: Attendance records retained indefinitely; generated files expire after 90 days

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Left=Present, Right=Absent, Up=Leave | Locked in PRD — intuitive for most users | — Pending |
| Non-expiring refresh token | Users stay logged in forever; explicit logout only | — Pending |
| Server-side PDF/Excel generation | Consistent formatting, no device dependency | — Pending |
| Supabase as temporary DB | Fast setup for Phase 1; may migrate later | — Pending |
| One student belongs to one class | Simplifies Phase 1 data model | — Pending |
| No partial accounts | Registration only completes after OTP | — Pending |
| Indian academic year (June–May) | Target market is Indian schools | — Pending |

---
*Last updated: 2026-05-19 after initialization from PRD v1.0*
