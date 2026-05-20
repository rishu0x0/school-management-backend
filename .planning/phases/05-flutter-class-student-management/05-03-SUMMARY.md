---
phase: 05-flutter-class-student-management
plan: "03"
subsystem: flutter-student-management
tags: [flutter, riverpod, supabase-storage, image-picker, seed]
dependency_graph:
  requires: [05-02]
  provides: [seed-flow, photo-upload]
  affects: [StudentRepository, StudentsNotifier, StudentListScreen, StudentFormSheet]
tech_stack:
  added: [supabase_flutter ^2.8.4, image_picker ^1.1.2, cached_network_image ^3.4.1]
  patterns: [Supabase.initialize() with String.fromEnvironment, two-step create-then-upload for new student photos, graceful fallback on storage error]
key_files:
  modified:
    - app/pubspec.yaml
    - app/lib/main.dart
    - app/lib/features/students/repository/student_repository.dart
    - app/lib/features/students/notifier/students_notifier.dart
    - app/lib/features/students/screens/student_list_screen.dart
    - app/lib/features/students/widgets/student_form_sheet.dart
decisions:
  - Supabase initialized with empty String.fromEnvironment defaults — storage calls fail gracefully when SUPABASE_URL not provided at runtime
  - Two-step CREATE then upload — student ID needed for storage path; create() called first without photo, then upload(), then update() with URL
  - _uploadPhoto() catches all exceptions and returns existingPhotoUrl as fallback — no crash when student-photos bucket not configured
  - _handleSeed() as instance method on ConsumerWidget (not StatefulWidget) — seed is a one-shot async call, no widget state needed
metrics:
  duration: "~10 min"
  completed: "2026-05-20"
  tasks: 4
  files_changed: 6
---

# Phase 5 Plan 03: Seed Flow and Photo Upload Summary

**One-liner:** supabase_flutter + image_picker wired into student management — seed 30 students in one tap, optional photo upload with graceful Supabase Storage fallback.

## What Was Built

### Task 1: Dependencies and Supabase init
Added `supabase_flutter ^2.8.4`, `image_picker ^1.1.2`, `cached_network_image ^3.4.1` to `pubspec.yaml`. Updated `main()` to async with `Supabase.initialize()` reading `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `String.fromEnvironment` — empty defaults mean the client initialises without crashing when env vars are absent.

**Commits:** `545d66e`

### Task 2: seed() in Repository and Notifier
`StudentRepository.seed()` POSTs to `/classes/{classID}/students/seed` with `{"count": 30}` and returns the `created` field. `StudentsNotifier.seed()` delegates to the repository, calls `refresh()`, and returns the count to the caller.

**Commits:** `8e3d8b6`

### Task 3: Seed button wired in StudentListScreen
Added `_handleSeed(BuildContext, WidgetRef)` instance method on the `ConsumerWidget`. Replaces the 05-02 placeholder SnackBar. Shows a 30-second "Generating..." SnackBar, hides it on completion, then shows "Generated N students" or a red error SnackBar. `context.mounted` checked before showing result SnackBars.

**Commits:** `dbd480b`

### Task 4: Photo picker in StudentFormSheet
Added `_pickedPhoto` (File?) and `_existingPhotoUrl` (String?) state fields. `initState()` reads `editStudent?.photoUrl`. `_pickPhoto()` opens the gallery via ImagePicker at 512x512 / quality 80. `_uploadPhoto()` uploads to `student-photos/{classID}/{studentID}.jpg` with `upsert: true` and returns the public URL — any exception returns the existing URL (graceful fallback). CircleAvatar photo picker placed above the name field; shows `FileImage` / `NetworkImage` / placeholder icon. CREATE flow: `repository.create()` first to get server ID, then `_uploadPhoto()`, then `repository.update()` with URL, then `notifier.refresh()`. EDIT flow: `_uploadPhoto()` then `notifier.updateStudent()` with `photoUrl`.

**Commits:** `588e187`

## Verification

- `flutter pub get` — clean, 0 dependency conflicts
- `build_runner build --delete-conflicting-outputs` — 0 errors both runs
- `flutter analyze` — **No issues found**

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

Files exist:
- app/pubspec.yaml — FOUND (supabase_flutter, image_picker, cached_network_image)
- app/lib/main.dart — FOUND (Supabase.initialize)
- app/lib/features/students/repository/student_repository.dart — FOUND (seed method)
- app/lib/features/students/notifier/students_notifier.dart — FOUND (seed method)
- app/lib/features/students/screens/student_list_screen.dart — FOUND (_handleSeed wired)
- app/lib/features/students/widgets/student_form_sheet.dart — FOUND (photo picker)

Commits exist: 545d66e, 8e3d8b6, dbd480b, 588e187 — all confirmed in git log.
