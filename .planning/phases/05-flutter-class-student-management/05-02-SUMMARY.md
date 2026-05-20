---
phase: 05-flutter-class-student-management
plan: "02"
subsystem: flutter-app
tags: [flutter, riverpod, student-management, dio, flutter_slidable, soft-remove]
dependency_graph:
  requires: [05-01, 03-go-crud-api]
  provides: [student-repository, students-notifier, student-list-screen, student-form-sheet]
  affects: [class-list-screen, attendance-screen]
tech_stack:
  added: []
  patterns: [AsyncNotifier-family, ConsumerWidget, ConsumerStatefulWidget, showModalBottomSheet, Slidable, RefreshIndicator, SnackBar]
key_files:
  created:
    - app/lib/features/students/repository/student_repository.dart
    - app/lib/features/students/repository/student_repository.g.dart
    - app/lib/features/students/notifier/students_notifier.dart
    - app/lib/features/students/notifier/students_notifier.g.dart
    - app/lib/features/students/widgets/student_form_sheet.dart
  modified:
    - app/lib/features/students/screens/student_list_screen.dart
decisions:
  - Renamed StudentsNotifier.update to updateStudent to avoid AsyncNotifierBase.update collision (same pattern as 05-01 ClassesNotifier)
  - Undo SnackBar only dismisses snack — does NOT re-activate student; soft-remove is server-side committed at swipe time; comment in code is explicit about this
metrics:
  duration: ~15min
  completed_date: 2026-05-20
  tasks_completed: 4
  files_created: 5
  files_modified: 1
---

# Phase 5 Plan 02: Student List Screen with CRUD and Soft-Remove Summary

**One-liner:** Full student management feature with Riverpod family notifier, Dio repository, Slidable swipe-to-remove with undo SnackBar, and grey-italic display for soft-removed students.

## Features Implemented

### StudentModel (`student_repository.dart`)
- Immutable data class: id, classId, fullName, rollNumber, isActive, photoUrl, createdAt
- `displayName` getter: returns `fullName` when active, `'(Removed)'` when inactive
- `fromJson` factory with safe bool cast (`as bool? ?? true`)

### StudentRepository (`student_repository.dart`)
- `list(classID)` — GET /classes/{classID}/students, maps `{students: [...]}` to `List<StudentModel>`
- `create()` — POST /classes/{classID}/students with fullName + optional rollNumber/photoUrl; throws `ApiException` on 4xx
- `update()` — PUT /classes/{classID}/students/{studentID}; throws `ApiException` on 4xx
- `softRemove()` — DELETE /classes/{classID}/students/{studentID}; sets is_active=false server-side
- Imports `ApiException` from `class_repository.dart` — not redefined

### StudentsNotifier (`students_notifier.dart`)
- `@riverpod class StudentsNotifier extends _$StudentsNotifier`
- Family pattern: `build(String classID)` — `classID` accessible as `this.classID` throughout
- Generated provider: `studentsNotifierProvider(classID)` (family)
- `refresh()` — sets AsyncLoading then AsyncValue.guard
- `create()` / `updateStudent()` / `softRemove()` — delegate to repo then refresh
- `updateStudent` (not `update`) to avoid collision with `AsyncNotifierBase.update`

### StudentFormSheet (`student_form_sheet.dart`)
- Create mode: full_name (required, validated) + roll_number (optional, digits only)
- Edit mode: pre-fills name and roll number from `editStudent`
- Inline `ApiException` error display below form fields
- Loading spinner on submit button; `autofocus: true` on name field
- Calls `notifier.updateStudent` (not `update`) in edit mode

### StudentListScreen (`student_list_screen.dart`)
- Replaces the `StatelessWidget` stub from 05-01
- `ConsumerWidget` watching `studentsNotifierProvider(classID)`
- Loading state: centered `CircularProgressIndicator`
- Error state: icon + message + Retry button
- Empty state: people icon + prompt + inline "Add Student" `FilledButton.icon`
- Populated list: `ListView.separated` inside `RefreshIndicator`
  - Each row wrapped in `Slidable` with `endActionPane` (Edit in blue, Remove in orange)
  - Removed students: no slide actions, grey avatar, italic grey `displayName`, "Removed" subtitle
  - Active students: slidable Edit + Remove, `IconButton` trailing edit shortcut
- `FloatingActionButton.extended` for add student
- `PopupMenuButton` with "Generate Test Students" stub (implemented in 05-03)
- Soft-remove triggers SnackBar for 3s; Undo action only dismisses the snack (server-side delete already committed)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed `update` to `updateStudent` in StudentsNotifier**
- **Found during:** Task 4 — flutter analyze
- **Issue:** `StudentsNotifier.update` signature `Future<void> Function({required String fullName, ...})` is not a valid override of `AsyncNotifierBase.update` (which takes a transformer function). Analyzer error: `invalid_override`. Same pattern as the 05-01 `ClassesNotifier.update` → `updateClass` fix.
- **Fix:** Renamed method to `updateStudent` in notifier; updated the single call-site in `StudentFormSheet._submit`.
- **Files modified:** `students_notifier.dart`, `student_form_sheet.dart`
- **Commit:** d257337

## flutter analyze Result

```
No issues found! (ran in 2.4s)
```

## Commits

| Hash    | Message |
| ------- | ------- |
| d257337 | feat(05-02): student list screen with CRUD and soft-remove |

## Self-Check

Files verified present:
- app/lib/features/students/repository/student_repository.dart — FOUND
- app/lib/features/students/repository/student_repository.g.dart — FOUND
- app/lib/features/students/notifier/students_notifier.dart — FOUND
- app/lib/features/students/notifier/students_notifier.g.dart — FOUND
- app/lib/features/students/widgets/student_form_sheet.dart — FOUND
- app/lib/features/students/screens/student_list_screen.dart — FOUND (stub replaced)

Commits verified: d257337 — FOUND

## Self-Check: PASSED
