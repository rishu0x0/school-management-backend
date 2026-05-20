---
phase: 04-flutter-auth-shell
plan: "02"
subsystem: flutter-app
tags: [flutter, riverpod, go_router, auth-state-machine, secure-storage, codegen]
dependency_graph:
  requires: [04-01]
  provides: [auth-state-machine, go-router-auth-guard, secure-storage-service, silent-refresh]
  affects: [04-03, 04-04]
tech_stack:
  added: []
  patterns:
    - Sealed class AuthState exhaustive switch in router redirect
    - RouterNotifier (ChangeNotifier) bridges Riverpod authNotifierProvider to GoRouter refresh cycle
    - silentRefresh distinguishes SocketException/DioException connection errors (→ NetworkError) from HTTP 401 (→ Unauthenticated)
    - SplashScreen calls silentRefresh via addPostFrameCallback in initState
key_files:
  created:
    - app/lib/core/auth/auth_state.dart
    - app/lib/core/auth/auth_notifier.dart
    - app/lib/core/auth/auth_notifier.g.dart
    - app/lib/core/storage/secure_storage.dart
    - app/lib/core/storage/secure_storage.g.dart
    - app/lib/core/router/router.dart
    - app/lib/core/router/router.g.dart
    - app/lib/features/auth/screens/login_screen.dart
    - app/lib/features/auth/screens/register_screen.dart
    - app/lib/features/auth/screens/otp_screen.dart
    - app/lib/features/auth/screens/splash_screen.dart
    - app/lib/features/auth/screens/no_internet_screen.dart
    - app/lib/features/home/home_screen.dart
  modified:
    - app/lib/app.dart
    - app/test/widget_test.dart
decisions:
  - Use bare Ref (not deprecated RouterRef/SecureStorageRef) in provider function signatures to eliminate deprecation warnings from riverpod_generator 2.x
  - widget_test.dart replaced default MyApp counter test with ProviderScope+App smoke test
  - SecureStorageService uses AndroidOptions(encryptedSharedPreferences: true) for Android keystore backing
metrics:
  duration: 18 min
  completed: 2026-05-20
  tasks_completed: 4
  files_created: 13
  files_modified: 2
---

# Phase 4 Plan 02: Auth State Notifier, GoRouter Auth Guard, Silent Refresh Summary

Sealed AuthState machine with 5 states, @riverpod AuthNotifier with silent refresh that correctly separates network errors from auth failures, GoRouter guard driven by RouterNotifier, and MaterialApp.router wired through routerProvider. flutter analyze: No issues found.

## What Was Built

### AuthState Machine (auth_state.dart)

Sealed class with 5 exhaustive states:

| State | Meaning | Router target |
|-------|---------|---------------|
| `AuthInitial` | App just launched, not yet checked | `/splash` |
| `AuthLoading` | silentRefresh in progress | `/splash` |
| `AuthAuthenticated(accessToken, teacherID)` | Valid session | `/home` |
| `AuthUnauthenticated` | No token or 401 from server | `/login` |
| `AuthNetworkError` | Network unreachable / timeout | `/no-internet` |

**Critical invariant:** `SocketException` and `DioExceptionType.connectionError/Timeout` → `AuthNetworkError`. Only HTTP 401 → `AuthUnauthenticated`. Teachers are never logged out by a network glitch.

### AuthNotifier (auth_notifier.dart)

`@riverpod class AuthNotifier extends _$AuthNotifier` with three public methods:

- `silentRefresh()` — reads refresh token from secure storage, POSTs `/auth/refresh` with `Authorization: Bearer <token>`, handles 200/401/network error transitions
- `login(accessToken, refreshToken, teacherID)` — saves tokens and transitions to `AuthAuthenticated`
- `logout()` — clears tokens, transitions to `AuthUnauthenticated`

Base URL injected via `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080')`.

### SecureStorageService (secure_storage.dart)

Wrapper around `flutter_secure_storage` with `AndroidOptions(encryptedSharedPreferences: true)`:

- `readAccessToken()` / `readRefreshToken()` / `readTeacherID()`
- `saveTokens(accessToken, refreshToken, teacherID)` — parallel `Future.wait`
- `clearTokens()` — parallel `Future.wait`

Exposed as `@riverpod SecureStorageService secureStorage(Ref ref)` → `secureStorageProvider`.

### Router Guard (router.dart)

`RouterNotifier extends ChangeNotifier` — listens to `authNotifierProvider` via `ref.listen`, calls `notifyListeners()` on every state change. GoRouter picks this up via `refreshListenable`.

Redirect logic (exhaustive sealed switch):

```dart
return switch (authState) {
  AuthInitial() || AuthLoading() => location == '/splash' ? null : '/splash',
  AuthAuthenticated()            => location == '/home' ? null : '/home',
  AuthUnauthenticated()          => (location == '/login' || ...) ? null : '/login',
  AuthNetworkError()             => location == '/no-internet' ? null : '/no-internet',
};
```

Routes: `/splash`, `/login`, `/register`, `/otp` (extra map), `/home`, `/no-internet`.

### app.dart

Updated from `MaterialApp(home: Scaffold(...))` to `MaterialApp.router(routerConfig: ref.watch(routerProvider))`.

### Screen Stubs

All 6 stub screens created:
- `SplashScreen` — `ConsumerStatefulWidget`; calls `silentRefresh()` in `addPostFrameCallback`
- `NoInternetScreen` — Retry button calls `silentRefresh()`
- `HomeScreen` — AppBar logout button calls `authNotifierProvider.notifier.logout()`
- `LoginScreen`, `RegisterScreen`, `OtpScreen` — placeholder text, implemented in plan 04-03

## build_runner Result

```
Built with build_runner in 8s; wrote 6 outputs.
```

Generated files: `auth_notifier.g.dart`, `secure_storage.g.dart`, `router.g.dart`.

## flutter analyze Result

```
Analyzing app...
No issues found! (ran in 2.0s)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] Deprecated Ref subclass parameter types**
- **Found during:** Task 4 — flutter analyze showed 2 info-level deprecation warnings
- **Issue:** riverpod_generator 2.x generates `RouterRef`/`SecureStorageRef` typedef aliases marked `@Deprecated('Will be removed in 3.0. Use Ref instead')`. Using them in function signatures produces `deprecated_member_use_from_same_package` info. Exit code was 1 despite no actual errors.
- **Fix:** Changed `RouterRef ref` → `Ref ref` and `SecureStorageRef ref` → `Ref ref` in both provider functions. Added `flutter_riverpod` import to `secure_storage.dart` for the `Ref` type. Regenerated `.g.dart` files.
- **Files modified:** `app/lib/core/router/router.dart`, `app/lib/core/storage/secure_storage.dart`, regenerated `.g.dart` files
- **Commit:** 166e72b

**2. [Rule 1 - Bug] Default widget_test.dart references non-existent MyApp**
- **Found during:** Task 4 — flutter analyze reported `error • The name 'MyApp' isn't a class`
- **Issue:** Flutter's default `widget_test.dart` still referenced `MyApp` from the create template. `App` is the class name in this project.
- **Fix:** Replaced entire test with a smoke test: `tester.pumpWidget(ProviderScope(child: App()))` and asserts `ProviderScope` renders without throwing.
- **Files modified:** `app/test/widget_test.dart`
- **Commit:** 166e72b

## Verification Checklist

- [x] `auth_state.dart` — sealed class with 5 states
- [x] `auth_notifier.dart` — @riverpod AuthNotifier with silentRefresh, login, logout
- [x] `auth_notifier.g.dart` — generated by build_runner
- [x] `secure_storage.dart` — FlutterSecureStorage wrapper with token CRUD
- [x] `secure_storage.g.dart` — generated by build_runner
- [x] `router.dart` — RouterNotifier + @riverpod GoRouter with sealed-switch redirect
- [x] `router.g.dart` — generated by build_runner
- [x] `app.dart` — MaterialApp.router using routerProvider
- [x] Screen stubs: login, register, otp, splash, no_internet, home — all created
- [x] `flutter analyze` — No issues found

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 + Task 2 | 6817970 | feat(04-02): auth state machine and secure storage with codegen |
| Task 3 | 98603df | feat(04-02): go_router auth guard, screen stubs, MaterialApp.router |
| Task 4 | 166e72b | feat(04-02): flutter analyze zero errors — fix Ref types and widget test |

## Self-Check: PASSED

- app/lib/core/auth/auth_state.dart: FOUND
- app/lib/core/auth/auth_notifier.dart: FOUND
- app/lib/core/auth/auth_notifier.g.dart: FOUND
- app/lib/core/storage/secure_storage.dart: FOUND
- app/lib/core/storage/secure_storage.g.dart: FOUND
- app/lib/core/router/router.dart: FOUND
- app/lib/core/router/router.g.dart: FOUND
- app/lib/app.dart: FOUND (MaterialApp.router)
- All 6 screen stubs: FOUND
- Commits 6817970, 98603df, 166e72b: FOUND
