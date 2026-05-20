---
phase: 05-flutter-class-student-management
plan: "01"
subsystem: flutter-app
tags: [flutter, riverpod, class-management, dio, go_router]
dependency_graph:
  requires: [04-flutter-auth-shell, 03-go-crud-api]
  provides: [class-list-screen, class-repository, classes-notifier, delete-warning-flow]
  affects: [router, home-screen, student-list-stub]
tech_stack:
  added: [flutter_slidable ^3.1.1]
  patterns: [AsyncNotifier, ConsumerStatefulWidget, showModalBottomSheet, PopupMenuButton, RefreshIndicator]
key_files:
  created:
    - app/lib/features/classes/repository/class_repository.dart
    - app/lib/features/classes/repository/class_repository.g.dart
    - app/lib/features/classes/notifier/classes_notifier.dart
    - app/lib/features/classes/notifier/classes_notifier.g.dart
    - app/lib/features/classes/screens/class_list_screen.dart
    - app/lib/features/classes/widgets/class_form_sheet.dart
    - app/lib/features/classes/widgets/delete_class_dialog.dart
    - app/lib/features/students/screens/student_list_screen.dart
  modified:
    - app/lib/features/home/home_screen.dart
    - app/lib/core/router/router.dart
    - app/lib/core/router/router.g.dart
    - app/pubspec.yaml
    - app/pubspec.lock
decisions:
  - Renamed ClassesNotifier.update to updateClass to avoid collision with AsyncNotifierBase.update
  - showDeleteClassFlow implemented as a top-level function (not a widget class) for clean call-site usage
  - DeleteClassDialog widget removed in favour of inline AlertDialog inside showDeleteClassFlow — simpler and avoids double-dialog nesting
metrics:
  duration: ~25min
  completed_date: 2026-05-20
  tasks_completed: 4
  files_created: 8
  files_modified: 4
---

# Phase 5 Plan 01: Class List Screen, CRUD, and Delete-Warning Flow Summary

**One-liner:** Full class management feature with two-step Go-API delete-warning flow, AsyncNotifier state, create/edit bottom sheet, and router wired to student stub.

## Features Implemented

### ClassRepository (`class_repository.dart`)
- `list()` — GET /classes, maps JSON `{classes: [...]}` to `List<ClassModel>`
- `create()` — POST /classes with name/section/subject; throws `ApiException` on 4xx
- `update()` — PUT /classes/{classID} with name only; throws `ApiException` on 4xx
- `delete(classID, confirm)` — DELETE /classes/{classID}[?confirm=true]; returns `DeleteWarning?` (null when confirmed/deleted)
- `ClassModel` — immutable data class with id, name, section?, subject?, createdAt
- `DeleteWarning` — studentCount + message from Go API warning response
- `ApiException` — typed exception for API errors surfaced to UI

### ClassesNotifier (`classes_notifier.dart`)
- `@riverpod class ClassesNotifier extends _$ClassesNotifier`
- `build()` returns `Future<List<ClassModel>>` — AsyncNotifier pattern
- `refresh()` — sets AsyncLoading then AsyncValue.guard
- `create()` / `updateClass()` — delegate to repo then refresh (renamed from `update` to avoid `AsyncNotifierBase.update` collision)
- `getDeleteWarning(classID)` — calls delete(confirm: false) to get warning
- `confirmDelete(classID)` — calls delete(confirm: true) then refresh

### ClassFormSheet (`class_form_sheet.dart`)
- Create mode: name (required), section (optional), subject (optional)
- Edit mode: name only (section/subject fields hidden)
- Inline error display for `ApiException`; loading spinner on submit button

### Delete Flow (`delete_class_dialog.dart`)
Two-step flow matching the Go backend confirm-required pattern:
1. Call `getDeleteWarning(classID)` — HTTP DELETE without `?confirm=true` → Go returns 200 with `{confirm_required: true, warning: {student_count, message}}`
2. Show `AlertDialog` with the warning message from the server (student count embedded)
3. On user confirm: call `confirmDelete(classID)` — HTTP DELETE with `?confirm=true` → actually deletes

### ClassListScreen (`class_list_screen.dart`)
- Loading state: centered `CircularProgressIndicator`
- Error state: icon + message + Retry button calling `refresh()`
- Empty state: school icon + prompt + inline "Create Class" button
- Populated: `ListView.separated` with `Card`/`ListTile`, avatar with first letter, subtitle for section/subject
- `PopupMenuButton` per item: Edit (opens ClassFormSheet) / Delete (runs showDeleteClassFlow)
- Tap navigates to `/classes/:classID/students` via `context.push` with `extra: {className}`
- `RefreshIndicator` for pull-to-refresh
- Logout `IconButton` in AppBar

### Router Updates (`router.dart`)
- Added `/classes` → `ClassListScreen()`
- Added `/classes/:classID/students` → `StudentListScreen(classID, className)` (reads `extra`)
- `HomeScreen` updated to post-frame `context.go('/classes')` redirect

### StudentListScreen stub (`student_list_screen.dart`)
- Real stub with correct constructor: `classID` + `className` named required params
- Body placeholder text; replaced in plan 05-02

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed `update` to `updateClass` in ClassesNotifier**
- **Found during:** Task 4 — flutter analyze
- **Issue:** `ClassesNotifier.update` signature `Future<void> Function({required String classID, required String name})` is not a valid override of `AsyncNotifierBase.update` (which takes a transformer function). Analyzer error: `invalid_override`.
- **Fix:** Renamed to `updateClass` in notifier and updated the single call-site in `ClassFormSheet._submit`.
- **Files modified:** `classes_notifier.dart`, `class_form_sheet.dart`
- **Commit:** f154522

**2. [Rule 2 - Missing import] Added `flutter_riverpod` import to class_repository.dart**
- **Found during:** Task 2
- **Issue:** `Ref` type undefined — `riverpod_annotation` alone does not re-export `Ref`; `flutter_riverpod` needed.
- **Fix:** Added `import 'package:flutter_riverpod/flutter_riverpod.dart';`
- **Files modified:** `class_repository.dart`

**3. [Rule 3 - Simplification] Removed `DeleteClassDialog` widget class, kept only `showDeleteClassFlow`**
- **Found during:** Task 3
- **Issue:** The plan contained both a `DeleteClassDialog` ConsumerStatefulWidget and `showDeleteClassFlow`. The widget was redundant — `showDeleteClassFlow` already shows a complete AlertDialog inline with the warning. Keeping both would require `showDeleteClassFlow` to open `DeleteClassDialog` which itself shows a second dialog — unnecessary nesting.
- **Fix:** Kept only `showDeleteClassFlow` (the version that shows the Go-API warning message), removed the separate widget class.
- **Files modified:** `delete_class_dialog.dart`

## flutter analyze Result

```
No issues found! (ran in 2.4s)
```

## Commits

| Hash    | Message |
| ------- | ------- |
| d9257af | feat(05-01): add ClassRepository, ClassesNotifier, flutter_slidable dep |
| f154522 | feat(05-01): class list screen, CRUD, delete-warning flow |

## Self-Check

Files verified present:
- app/lib/features/classes/repository/class_repository.dart — FOUND
- app/lib/features/classes/notifier/classes_notifier.dart — FOUND
- app/lib/features/classes/screens/class_list_screen.dart — FOUND
- app/lib/features/classes/widgets/class_form_sheet.dart — FOUND
- app/lib/features/classes/widgets/delete_class_dialog.dart — FOUND
- app/lib/features/students/screens/student_list_screen.dart — FOUND

Commits verified: d9257af, f154522 — FOUND

## Self-Check: PASSED
