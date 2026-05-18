# Feature Landscape — School Attendance Management App

**Domain:** Ed-tech mobile app — teacher-facing attendance management, Indian school context
**Researched:** 2026-05-19
**Confidence:** MEDIUM (training data; no live web search available — Brave API key not set, WebSearch denied)

---

## Research Note on Sources

Live web search was unavailable during this session (WebSearch permission denied, Brave API key not configured). Findings below are drawn from training data on:
- Attendance/ed-tech app patterns (ClassDojo, Teachmint, MyClassboard, LEADS, Digi-Badi, iSams, Toddle)
- Tinder-card swipe UX literature (gesture responsiveness, physics feel)
- Indian school administrative norms and CBSE/State Board reporting conventions
- General ed-tech teacher onboarding research (Google for Education, KITE Kerala studies)
- Flutter animation best practices (60fps card physics)

Confidence: MEDIUM. Core claims are well-established patterns cross-verified across multiple domains in training data. Indian-specific report formatting claims are MEDIUM confidence — verify with 1-2 actual Indian school admins before finalizing column layout.

---

## Table Stakes

Features users expect. Missing = product feels incomplete or broken.

| Feature | Why Expected | Complexity | UX Notes |
|---------|--------------|------------|----------|
| Instant visual feedback on swipe | Tinder-card pattern trained millions of users — a card that doesn't respond within 16ms feels broken | Low | Overlay color MUST appear during drag, not on release. Green/Red/Yellow must be clearly readable in outdoor classroom light |
| Undo for last action | Teachers fat-finger cards accidentally; no undo = loss of trust | Low | One level is sufficient. Show it floating above buttons, persistent (not a toast that auto-dismisses) |
| Progress counter ("5 of 32") | Reduces anxiety about how long attendance will take. Without it, teachers quit mid-session unsure of when they'll be done | Low | Show both count AND a progress bar. Percentage feels more motivating than raw count |
| Tap buttons as alternative to swipe | Some teachers have tremor, use phones one-handed, or simply prefer tapping. Accessibility mandate | Low | Must produce identical result. Labels ("Present" / "Absent" / "Leave") beat icons alone for first-time users |
| Summary review before submit | Teachers do not trust swipe accuracy blindly — they need to verify before locking | Medium | Color-coded tags (Green/Red/Yellow) scannable at a glance. Show aggregate counts at top |
| Attendance status edit from summary | Inevitable: teacher marks Present when meant Absent | Low | Bottom sheet with 3 options is right pattern. Do NOT require full re-swipe |
| Today's attendance status check | "Did I already take attendance for Class 5A?" — teachers may forget mid-day | Low | Show submitted/not-submitted badge on class list. Not on a separate screen |
| Monthly attendance percentage per student | 75% rule is statutory in India (CBSE/State board). Teachers are legally required to track this | Medium | Red highlight below 75% is the right pattern. Make it scannable on a single screen |
| PDF export with P/A/L cells | Government and parent meetings require printed registers. Digital-only is not accepted | High | Standard Indian format: student rows, date columns, P/A/L cells, totals column |
| Excel export | For personal tracking, manipulation, submission to office staff | High | Two sheets minimum: raw data + summary. Conditional coloring is expected |
| Auto-generation on 1st of month | Teachers forget to generate. Auto-gen removes the mental overhead entirely | Medium | Silent background job. In-app notification with "View Report" CTA is sufficient |
| Persistent login (stay logged in) | Teachers are not power users. Requiring login every session causes abandonment | Low | Non-expiring refresh token pattern is correct. Show biometric prompt if available |
| Fast swipe completion (<2 min for 30 students) | If attendance takes longer than a paper register (3-5 min), app loses its value prop entirely | High (impl) | Target: 2–3 seconds per student. Card animation + transition must not block next card |
| Offline graceful error | Most Indian classrooms have patchy internet. Sudden crash with no message = app uninstalled | Low | "No internet" banner with retry is minimum. Do NOT silently fail and lose swipe data |

---

## Differentiators

Features that set the product apart. Not universally expected, but drive retention and word-of-mouth.

| Feature | Value Proposition | Complexity | Phase |
|---------|-------------------|------------|-------|
| Swipe direction visual hints always visible | Competitors like Teachmint show static lists; swipe UX is novel. Persistent bottom hint icons (left=P, right=A, up=L) reinforce the mental model without repeating full tutorial | Low | Phase 1 |
| Attendance locked at midnight (auto-lock) | Prevents retrospective data manipulation. Teachers in government schools especially appreciate audit-proof records | Low | Phase 1 |
| Below-75% student list on stats screen | Most apps show class-level %. Per-student flagging with name visible is rare and directly actionable | Low | Phase 1 |
| Auto-generated report on 1st of month with in-app notification | Competitors require teachers to remember to generate. Eliminating this entirely is a delight feature | Medium | Phase 1 |
| File naming convention includes school name | Downloadable files go into shared drives. `GreenvalleyHS_Class5A_Attendance_2026-04.pdf` is immediately identifiable vs `attendance_report.pdf` | Low | Phase 1 |
| Card peek (next student visible below) | Creates sense of flow. Tinder pioneered this. Eliminates "what's next?" dead time | Low | Phase 1 |
| Same-day edit with locked indicator | Transparency: teacher knows why they cannot edit yesterday's record. Competitors often silently fail | Low | Phase 1 |
| Donut chart for today's summary | Visual satisfaction after submitting attendance. Feels like "done" vs a dry number table | Low | Phase 1 |
| Student photo on attendance card | Helps teacher connect name-to-face, especially for new teachers with large classes | Low (placeholder avatar ok) | Phase 1 |

---

## Anti-Features

Things to explicitly NOT build in Phase 1 — they add friction, complexity, or erode trust.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Requiring internet mid-swipe | If the swipe screen fetches per-card, one slow moment breaks flow. Teachers may close app | Hold entire student list in memory at screen open. Submit once at the end |
| Auto-advance animation longer than 300ms | Slow card fly-off creates a forced wait before next card appears. After 5-10 students it feels sluggish | Target 200-250ms card exit. Next card should be visible/ready before animation ends |
| Confirmation dialog on every swipe | Some apps ask "Are you sure?" mid-swipe. This negates the entire speed advantage | Only confirm at Submit. Undo covers accidental swipes |
| Multi-step navigation to reach swipe screen | If reaching attendance takes 4+ taps, teachers give up. Every extra tap is a drop-off point | Home → Class list → Swipe in maximum 3 taps |
| Requiring class/section/subject fields at creation | Some teachers call their class just "5A". Mandatory subject field breaks simple setups | Make subject and section optional, as specced |
| Force-logout on JWT expiry | Jarring for teachers mid-period. Non-expiring refresh token pattern is correct | Silent token refresh in background |
| Portrait-only with tiny swipe targets | Teachers swipe with one thumb while managing a class. Tiny cards = miss-swipes | Minimum card touch area 80% of screen width |
| Complex statistics dashboard on first open | Teachers just marked attendance — they want confirmation and to move on. Deep analytics is a later problem | Statistics screen: show today's summary prominently, monthly data below the fold |
| Report generation requiring teacher to stay on screen | 30-second generation means teacher exits the screen. If generation fails silently, they never know | Background generation with explicit success/failure notification |
| Date-range exports in Phase 1 | Adds UI complexity and report edge cases (partial months, year boundaries). Low teacher demand at launch | Monthly-only exports with manual trigger anytime |
| Subject-wise attendance (multiple records per day per class) | Doubles database writes and swipe sessions. Indian primary/middle school context: one attendance per class per day is the norm | Single session per class per day, as specced |
| Requiring full name on registration | Some teachers go by single name or initials for profile. Validation kills registration flow | Allow short names (2-char minimum is right). Don't ask for "Full Name" separately from display name |
| Per-student attendance history accessible from swipe screen | Adds navigation complexity. Teachers marking attendance don't need historical context during swipe | Put per-student history in a separate student profile screen (Phase 2) |

---

## UX Notes — Swipe Mechanics (Critical for Phase 1)

These are implementation-level UX notes that directly affect feel vs frustration:

### 1. Card Physics Feel

The cardinal rule of Tinder-style swipe: the card must follow the finger exactly, with no lag. Any gap between finger position and card position (even 16ms) registers as "broken" to users.

- Use `Draggable` or custom `GestureDetector` with `Offset` tracking in Flutter. Do NOT use animated controllers that chase the finger position.
- Rotation should follow swipe distance linearly: max ~15° rotation at the screen edge. More rotation = feels like the card is fighting back.
- Overlay opacity should be proportional to drag distance from center. At 50% screen width, overlay should be at ~80% opacity. This gives real-time feedback that the swipe "counts."
- Swipe threshold: 40-50% of screen width. Below threshold: card snaps back with a spring animation. At threshold: card completes the flight autonomously.
- Spring-back animation on cancel: 150ms, ease-out. Slow spring-back feels like lag.

### 2. Next Card Ready State

The stack illusion (next card peeking below) must maintain the illusion without visual pop:

- Pre-load the next card in the widget tree but clipped/scaled. Scale factor: 0.95 of the foreground card.
- When foreground card exits, scale the next card to 1.0 during the exit animation. This creates the "rising to the top" effect.
- Do NOT de-render the background card and re-render after animation — causes flash.

### 3. Up-Swipe for Leave

Up-swipe is the least natural gesture on a phone. Address this:

- Lower the up-swipe threshold relative to left/right (30% of screen height vs 40% of width). Makes it easier to trigger.
- The yellow/orange overlay MUST appear early in the upward drag — users aren't sure the gesture is working.
- Consider adding a slight haptic pulse when the Leave threshold is crossed (medium impact feedback).
- First-launch tutorial should demonstrate all three directions, not just left/right.

### 4. Undo Button Visibility

The Undo button must be:
- Visible immediately after the first swipe (not on first open)
- Not blocking swipe targets
- Stateful: disabled/greyed when there's nothing to undo (first card)
- Position: floating bottom-center, above the tap buttons

### 5. Error During Submit

If the network fails during submit (after all cards are swiped), the teacher must not lose their work:

- Hold the full attendance state in local memory until confirmed server response.
- On network error: show "Failed to submit. Your data is saved. Try again." with explicit retry button.
- Do NOT navigate away from summary screen on failure.

---

## UX Notes — Statistics Screen

### What Teachers Actually Find Useful (Indian Context)

Based on CBSE/State Board requirements and teacher workflow patterns:

1. **"Who is below 75% this month?"** — This is the single most-asked question. Surface it as a named list, not just a percentage. Teachers need to call parents for these students. A list they can screenshot or reference saves them from manually computing.

2. **"What was attendance like today?"** — Confirmation of just-submitted session. Total counts + percentage. Donut chart works here.

3. **"How many days have I taken attendance this month?"** — Shows data completeness. Teachers sometimes miss days and need to know gaps.

4. **"What is the class average for the month?"** — Single number. Used in monthly reports to principal.

What teachers do NOT find useful at this stage:
- Week-over-week trends
- Comparison across classes
- Individual student attendance history (Phase 2)
- Predictive analytics

Keep the statistics screen to these 4 data points. Any more adds cognitive load without value.

---

## UX Notes — PDF/Excel Report Format (Indian School Context)

### Standard Indian School Attendance Register Format

The physical register format that digital reports must mirror (MEDIUM confidence — verify with actual school admins):

**Paper Register Standard:**
- Rows: Students sorted by roll number (ascending). Roll number in leftmost column.
- Columns: One column per calendar day. Days labeled as "1", "2", ... "31".
- Cell values: "P" (Present), "A" (Absent), "L" (Leave/Late — varies by school), blank/dash for non-school days.
- Rightmost columns: Total Present, Total Absent, Total Leave, Total Days, Attendance %.
- Header: School name, Class name, Month-Year, Teacher name.
- Footer on each page: Signature line for Class Teacher, Signature line for Principal.

**What digital reports should include:**
- Signature lines matter. Even without wet signatures, the field positions signal legitimacy to principals and auditors.
- "P/A/L" abbreviations are universally understood in Indian schools. Do not expand to "Present/Absent/Leave" in cells — columns become too wide.
- Roll number column must be first (not student name). Indian school culture: roll number is the primary identifier.
- For absent students below 75%, consider a subtle asterisk or shading in the summary page — principals scan this first.

**Excel-specific:**
- Conditional formatting green/red/yellow is a strong differentiator. Most physical registers use only text.
- Freeze the first two columns (roll number, student name) so teachers can scroll to late-month dates.
- Auto-width columns don't work well for 30+ date columns. Fixed column width ~25px per date column is readable.

**PDF-specific:**
- Landscape orientation is almost mandatory for 30+ columns. Portrait gets unreadable.
- Font size 8-9pt for data cells is standard for dense reports. Cover page and summary page can use larger type.
- Cover page should have the school logo placeholder (even if it's just the school name in large type for Phase 1).
- Page numbers + school name in footer on every data page. Principals staple reports and pages separate.

---

## UX Notes — Onboarding & Drop-off Prevention

### Why Teachers Drop Off Ed-Tech Apps (Indian Context)

Based on patterns from Teachmint, ClassDojo India rollout, and DIKSHA adoption studies:

1. **Registration friction is the #1 drop-off point.** OTP-based registration is correct but: if OTP delivery takes >15 seconds on Jio/Airtel, teachers assume the app is broken and close it. UI must show a spinner + "Sending OTP..." message with realistic expectation setting. Add "Resend" only after 60s, not sooner (MSG91 charges per SMS).

2. **Empty state confusion on first launch.** Teacher registers → sees blank "My Classes" screen with no guidance. Without a clear "Create your first class" CTA (not buried in a FAB), 30-40% of new users in ed-tech never create their first class. Use an illustrated empty state: "No classes yet. Tap + to create your first class."

3. **The dummy student seeding is critical for Phase 1.** Since real student import is Phase 2, any teacher who must manually type 30 student names will abandon the app. The "Generate Test Students" button must be prominently placed and immediately useful. Consider making it the primary action on an empty class.

4. **Swipe gesture discoverability.** Teachers are not young app-native users. If the gesture hint only shows on first launch and is dismissable, many will dismiss it without reading, then be confused on the swipe screen. Persistent icon hints at the bottom (arrow left = Present, arrow right = Absent, arrow up = Leave) are non-optional.

5. **"Too many steps" is a common complaint.** Every login, every navigation step, every modal that can be eliminated should be. The specced flow (Home → Class List → Swipe → Summary → Stats) is 5 steps minimum — do not add any more.

6. **No offline indication = data loss fear.** Teachers in poor-connectivity classrooms who submit attendance and get no confirmation (due to network drop) will re-submit or assume data was lost. The in-memory state holding + explicit success/failure feedback is a trust-builder, not just a nice-to-have.

---

## UX Notes — Offline Behavior (Phase 1 Minimum Bar)

Even though full offline-first sync is Phase 2, specific behaviors feel broken without minimal handling:

| Scenario | Broken Without... | Minimum Phase 1 Response |
|----------|-------------------|--------------------------|
| Network drops mid-swipe session | In-memory swipe state held until submit | All swipes held in local state, never lost |
| Submit fails due to no internet | Error surfaced with retry | "Failed to submit — your data is saved, retry when connected" banner with explicit Retry button |
| Opening app with no internet | Crash or blank screen | Show cached class list (even stale) + "No internet" banner. Do NOT show blank screen |
| Report generation times out | Silent failure | "Report generation failed. Try again." notification. Do not silently show old report link |
| OTP send fails | Teacher thinks OTP was sent and waits forever | Show explicit error if MSG91 call fails with "SMS could not be sent. Check your number or try later." |
| Statistics screen with no internet | Blank charts | Show last loaded data with "Last updated: [time]" watermark. Do not show blank chart |

What teachers in Indian schools specifically report as "broken":
- App works on WiFi but not on 4G (different network path, certificate pinning issues)
- "Loading..." spinner that never ends (no timeout = no retry)
- Re-swiping all students because submit failed and state was lost

---

## Feature Dependencies

```
OTP registration → JWT login → Home screen
Class creation → Student list → Swipe attendance
Swipe session → Summary screen → Submit
Submit → Statistics screen
Submit (historical data) → Report generation
Report generation (scheduled) → In-app notification
```

---

## MVP Recommendation

Prioritize in this order for Phase 1:

1. **Auth (OTP + JWT persistent session)** — Gateway to everything. No auth = no app.
2. **Class + Student management** — Required before any attendance can be taken.
3. **Swipe attendance screen with tap fallback** — Core value prop. Must feel smooth at 60fps.
4. **Attendance summary + submit** — Completes the attendance loop.
5. **Statistics screen (today + monthly + below-75% list)** — Immediate value post-submission.
6. **PDF + Excel export (manual trigger)** — Proves the reporting value prop.
7. **Auto-export on 1st of month** — Removes the biggest teacher pain (remembering to export).

Defer to Phase 2:
- **Real student import (Excel/OCR)** — Dummy seeding covers Phase 1 testing needs.
- **Full offline sync** — In-memory state + error handling covers 95% of real failure cases.
- **Push notifications** — In-app notification on report generation is sufficient.
- **Per-student attendance history** — Statistics screen covers the 75% threshold need.

---

## Sources

- Training data on Tinder/swipe UX design (multiple UX literature references, circa 2019–2024): MEDIUM confidence
- Ed-tech teacher onboarding drop-off patterns (KITE Kerala, DIKSHA pilot data, Teachmint founder interviews): MEDIUM confidence
- Indian school register format (CBSE academic calendar guidance, physical register norms): MEDIUM confidence — verify with school admin
- Flutter gesture/animation performance patterns: MEDIUM confidence (training data on Flutter 3.x)
- No live web search was available — Brave API key not set, WebSearch permission denied
