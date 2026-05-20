# Phase 06-01 Summary — Swipe Card Attendance UI

## Status: COMPLETE

## What was built

### AttendanceSwipeScreen (`lib/features/attendance/screens/attendance_swipe_screen.dart`)
- `ConsumerStatefulWidget` that reads `AttendanceNotifier(classID)`
- `CardSwiper` with `controller`, `cardsCount`, `initialIndex`, `isLoop: false`
- `AllowedSwipeDirection.only(left: true, right: true, up: true)` — down blocked
- Swipe mapping: **Left → Present**, **Right → Absent**, **Up → Leave**
- `onSwipeDirectionChange` drives the live overlay on `StudentSwipeCard` (green/red/amber)
- `LinearProgressIndicator` at top showing `currentIndex / students.length`
- "All marked" state shows a completion view with "Review & Submit" button
- AppBar "Review" button navigates to summary at any time
- `initState` post-frame check: if session already submitted → `pushReplacement` to stats
- Bottom 80px placeholder for tap buttons (wired in 06-02)

### Stub screens
- `attendance_summary_screen.dart` — placeholder with "Submit Attendance" button
- `attendance_submit_screen.dart` — placeholder, replaced in 06-02
- `stats/screens/stats_screen.dart` — placeholder, replaced in later phase

### Router (`lib/core/router/router.dart`)
Four new routes added:
- `/classes/:classID/attendance` → `AttendanceSwipeScreen`
- `/classes/:classID/attendance/summary` → `AttendanceSummaryScreen`
- `/classes/:classID/attendance/submit` → `AttendanceSubmitScreen`
- `/classes/:classID/stats` → `StatsScreen`

### Entry points
- **StudentListScreen**: `IconButton(Icons.how_to_reg)` in AppBar → pushes attendance route
- **ClassListScreen**: "Take Attendance" option added to each card's `PopupMenuButton`

## Package API confirmed (flutter_card_swiper 7.2.0)
- `CardSwiperDirection` is a class with static constants (`left`, `right`, `top`, `bottom`, `none`) using angle-based comparison
- `AllowedSwipeDirection.only(up:, down:, left:, right:)` — all named params
- `onSwipeDirectionChange(horizontal, vertical)` exists and was used for live overlay
- `CardSwiperController.dispose()` is async — called in `State.dispose()` without await (safe)

## Verification
- `flutter analyze`: **0 issues**
- `build_runner`: clean build, 2 outputs written

## Commit
`be2269e` — feat(06-01): swipe card attendance — Left=Present, Right=Absent, Up=Leave
