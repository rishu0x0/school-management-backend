---
phase: 06-flutter-attendance-swipe
plan: "05"
status: complete
completed: 2026-05-20
---

# 06-05 Summary — Statistics Screen (Donut Chart + Monthly Overview)

## What was built

### StatsRepository (`app/lib/features/stats/repository/stats_repository.dart`)
- Models: `TodayStats`, `StudentStat`, `MonthlyStats` with `fromJson` constructors
- `@riverpod StatsRepository statsRepository(Ref ref)` provider
- `getToday(classID)` → GET `/classes/$classID/stats/today`
- `getMonthly(classID, month)` → GET `/classes/$classID/stats/monthly?month=YYYY-MM`
- Generated: `stats_repository.g.dart`

### StatsNotifier (`app/lib/features/stats/notifier/stats_notifier.dart`)
- `StatsState` value class with `today`, `monthly`, `selectedMonth` + `copyWith`
- `@riverpod class StatsNotifier` family by `classID`
- `build()`: loads today + monthly in parallel via `Future.wait`
- `changeMonth(month)`: updates `selectedMonth` immediately, then fetches new monthly data
- `refresh()`: resets to `AsyncLoading` and re-runs `build`
- Generated: `stats_notifier.g.dart`

### StatsScreen (`app/lib/features/stats/screens/stats_screen.dart`)
- Replaced stub; ConsumerWidget watching `statsNotifierProvider(classID)`
- AppBar back button → `context.go('/classes')`; refresh icon button
- **Today's section**: `fl_chart PieChart` donut (centerSpaceRadius: 40, radius: 60)
  - Present=green, Absent=red, Leave=amber sections with white count labels
  - Legend row below chart; `submitted: false` → shows "No attendance recorded today"
- **Monthly section**: `_MonthPicker` DropdownButton (last 6 months in YYYY-MM format)
  - Summary card: Days Recorded / Average Attendance % / Below-75% count
  - Below-threshold list: red CircleAvatar with roll number, student name, attendance %
- Pull-to-refresh via `RefreshIndicator`
- Error state with Retry button

## Verification
- `flutter analyze` zero issues (including zero `info` warnings)
- `build_runner` generated all `.g.dart` files successfully
- Phase 6 complete
