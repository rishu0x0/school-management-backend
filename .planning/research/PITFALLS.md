# Domain Pitfalls — School Attendance App

**Domain:** Flutter + Go + Supabase mobile attendance app
**Researched:** 2026-05-19
**Research mode:** Training knowledge (WebSearch/Brave denied in environment)
**Overall confidence:** MEDIUM — all findings from training data through mid-2025; no live verification possible. Flag any claim against current library changelogs before acting.

---

## How to Read This Document

Each pitfall entry includes:
- **What goes wrong** — the exact failure mode
- **Why it happens** — root cause
- **Consequences** — what breaks
- **Warning signs** — how to detect early
- **Prevention** — concrete steps
- **Phase** — which build phase should address this

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or security incidents.

---

### CRIT-1: Non-Expiring Refresh Token Without Rotation or Compromise Detection

**What goes wrong:** A refresh token that never expires and is never rotated means a stolen token grants permanent access with no automatic remediation path.

**Why it happens:** The PRD correctly models "stay logged in forever" but the security design only handles the happy path (explicit logout). It does not account for token theft via device compromise, backup extraction (Android ADB backup on unencrypted devices), or a future app vulnerability.

**Consequences:**
- Attacker with stolen token has permanent teacher access to all class and student data.
- No audit trail to detect abuse.
- No expiry = no automatic clean-up of stale device sessions in the DB, causing `refresh_tokens` table bloat over time.

**Warning signs:**
- `refresh_tokens` table growing unboundedly months after launch.
- No `last_used_at` column → no way to detect dormant vs active tokens.
- Refresh endpoint accepts a token without checking whether the same token was just used from a different IP (impossible to detect without metadata).

**Prevention:**
1. Add `last_used_at TIMESTAMPTZ` and `device_hint TEXT` (user-agent/platform) columns to `refresh_tokens`.
2. Implement soft rotation: on each `/auth/refresh` call, optionally issue a new token and mark the old one retired after a grace window (e.g., 30 seconds to handle network retries). Full rotation is ideal but the PRD's multi-device model makes this complex — at minimum record `last_used_at`.
3. Add a background Go cron that deletes tokens unused for >6 months (dead device sessions).
4. Never log the raw refresh token value — only its hash. The DB schema already says `token_hash`; ensure no middleware logs the raw request body for `/auth/refresh`.
5. Consider a "force logout all devices" admin endpoint for teacher-initiated security reset.

**Phase:** Auth phase (Phase 1). The `refresh_tokens` table schema must include `last_used_at` and `device_hint` from day 1. Retrofitting metadata columns is painful after data exists.

---

### CRIT-2: Timezone Bug in Midnight Attendance Lock

**What goes wrong:** The backend stores `attendance_sessions.date` as a `DATE` type and sets `is_locked = true` at midnight — but midnight in which timezone? If the Go server or Supabase PostgreSQL is running in UTC and the teacher is in IST (UTC+5:30), midnight UTC is 5:30 AM IST. Teachers would lose edit access at 5:30 AM IST instead of midnight IST.

**Why it happens:** Developers default to UTC everywhere (correct for storage) but forget to interpret the "midnight" business rule in the teacher's local timezone.

**Consequences:**
- Teachers lose edit access 5.5 hours early (locks at 18:30 UTC = 00:00 IST... wait: midnight IST = 18:30 UTC previous day). Teachers cannot edit attendance after 6:30 PM IST, even though the school day ends later.
- Alternatively, if the lock check uses wall clock of the server (UTC), teachers in IST get until 05:30 IST of the next morning, which is also wrong.
- Monthly cron job on the 1st fires at 00:00 UTC = 05:30 IST on the 1st, which means it processes May data on June 1st 05:30 IST — harmless but if ever combined with a "lock past months" rule, creates edge cases.

**Warning signs:**
- Lock check written as `time.Now().After(endOfDay)` in Go without explicit timezone conversion.
- PostgreSQL cron or pg_cron using `NOW()` without `AT TIME ZONE 'Asia/Kolkata'`.
- No test written for the 18:30–00:00 UTC window.

**Prevention:**
1. All business-rule time comparisons must use IST: `time.LoadLocation("Asia/Kolkata")` in Go.
2. The `date` field in `attendance_sessions` is a `DATE` — construct end-of-day as `date + 1 day at 00:00 IST` then convert to UTC for comparison.
3. Store `locked_at TIMESTAMPTZ` explicitly (the actual UTC instant of lock) rather than computing it on every check.
4. Write an integration test: create a session dated today, simulate time at 23:55 IST, confirm editable; simulate 00:05 IST next day, confirm locked.
5. The cron job expression `0 0 1 * *` fires at 00:00 server time — document the server timezone and verify 00:00 IST = 18:30 UTC of previous day; set cron to `30 18 * * 1` if server is UTC, or configure the Go cron with explicit IST location.

**Phase:** Attendance submission phase and cron phase. Add the IST timezone constant to a shared `pkg/timezone` package from day 1.

---

### CRIT-3: Supabase RLS Policies That Allow Lateral Data Access

**What goes wrong:** RLS is enabled but policies are written incorrectly, allowing a teacher to read another teacher's classes, students, or attendance records via crafted API calls that bypass the Go backend and hit Supabase directly.

**Why it happens:** Two common mistakes:
- (a) Policy references `auth.uid()` which is the Supabase Auth UID — but this project uses custom JWT auth through Go, not Supabase Auth. If Go uses the Supabase service role key for all DB operations, RLS is bypassed entirely.
- (b) Policies written at the wrong table level: protecting `classes` but forgetting `students` and `attendance_records` inherit no protection by default.

**Consequences:**
- Any user who discovers the Supabase project URL and anon key (easily extracted from a decompiled Flutter app or network sniff) can directly query the PostgREST API and read all teachers' student and attendance data.
- Even without deliberate attack: a misconfigured policy silently returns data from the wrong teacher, causing data corruption in the app without errors.

**Warning signs:**
- Go backend initialized with `supabase.NewClient(url, serviceRoleKey, ...)` and that same client used for all queries.
- No RLS policy test suite.
- Supabase dashboard shows "RLS enabled" but no policies listed for `students`, `attendance_records`, or `attendance_sessions`.

**Prevention:**
1. **Architecture decision required at Phase 1:** Either (a) use Supabase Auth for teacher identity (Supabase manages JWTs) and write RLS policies using `auth.uid()`, or (b) use Go's own JWT and **the service role key only in Go backend** with Go enforcing all ownership checks — in this case RLS provides defense-in-depth but not primary enforcement.
2. If using option (b) — which matches the PRD — write RLS policies that use a custom JWT claim: set `app.jwt_secret` in Supabase and pass the teacher's JWT from Go so RLS can read `auth.jwt() -> 'teacher_id'`. This requires the Go backend to forward the teacher JWT to Supabase rather than using service role for user-context queries.
3. Write policies for ALL tables: `teachers`, `classes`, `students`, `attendance_sessions`, `attendance_records`, `generated_reports`. Missing even one table is a data leak.
4. Never expose the service role key to the Flutter app — only the anon key (which is fine to be public if RLS is correct).
5. Add a Supabase RLS test: connect as a second teacher, attempt to read first teacher's classes — expect empty result.

**Phase:** Database/infrastructure setup phase. RLS policies must be written and tested before any API endpoint is built on top of the schema.

---

### CRIT-4: Flutter Secure Storage Not Actually Secure on All Android Configurations

**What goes wrong:** `flutter_secure_storage` on Android uses the Android Keystore system on API 23+ (Android 6.0+) which is the minimum target. However, on older Android 6/7 devices, the Keystore implementation has known weaknesses, and on rooted devices the encrypted storage can be extracted. More practically: if the user enables ADB backup and the app does not set `android:allowBackup="false"`, the Keystore-encrypted data can be exfiltrated via backup.

**Why it happens:** Default Flutter app template sets `android:allowBackup="true"`. Developers assume "secure storage = safe" without verifying backup exclusion.

**Consequences:**
- Refresh token extracted from backup → permanent account access on any device.
- Non-expiring refresh token (see CRIT-1) compounds this: there is no TTL safety net.

**Warning signs:**
- `AndroidManifest.xml` has `android:allowBackup="true"` (default).
- No `backup_rules.xml` excluding the secure storage keystore entries.
- No test on a rooted emulator.

**Prevention:**
1. Set `android:allowBackup="false"` in `AndroidManifest.xml`, or use Android 12+ `android:dataExtractionRules` to explicitly exclude secure storage keys.
2. On iOS, `flutter_secure_storage` uses the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` by default — verify this attribute is not changed to a weaker one.
3. Document this limitation: Phase 1 is acceptable with these controls; Phase 2 (if handling more sensitive school data) should add certificate pinning and biometric unlock for app access.

**Phase:** Auth phase (Phase 1). One-line `AndroidManifest.xml` change, no architecture impact.

---

## High Severity Pitfalls

Issues that cause significant bugs, performance problems, or data quality issues.

---

### HIGH-1: Flutter Swipe Card Jank — Widget Rebuilds During Animation

**What goes wrong:** The Tinder-card swipe animation runs at < 60fps because the gesture callback triggers `setState()` on a parent widget that rebuilds the entire screen tree (card stack + progress indicator + button row) on every pointer move event.

**Why it happens:** Developers put `GestureDetector` callbacks inside `StatefulWidget.build()` and call `setState()` to update the drag offset, causing O(pointer-events-per-frame) full subtree rebuilds.

**Consequences:**
- Jank on mid-range Android phones (Redmi, Realme — the dominant devices in the Indian school teacher demographic).
- Frame drops visible as stuttering card drag.
- Battery drain during class of 40+ students.

**Warning signs:**
- Flutter DevTools timeline shows "Build" frames > 16ms during drag.
- `setState()` called inside `onPanUpdate`.
- The card stack widget is an ancestor of the progress indicator widget.

**Prevention:**
1. Use `AnimationController` + `Tween` with `addListener(() => setState(()))` scoped to a small `AnimatedBuilder` that wraps only the card — not the entire screen.
2. Better: use a dedicated package like `appinio_swiper` or `flutter_card_swiper` which handle the animation internals correctly, rather than building raw gesture detection from scratch.
3. If building from scratch: separate the card layer from the UI chrome using a `RepaintBoundary`. The card's drag offset updates only repaint the card layer.
4. Pre-build the "next card" widget in the background so the card behind the current one is already rendered.
5. Image loading: use `cached_network_image` for student photos — lazy-loading images during the swipe transition causes layout jank. In Phase 1 with dummy students and no real photos this is less critical, but establish the pattern.

**Phase:** Attendance swipe screen phase.

---

### HIGH-2: Swipe-Up Gesture Conflict with System Navigation

**What goes wrong:** On Android with gesture navigation enabled (Android 10+, which is the default for newer devices), a swipe-up gesture from the bottom of the screen triggers the Android home gesture, not the "Leave" attendance action.

**Why it happens:** The Android gesture navigation bar occupies the bottom ~40–60dp of the screen. `GestureDetector` in Flutter competes with the system gesture zones. The system gesture takes priority.

**Consequences:**
- Teachers accidentally navigate home while trying to mark Leave.
- If students are near the bottom of the swipe stack, the gesture becomes unusable.
- This is a UX blocker for the "Swipe Up = Leave" core interaction.

**Warning signs:**
- Testing only on iOS or on Android with 3-button navigation enabled.
- Not testing on Android 10+ with system gesture navigation.
- No insets handling in the layout.

**Prevention:**
1. Use `EdgeInsets` from `MediaQuery.of(context).systemGestureInsets` and offset the card's swipe-up detection zone above the system gesture area.
2. Consider placing the swipe-up trigger zone in the middle/upper portion of the card, not the bottom edge.
3. Alternatively: given that "Swipe Up = Leave" is a less common action than Present/Absent, the tap button alternative (already in the PRD) is the safety net. Make the tap buttons prominent enough that teachers naturally use them on Android.
4. Test on a physical Android 10+ device with gesture navigation before the swipe screen is considered done.
5. Add gesture hint UI that shows the "up" arrow starting from mid-card, visually guiding users away from the system gesture zone.

**Phase:** Attendance swipe screen phase. Must test on Android gesture navigation before feature sign-off.

---

### HIGH-3: JWT Race Condition on Parallel Requests After Token Expiry

**What goes wrong:** On app launch, the Flutter app makes multiple API calls simultaneously (e.g., fetch classes, fetch today's stats). If the access token is expired, all calls fail with 401. Multiple concurrent "refresh token" requests fire simultaneously — the Go backend receives 3–5 simultaneous refresh calls with the same refresh token, issues 3–5 new access tokens, and if it uses rotation (see CRIT-1), only one rotation succeeds and the rest fail, causing spurious 401s and a confusing logout.

**Why it happens:** No request queuing or "refresh in progress" mutex in the Flutter HTTP client.

**Consequences:**
- User sees a flash of "session expired" or is redirected to Login on a valid session.
- If not using rotation: multiple valid access tokens issued from one refresh call — benign but wasteful.
- If using rotation: one of the concurrent refresh calls arrives after the first has already rotated the token, sees the old (now-revoked) token, and incorrectly identifies the session as compromised.

**Warning signs:**
- HTTP client (Dio or http package) initialized without an interceptor queue for 401s.
- Multiple API calls fired in `initState()` with no coordination.
- No "isRefreshing" flag in the auth state manager.

**Prevention:**
1. Use `Dio` with a `QueuedInterceptorsWrapper` (or equivalent) that queues all requests when a token refresh is in progress. Only one refresh call fires; all queued requests retry with the new token.
2. Implement in the Go backend: make `/auth/refresh` idempotent for the same token within a short window (e.g., 5 seconds) — return the same new access token rather than refusing or issuing another rotation. A Redis lock or DB-level "last_refreshed_at" check achieves this.
3. The Flutter auth service should have a single `Future<String> getValidAccessToken()` method that all API calls go through, with a `Completer` to coalesce concurrent refresh requests.

**Phase:** Auth and API client phase.

---

### HIGH-4: Go PDF Generation — Memory Spike for Large Monthly Reports

**What goes wrong:** The Go PDF library builds the entire document in memory before writing it to Supabase Storage. For a class of 50 students × 31 days, this is manageable in isolation — but the cron job on the 1st of the month generates reports for ALL classes simultaneously. If 100 teachers each have 3 classes, 300 concurrent report generations each holding ~5–20MB in memory causes an OOM (out of memory) kill on a small VPS or container.

**Why it happens:** Cron job fires once and fans out all report generations as goroutines without concurrency limit.

**Consequences:**
- Server crashes on the 1st of each month.
- All auto-reports fail; teachers receive no report.
- Manual report generation also fails if it shares the same generation path during the cron window.

**Warning signs:**
- Cron job implementation uses `go func()` in a loop with no semaphore.
- No memory profiling done at 100+ class scale.
- PDF library (`fpdf`, `gofpdf`, `maroto`, `unipdf`) used in default mode without checking streaming options.

**Prevention:**
1. Use a worker pool with a bounded channel semaphore: `sem := make(chan struct{}, 10)` — process at most 10 reports concurrently.
2. For the cron job, spread generation using a job queue: push all generation tasks to a queue at midnight, process throughout the 1st (teachers don't need the report at 00:00:01).
3. Prefer `gofpdf` or `maroto` (both are streaming-capable) over libraries that require full DOM-style construction.
4. After generation, stream directly to Supabase Storage rather than buffering the file bytes in a Go `[]byte` variable.
5. Add a `/health/memory` metric endpoint; alert if heap > 500MB during cron window.

**Phase:** Report generation phase AND cron phase.

---

### HIGH-5: Go Excel Generation — Conditional Formatting Compatibility

**What goes wrong:** The Go Excel library (`excelize`) generates `.xlsx` files with conditional formatting (green/red/yellow cells per PRD). The file opens correctly in Google Sheets but renders incorrectly in Microsoft Excel because the conditional format rule syntax differs subtly between the two, and `excelize` may generate rules that Google Sheets tolerates but Excel rejects.

**Why it happens:** `excelize` is primarily validated against Google Sheets behavior by most open-source contributors. Edge cases in conditional formatting (especially when combining cell value rules with color scales) break Excel compatibility.

**Consequences:**
- Excel file opens but shows no conditional formatting in MS Excel.
- PRD acceptance criterion explicitly requires MS Excel compatibility.
- Indian schools often use MS Excel (Office via school licenses or pirated copies).

**Warning signs:**
- Generated `.xlsx` validated only in Google Sheets.
- Not tested in MS Excel 2016, 2019, or Office 365.
- `excelize` version used is < 2.7 (older versions had known compat bugs).

**Prevention:**
1. Use `excelize` v2.8+ (latest stable as of mid-2025) which has improved OOXML compliance.
2. Write a test fixture: generate a sample 3-student, 5-day report, open in both Google Sheets and MS Excel (or use the Excel online API if CI is needed), verify green/red/yellow cells appear.
3. Use simple conditional formatting rules (value == "P" → green background) rather than formula-based rules, which have higher compat risk.
4. As a fallback: apply cell background colors as explicit fill styles (not conditional formatting rules) for the data cells. Conditional formatting remains for the Summary sheet. This guarantees visual correctness in both apps.

**Phase:** Report generation phase.

---

### HIGH-6: MSG91 DLT Registration Blocking OTP Delivery

**What goes wrong:** In India, all commercial SMS (including OTP) must use TRAI's Distributed Ledger Technology (DLT) platform. MSG91 requires a registered sender ID and a pre-approved message template before OTPs can be delivered. Without DLT registration, MSG91 will accept the API call (no error) but the telecom operators will silently drop the SMS.

**Why it happens:** Developers test with MSG91 sandbox (which bypasses DLT checks) and only discover the issue in production when real users cannot receive OTPs.

**Consequences:**
- OTP SMS sent silently fails to deliver.
- No error returned from MSG91 API — the Go backend sees "success" and the teacher's registration or login is permanently blocked.
- Registration flow broken for all users in production.

**Warning signs:**
- Using MSG91 sandbox/test mode for all development testing.
- No DLT entity registration initiated before development starts.
- No fallback OTP delivery channel (e.g., voice OTP).
- MSG91 dashboard shows "Delivered: 0" for real number tests.

**Prevention:**
1. **Start DLT registration immediately** — it takes 3–7 business days minimum, sometimes 2+ weeks. It must happen before development of the OTP flow is complete.
2. Register on any DLT platform (Airtel, Jio, Vi, BSNL — any one is sufficient; MSG91 auto-propagates). Required: company PAN, GST certificate (or personal PAN for individuals), registered mobile.
3. Create the OTP message template in MSG91 console with the exact text that will be sent, including the `{#var#}` placeholder for the OTP code. Template must be pre-approved by the telecom.
4. Use template ID (not template text) in the MSG91 API call. Using the wrong template ID causes silent drops.
5. Enable MSG91's voice OTP fallback for when SMS fails — Indian telecom network is unreliable, especially in rural school areas.
6. Log MSG91's `request_id` on every send-OTP call for debugging delivery failures.

**Phase:** Auth/OTP phase. DLT registration must be a Phase 0 prerequisite before auth development begins.

---

### HIGH-7: Supabase "Temporary" Label Leading to Deferred RLS and Sloppy Schema

**What goes wrong:** The PRD says Supabase is "temporary." This creates an organizational mindset of "we'll fix it properly when we migrate." In practice, Phase 1 ships to production, the migration never happens, and the "temporary" setup — with incomplete RLS, no index planning, and the service role key used everywhere — becomes permanent.

**Why it happens:** "Temporary" technology framing reduces perceived investment in doing it right. Teams skip security hardening, index optimization, and proper connection pooling because "we're going to migrate anyway."

**Consequences:**
- RLS gaps (see CRIT-3) go unfixed in production.
- Missing indexes on `attendance_records(session_id)`, `classes(teacher_id)`, `attendance_sessions(class_id, date)` cause slow queries as data grows.
- If actual migration to self-hosted PostgreSQL is ever attempted, the lack of proper schema documentation makes it painful.

**Warning signs:**
- Schema migrations tracked in ad-hoc SQL files rather than a migration tool (Flyway, golang-migrate).
- No index documentation.
- RLS policies not in version control.

**Prevention:**
1. Treat it as permanent from day 1. "Temporary" only means the hosting provider may change, not that the schema or security can be sloppy.
2. Use `golang-migrate` for all schema changes — every `CREATE TABLE`, `ALTER TABLE`, `CREATE INDEX`, and RLS policy in versioned migration files.
3. Required indexes from day 1: `CREATE INDEX ON classes(teacher_id)`, `CREATE INDEX ON attendance_sessions(class_id, date)`, `CREATE INDEX ON attendance_records(session_id)`, `CREATE INDEX ON refresh_tokens(token_hash)`.
4. Keep all RLS policies in migration files, not just applied via Supabase dashboard.

**Phase:** Database setup phase (Phase 1, before any tables are created).

---

## Moderate Pitfalls

Issues that cause bugs or UX problems but are fixable without rewrites.

---

### MOD-1: Flutter State Management During Attendance Submission — Double Submit

**What goes wrong:** Teacher taps "Submit Attendance," the button triggers a network request. The request takes 800ms (within the <1s SLA). Teacher taps again because they see no visual feedback. Two POST requests reach the Go backend, the first creates the session, the second fails with a duplicate key error (UNIQUE constraint on `class_id, date`). The second failure triggers an error dialog even though the first submission succeeded.

**Why it happens:** No loading state disables the submit button during the request.

**Consequences:**
- False error shown to teacher on a successful submission.
- Confusing UX — teacher may re-enter the swipe screen and resubmit, creating an edit instead of a new submission.

**Warning signs:**
- Submit button not wrapped in a `BlocConsumer`/`Consumer`/`ValueListenableBuilder` that disables it when state is `loading`.
- Network request fired directly in `onPressed` with no guard.

**Prevention:**
1. Implement a simple state machine for the submission flow: `idle → loading → success/error`. The submit button is disabled (and shows a `CircularProgressIndicator`) in `loading` state.
2. On the Go backend: make the POST attendance endpoint idempotent — if a session for `(class_id, date)` already exists and the request comes from the same teacher, return the existing session rather than a 409 error.
3. Use `Riverpod` or `BLoC` — not raw `setState()` — for this state machine. The swipe screen accumulates significant local state (all student marks); managing that plus submission state in a single `StatefulWidget` becomes unmanageable.

**Phase:** Attendance submission screen phase.

---

### MOD-2: Flutter Offline State — Swipe Data Lost on Network Error at Submit

**What goes wrong:** Teacher swipes through all 40 students (2 minutes of work), taps Submit, network is unavailable (Indian school networks are often intermittent via mobile data), submission fails, and the swipe data is lost — teacher must start over.

**Why it happens:** The PRD specifies "Phase 1 — basic offline: show retry button." But if the swipe data is held only in widget state and the user navigates away from the error screen, the state is garbage collected.

**Consequences:**
- Teacher must re-swipe all 40 students. Severe usability regression.
- Likely to cause negative feedback during initial teacher onboarding.

**Warning signs:**
- Attendance session state stored in a `StatefulWidget` rather than in a state management solution that survives navigation.
- No persistence layer for in-progress sessions.

**Prevention:**
1. Store the accumulated swipe results in an app-level state provider (Riverpod `StateNotifier`, BLoC, or Provider) — not in widget state. This survives navigation events.
2. On submission failure, show an in-page retry that does not clear the state. The user stays on the submission screen with their marks intact.
3. The PRD's "retry button" behavior is correct — implement it such that the button re-attempts the POST with the preserved state, not a navigation-back that destroys it.
4. Phase 2 will add full offline SQLite — but Phase 1 must at least survive network errors without data loss.

**Phase:** Attendance submission screen phase.

---

### MOD-3: MSG91 Template Variable Mismatch in Production

**What goes wrong:** The MSG91 template is registered with a specific text (e.g., "Your OTP for School Attendance App is {#var#}. Valid for 10 minutes."). The Go backend sends the OTP using a different template ID or constructs the message text slightly differently. MSG91 rejects or mismatches the variable substitution.

**Why it happens:** MSG91's API requires the `template_id` to match exactly the registered template. Any typo in the backend config causes substitution to fail — the teacher receives "Your OTP for School Attendance App is {#var#}" literally.

**Consequences:**
- Teacher cannot read the OTP.
- Registration blocked.
- Hard to diagnose (MSG91 returns "success" even with literal placeholder delivery on some configurations).

**Prevention:**
1. Store `MSG91_TEMPLATE_ID` in environment config (not hardcoded).
2. Write an integration test against MSG91 sandbox that verifies the rendered message text (not just HTTP 200).
3. After DLT template approval, immediately test with a real phone number before any user-facing rollout.

**Phase:** Auth/OTP phase.

---

### MOD-4: Supabase Storage 90-Day Expiry — No Automated Cleanup

**What goes wrong:** The PRD specifies generated files expire after 90 days. Supabase Storage does not natively support TTL-based auto-deletion (as of mid-2025). Without an explicit cleanup mechanism, files accumulate indefinitely, increasing storage costs.

**Why it happens:** Developers assume "cloud storage has lifecycle policies" (S3 does; Supabase Storage bucket policies are more limited).

**Consequences:**
- Storage costs grow unboundedly.
- `generated_reports.expires_at` column exists in the schema but nothing acts on it.

**Warning signs:**
- No cron job or scheduled function for file cleanup.
- `expires_at` column populated but never queried.

**Prevention:**
1. Add a Go cron job (separate from the report generation cron) that runs daily: `SELECT file_url FROM generated_reports WHERE expires_at < NOW()`, deletes each file from Supabase Storage via the Storage API, then deletes the DB row.
2. Alternatively: use a Supabase Edge Function triggered by pg_cron to handle cleanup within the Supabase ecosystem. Either approach works; pick based on operational simplicity.
3. Test the cleanup job with synthetic expired records before deploying the report generation feature.

**Phase:** Report generation/storage phase.

---

### MOD-5: Go Cron Job Firing Twice — No Distributed Lock

**What goes wrong:** The Go cron job runs monthly report generation on the 1st. If the Go server is ever restarted during the cron window (deployment, crash recovery), the cron job fires again and generates duplicate reports — teacher sees two download links for the same month.

**Why it happens:** In-process cron schedulers (`robfig/cron`) have no distributed state. On restart, they re-fire any schedule that was missed or that falls within the start window.

**Consequences:**
- Duplicate reports in Supabase Storage (cost waste).
- Duplicate rows in `generated_reports` table unless there's a UNIQUE constraint.
- If the generation includes expensive queries, duplicate runs double server load.

**Prevention:**
1. Add `UNIQUE(class_id, month, file_type)` constraint on `generated_reports` — this makes duplicate generation fail gracefully at the DB level.
2. Before generating: `SELECT id FROM generated_reports WHERE class_id = $1 AND month = $2 AND file_type = $3` — skip if already generated.
3. For production robustness: use a DB-backed distributed lock (try-insert a `cron_locks` row with a UNIQUE constraint; if insert fails, another instance is running).

**Phase:** Cron/background jobs phase.

---

### MOD-6: Indian Academic Year Boundary in Monthly Stats

**What goes wrong:** The Statistics screen shows "monthly overview (current month)" and the report system uses calendar months. The Indian academic year runs June–May. Statistics queries that use `EXTRACT(YEAR FROM date)` to group by year will group June 2026 data with January 2026 data as "2026" — but for academic reporting they belong to different academic years (2025–26 vs 2026–27).

**Why it happens:** Developers default to calendar year. The academic year boundary is a Phase 1 concern even though custom date-range exports are deferred.

**Consequences:**
- "Monthly average attendance" calculation in Statistics screen is correct (uses current calendar month).
- But the "75% threshold" calculation — if ever computed year-to-date — could silently cross academic year boundaries.
- More critically: the `generated_reports.month` stored as first-of-month `DATE` is fine for Phase 1. But any future "annual report" feature that uses `EXTRACT(YEAR FROM month)` will group incorrectly.

**Prevention:**
1. For Phase 1: document explicitly in code that all stats use calendar months, not academic years. Add a `// NOTE: calendar month, not academic year` comment at the stats query.
2. Add a `academic_year` computed column or helper function: `CASE WHEN EXTRACT(MONTH FROM date) >= 6 THEN EXTRACT(YEAR FROM date) || '-' || (EXTRACT(YEAR FROM date) + 1) ELSE (EXTRACT(YEAR FROM date) - 1) || '-' || EXTRACT(YEAR FROM date) END`.
3. Do not expose "year" granularity in Phase 1 API responses — return only month-level data. This defers the academic year complexity to Phase 3 when custom date ranges are added.

**Phase:** Statistics API phase.

---

## Minor Pitfalls

Small issues, easily fixed if caught early, costly if discovered late.

---

### MIN-1: Flutter `flutter_secure_storage` Key Name Collisions on Re-install

**What goes wrong:** On Android, `flutter_secure_storage` persists data in the Android Keystore even after app uninstall (on some Android versions). If the teacher reinstalls the app, the old refresh token key survives in the Keystore, causing unexpected auto-login behavior or key decryption errors if the encryption parameters changed between app versions.

**Prevention:** On app first-launch detection (e.g., check for a `first_run` flag in `SharedPreferences`), clear all Secure Storage keys. This handles the "fresh install but stale Keystore" edge case.

**Phase:** Auth phase.

---

### MIN-2: Roll Number Ordering vs. Natural Sort

**What goes wrong:** The PRD specifies students ordered by roll number ascending. If roll numbers are stored as `TEXT` (e.g., "1", "2", "10"), sorting alphabetically gives "1", "10", "2" — wrong order.

**Prevention:** The schema correctly defines `roll_number INTEGER` — keep it as integer and never cast to text in ORDER BY clauses. The API response must also return integers, not strings, for roll numbers.

**Phase:** Student management phase.

---

### MIN-3: PDF Report "–" vs Null for Non-School Days

**What goes wrong:** The PRD says show "—" for days with no recorded attendance session. The Go backend must distinguish between "no session exists for that date" (no school / teacher didn't take attendance) and "session exists but student was not marked" (a bug — should never happen post-submission). Mixing these up causes incorrect "—" in reports.

**Prevention:** After an attendance session is submitted, the Go backend must verify all students in the class have a corresponding `attendance_records` row before marking `is_locked = true`. Any missing records are a data integrity error, not a "no school" day. Write a SQL CHECK or a pre-lock validation query.

**Phase:** Attendance submission + report generation phases.

---

### MIN-4: Supabase Connection Pool Exhaustion

**What goes wrong:** Supabase's free and Pro tiers have connection limits (e.g., 60 direct connections on Pro). A Go service using `database/sql` with a large pool size and high concurrency during the cron window can exhaust connections.

**Prevention:** Use PgBouncer (Supabase's built-in connection pooler, available at the pooler URL in Supabase dashboard) for all application queries. Set `db.SetMaxOpenConns(20)` in Go. Direct connections (non-pooler) should only be used for migrations.

**Phase:** Database/infrastructure phase.

---

### MIN-5: Student Card Image Loading Jank During Swipe Transition

**What goes wrong:** Phase 1 uses placeholder avatars (no real photos). But if student photos are added in Phase 2 and the image URL is fetched during the card swipe transition, a brief blank/loading state breaks the 60fps animation.

**Prevention:** Pre-fetch the next card's image before it becomes the top card (prefetch 2 cards ahead). Use `precacheImage()` in Flutter. Establish this pattern in Phase 1 even with placeholder avatars so Phase 2 doesn't introduce jank.

**Phase:** Attendance swipe screen phase.

---

## Phase-Specific Warning Map

| Phase Topic | Likely Pitfall | Key Mitigation |
|---|---|---|
| Database schema creation | CRIT-3 (RLS gaps), HIGH-7 (deferred RLS), MIN-4 (connection pool) | Write all RLS policies + indexes in migration files before any other phase |
| DLT / MSG91 registration | HIGH-6 (DLT blocking OTP) | Start DLT registration before coding auth — 3–14 day lead time |
| Auth — OTP + JWT | CRIT-1 (non-expiring token), CRIT-4 (Android backup), HIGH-3 (race condition), MIN-1 (Keystore re-install) | Add `last_used_at` to refresh_tokens, set `allowBackup=false`, implement Dio interceptor queue |
| Attendance swipe screen | HIGH-1 (jank), HIGH-2 (Android gesture conflict) | Use `RepaintBoundary` + animation scoping; test on physical Android 10+ gesture nav device |
| Attendance submission | CRIT-2 (midnight timezone), MOD-1 (double submit), MOD-2 (swipe data lost) | IST timezone constant in shared pkg; state machine for submit button; app-level state for swipe results |
| Statistics screen | MOD-6 (academic year boundary) | Calendar month only in Phase 1; document academic year gap explicitly |
| PDF/Excel generation | HIGH-4 (OOM on cron), HIGH-5 (Excel compat) | Worker pool semaphore; test xlsx in MS Excel; validate "—" vs null logic |
| Cron job | HIGH-4 (memory), MOD-5 (double fire) | Bounded worker pool; idempotency check before generation |
| Supabase Storage cleanup | MOD-4 (no auto-expiry) | Daily cleanup cron; test with synthetic expired records |
| Student management | MIN-2 (roll number sort) | Keep `roll_number` as INTEGER throughout |

---

## India-Specific Concerns Checklist

- [ ] **DLT registration** started before auth development (3–14 day approval lead time).
- [ ] **MSG91 template** pre-approved with exact OTP text including "Valid for 10 minutes" (TRAI requirement for OTP templates).
- [ ] **IST timezone** (`Asia/Kolkata`, UTC+5:30, no DST) used for all business-rule time calculations.
- [ ] **Academic year** (June–May) boundary documented in stats code; calendar months used in Phase 1.
- [ ] **Indian mobile numbers** are 10 digits (without country code) — validation regex `^[6-9]\d{9}$` (Indian mobile numbers start with 6, 7, 8, or 9). Validate server-side, not just client-side.
- [ ] **Low-end Android devices** (Redmi Note series, Realme) used for swipe animation profiling — not just flagship phones.
- [ ] **Intermittent mobile networks** (2G/3G in rural areas) handled gracefully: retry buttons, no data loss on submit failure.
- [ ] **MSG91 rate limits** — default limits may restrict bulk OTP sends during peak school registration season (June). Contact MSG91 to raise limits before launch.

---

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Flutter swipe jank / gesture conflicts | MEDIUM | Well-documented Flutter performance patterns; Android gesture nav behavior verified in training data through Android 14 |
| JWT race conditions | HIGH | Standard distributed systems pattern; Dio interceptor queue is documented behavior |
| Supabase RLS architecture | MEDIUM | Supabase PostgREST + RLS + custom JWT interaction documented in official Supabase docs as of 2024; verify current docs for any 2025 changes |
| MSG91 DLT | MEDIUM | DLT requirement confirmed by TRAI regulation (effective 2021, still enforced 2025); MSG91-specific template flow from training data — verify current MSG91 docs |
| Go PDF/Excel generation | MEDIUM | `gofpdf`/`excelize` behavior from training data; verify latest `excelize` version for current OOXML compat |
| Timezone (IST/midnight lock) | HIGH | Go `time.LoadLocation("Asia/Kolkata")` is standard; IST = UTC+5:30 with no DST is a fixed fact |
| Flutter state management (offline) | MEDIUM | Pattern-level knowledge; specific library behavior (Riverpod 2.x vs BLoC 8.x) should be verified against current docs |

---

## Sources

*WebSearch and Brave Search were not available in this environment. All findings are from training data (knowledge cutoff: mid-2025). Validate against:*

- Flutter performance docs: https://docs.flutter.dev/perf/rendering-performance
- Flutter secure storage: https://pub.dev/packages/flutter_secure_storage
- Supabase RLS with custom JWT: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase custom claims / JWT: https://supabase.com/docs/guides/auth/jwts
- MSG91 DLT docs: https://help.msg91.com/article/140-dlt-registration
- Go timezone: https://pkg.go.dev/time#LoadLocation
- excelize (Go Excel): https://pkg.go.dev/github.com/xuri/excelize/v2
- TRAI DLT circular: https://www.trai.gov.in/sites/default/files/Regulation_19072018.pdf
- Dio HTTP client interceptors: https://pub.dev/packages/dio
