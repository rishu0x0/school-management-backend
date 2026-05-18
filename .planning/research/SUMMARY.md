# Research Summary — School Management Attendance App

**Synthesized from:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md  
**Date:** 2026-05-19  
**Overall Confidence:** MEDIUM

---

## Executive Summary

A teacher-facing mobile attendance app on a locked Flutter + Go + Supabase stack, targeting the Indian school market. The core value prop is a Tinder-style swipe interface reducing class attendance from a 3–5 minute paper exercise to under 2 minutes. All patterns — swipe card UX, JWT persistent sessions, server-side PDF/Excel — are mature and well-documented.

**Recommended implementation:**
- **Flutter:** feature-first structure, Riverpod 2.x, go_router, Dio with interceptor-based JWT refresh queue
- **Go:** single-process monolith, Chi v5, pgx v5 + sqlc, maroto v2 (PDF), excelize v2 (Excel)
- **Supabase:** direct pgx connection (not PostgREST REST layer), service role key in Go, RLS as defense-in-depth

---

## Stack (Key Picks)

| Layer | Recommended | Avoid |
|-------|-------------|-------|
| Flutter state | Riverpod 2.x with codegen | GetX, Provider (maintenance mode) |
| Flutter routing | go_router (official) | Navigator 1.0 manual push |
| Flutter HTTP | Dio + interceptor queue | http package (no interceptors) |
| Flutter secure storage | flutter_secure_storage 9.x | SharedPreferences for tokens |
| Go router | Chi v5 | Fiber (non-stdlib compat), GORM |
| Go DB | pgx v5 + sqlc | supabase-go as DB driver |
| Go PDF | maroto v2 | gofpdf (unmaintained) |
| Go Excel | excelize v2.8+ | — (no real alternative) |
| Go JWT | golang-jwt/jwt v5 | PASETO (overkill here) |

---

## Features (Table Stakes vs Differentiators)

### Table Stakes (must work or users leave)
- Instant swipe response — card tracks finger with zero perceived lag
- All 3 statuses: Present, Absent, Leave
- Clear undo for last swipe
- Explicit success/failure feedback on submission
- Monthly PDF report matching physical register format (roll no + P/A/L cells + signature line)
- Students below 75% highlighted — named list, not just a percentage

### Differentiators for Phase 1
- < 2 minute full class attendance (speed advantage over paper)
- Auto-export on 1st of month (zero-effort reports for teachers)
- Dummy student seeding (removes friction from empty-state onboarding)
- Tap-button alternative (accessibility + Android gesture nav safety net)

### Anti-Features (avoid)
- Silent submission failure (must show explicit retry UI)
- Attendance screen that auto-advances before teacher sees confirm animation
- Complex onboarding requiring class setup before value is demonstrated

---

## Architecture (Key Decisions)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Flutter structure | Feature-first | Auth, classes, attendance, reports as top-level features |
| Go structure | Single-process monolith | Shared DB pool; cron as goroutine via robfig/cron |
| Supabase auth | Go uses service role key; RLS as defense-in-depth | Simpler than forwarding JWT to PostgREST |
| Report file storage | Private Supabase Storage bucket | Files contain student PII; serve via signed URLs |
| Midnight lock | Go service layer primary + PG trigger defense-in-depth | Fast error, good messages at API layer |
| Cron timing | `35 18 1 * *` UTC = 00:05 IST | UTC server; cron expression must be IST-aware |

---

## Pitfalls (Critical)

| # | Pitfall | Prevention | Phase |
|---|---------|-----------|-------|
| 1 | **MSG91 DLT registration** takes 3–14 days — blocks all OTP production testing | Start registration before Phase 1 coding | Pre-phase 0 |
| 2 | **Non-expiring refresh tokens** = permanent access after device compromise | Add `last_used_at`, `device_hint`, exclude from Android backup | Phase 2 (Auth) |
| 3 | **Midnight lock uses UTC, not IST** — edit access lost at 18:30 IST | `time.LoadLocation("Asia/Kolkata")` in shared `pkg/timezone` constant | Phase 3 (Attendance) |
| 4 | **Swipe-Up for Leave intercepted by Android 10+ gesture nav** | Ensure tap-button alternative is prominently visible on Android by default | Phase 6 (Swipe) |
| 5 | **Monthly cron bulk PDF generation OOM** — 300+ concurrent builds | Bounded worker pool, max 10 concurrent generations | Phase 7 (Reports) |
| 6 | **Supabase Storage has no native TTL** — `expires_at` column alone does nothing | Add Go cron cleanup job for 90-day report expiry | Phase 7 (Reports) |
| 7 | **JWT token refresh race condition** — parallel requests get 401, trigger multiple refresh calls | Dio `QueuedInterceptorsWrapper` or mutex-locked refresh singleton | Phase 4 (Flutter auth) |

---

## Suggested Build Order (8 Phases)

1. **Database Foundation** — Schema + RLS (blocks everything else)
2. **Go Auth API** — JWT auth, MSG91 OTP, refresh token table
3. **Go CRUD API** — Classes, students, attendance endpoints + IST midnight lock
4. **Flutter Auth Shell** — Routing, auth guard, login/register screens (can parallel Phase 3)
5. **Flutter Class + Student Management** — Empty state, seed button, CRUD screens
6. **Flutter Attendance Swipe** — Core feature: swipe cards, summary, submission, statistics
7. **Reports (Backend + Flutter)** — PDF/Excel generation, cron, manual export, Flutter download UI
8. **Integration + QA + Hardening** — IST timezone integration test, RLS multi-teacher test, Excel compat, App Store build

---

## Open Flags for Phase Planning

- **Verify before Phase 2:** MSG91 DLT template text against current MSG91 docs
- **Verify before Phase 3:** Supabase plan connection limits for pgxpool `MaxConns`
- **Spike in Phase 6:** Evaluate `flutter_card_swiper v7` before committing to fully custom swipe widget (1-day spike)
- **Prototype in Phase 7:** PDF 31-column layout on A4 landscape before full implementation; test Excel output in MS Excel (not just Google Sheets)
- **Validate before Phase 7:** Indian PDF report format with a real school admin (column order, signature line placement)

---

*Research committed: fd091f3 · 2026-05-19*
