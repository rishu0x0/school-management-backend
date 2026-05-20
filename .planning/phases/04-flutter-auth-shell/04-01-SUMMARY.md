---
phase: 04-flutter-auth-shell
plan: "01"
tags: [flutter, scaffold, riverpod, go_router, msg91, sendotp]
subsystem: flutter-app
dependency_graph:
  requires: []
  provides: [flutter-project-scaffold, pubspec-deps, feature-dirs, main-entry, app-widget-stub]
  affects: [04-02, 04-03, 04-04]
tech_stack:
  added:
    - flutter_riverpod 2.6.1
    - riverpod_annotation 2.6.1
    - go_router 14.8.1
    - flutter_secure_storage 9.2.4
    - dio 5.7.0
    - sendotp_flutter_sdk 0.0.2
    - connectivity_plus 6.1.5
    - riverpod_generator 2.6.1
    - build_runner 2.5.4
    - riverpod_lint 2.6.1
    - custom_lint 0.6.10
  patterns:
    - ProviderScope at root — all Riverpod providers accessible app-wide
    - ConsumerWidget for App — enables watching providers at the widget level
    - OTPWidget.initializeWidget at startup — MSG91 SDK initialized before runApp
key_files:
  created:
    - app/pubspec.yaml
    - app/analysis_options.yaml
    - app/lib/main.dart
    - app/lib/app.dart
    - app/lib/core/auth/.gitkeep
    - app/lib/core/network/.gitkeep
    - app/lib/core/router/.gitkeep
    - app/lib/core/storage/.gitkeep
    - app/lib/features/auth/screens/.gitkeep
    - app/lib/features/auth/repository/.gitkeep
    - app/lib/features/auth/widgets/.gitkeep
    - app/lib/features/home/.gitkeep
  modified: []
decisions:
  - sendotp_flutter_sdk ^1.0.4 not on pub.dev; resolved to 0.0.2 (latest available); OTPWidget.initializeWidget confirmed present in 0.0.2 source — import kept in main.dart without fallback needed
  - analysis_options.yaml enables custom_lint plugin and suppresses invalid_annotation_target (required for riverpod_annotation codegen)
  - environment sdk constraint relaxed to >=3.3.0 <4.0.0 from flutter create default (^3.8.1) to match plan spec and ensure compatibility with riverpod 2.x
metrics:
  duration: 4 min
  completed: 2026-05-20
  tasks_completed: 2
  files_created: 13
---

# Phase 4 Plan 01: Flutter Project Scaffold Summary

Flutter project scaffolded at `app/` with feature-first directory structure, all Phase 4 dependencies declared, and a bare compilable skeleton. `flutter pub get` succeeded and `flutter analyze` reports zero issues on `main.dart` and `app.dart`.

## What Was Built

- **Flutter project** created with `flutter create --no-pub --org com.schoolmanagement --project-name school_attendance --platforms ios,android`
- **pubspec.yaml** replaced with full dependency spec: Riverpod 2.x, go_router, flutter_secure_storage, dio, sendotp_flutter_sdk, connectivity_plus, and all dev deps for codegen (riverpod_generator, build_runner, riverpod_lint, custom_lint)
- **main.dart** — `WidgetsFlutterBinding.ensureInitialized()`, `OTPWidget.initializeWidget(widgetId, authToken)`, `runApp(ProviderScope(child: App()))`
- **app.dart** — `ConsumerWidget` stub returning `MaterialApp` with Material3 theme (seed color `0xFF1565C0`), `debugShowCheckedModeBanner: false`, loading spinner home
- **Feature-first directories** with `.gitkeep` files: `lib/core/{auth,network,router,storage}`, `lib/features/{auth/{screens,repository,widgets},home}`

## Dependencies Added (Resolved Versions from pub get)

| Package | Requested | Resolved |
|---------|-----------|---------|
| flutter_riverpod | ^2.6.1 | 2.6.1 |
| riverpod_annotation | ^2.3.5 | 2.6.1 |
| go_router | ^14.6.2 | 14.8.1 |
| flutter_secure_storage | ^9.2.2 | 9.2.4 |
| dio | ^5.7.0 | 5.7.0 |
| sendotp_flutter_sdk | ^0.0.2 (downgraded) | 0.0.2 |
| connectivity_plus | ^6.1.3 | 6.1.5 |
| riverpod_generator | ^2.4.3 | 2.6.1 |
| build_runner | ^2.4.12 | 2.5.4 |
| riverpod_lint | ^2.3.13 | 2.6.1 |
| custom_lint | ^0.6.8 | 0.6.10 |

## Directory Structure Created

```
app/lib/
  main.dart
  app.dart
  core/
    auth/           (.gitkeep)
    network/        (.gitkeep)
    router/         (.gitkeep)
    storage/        (.gitkeep)
  features/
    auth/
      screens/      (.gitkeep)
      repository/   (.gitkeep)
      widgets/      (.gitkeep)
    home/           (.gitkeep)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] sendotp_flutter_sdk ^1.0.4 does not exist on pub.dev**
- **Found during:** Task 1 — first `flutter pub get` attempt
- **Issue:** `sendotp_flutter_sdk ^1.0.4` caused version solving to fail with "doesn't match any versions". The plan's Important Notes anticipated this and specified the fallback: try without version constraint, or remove import if still fails.
- **Fix:** Ran `flutter pub add sendotp_flutter_sdk` (no version constraint) which resolved to `^0.0.2` — the latest version published. Verified `OTPWidget.initializeWidget` exists in v0.0.2 source (`lib/src/otp_widget.dart` line 20). Import and call in `main.dart` kept unchanged — no fallback comment needed.
- **Files modified:** `app/pubspec.yaml` (sendotp_flutter_sdk constraint changed from ^1.0.4 to ^0.0.2)
- **Commit:** 7686f11

## flutter pub get Result

```
Got dependencies!
49 packages have newer versions incompatible with dependency constraints.
```

Clean resolution. The 49 "newer versions" warning is informational only — all packages resolved successfully within declared constraints.

## flutter analyze Result

```
Analyzing 2 items...
No issues found! (ran in 1.9s)
```

## Verification Checklist

- [x] `app/` directory exists with Flutter project structure
- [x] `flutter pub get` exits with no errors
- [x] `pubspec.yaml` contains: flutter_riverpod, riverpod_annotation, go_router, flutter_secure_storage, dio, sendotp_flutter_sdk, connectivity_plus
- [x] `lib/main.dart` has `ProviderScope` wrapping `App`
- [x] `lib/main.dart` has `OTPWidget.initializeWidget` call
- [x] Feature directories exist: `lib/core/auth/`, `lib/core/network/`, `lib/core/router/`, `lib/core/storage/`, `lib/features/auth/`

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 + Task 2 | 7686f11 | feat(04-01): flutter project scaffold — ProviderScope, Riverpod 2.x, go_router, MSG91 SDK |

## Self-Check: PASSED

- app/lib/main.dart: FOUND
- app/lib/app.dart: FOUND
- app/pubspec.yaml: FOUND (sendotp_flutter_sdk 0.0.2)
- Feature dirs: FOUND (all 8 .gitkeep files committed)
- Commit 7686f11: FOUND
