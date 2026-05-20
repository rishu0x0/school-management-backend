---
phase: 04-flutter-auth-shell
plan: "04"
subsystem: flutter-network
tags: [dio, jwt-refresh, queued-interceptor, connectivity-plus, riverpod, flutter]
dependency_graph:
  requires:
    - 04-02  # AuthNotifier silentRefresh/login/logout, SecureStorageService
    - 04-03  # Auth screens, router guard
  provides:
    - Dio singleton with QueuedInterceptorsWrapper JWT refresh
    - NetworkNotifier connectivity bool state
    - Offline banner overlay in app.dart
  affects:
    - All future feature plans that use apiClientProvider for HTTP calls
tech_stack:
  added:
    - dio QueuedInterceptorsWrapper (queues concurrent 401s, prevents duplicate refresh)
    - connectivity_plus ^6.1.3 stream listener (List<ConnectivityResult>)
  patterns:
    - Riverpod @riverpod code-gen with bare Ref (not deprecated typed refs)
    - Fresh Dio for refresh call and retry — avoids re-entering interceptor chain
key_files:
  created:
    - app/lib/core/network/api_client.dart
    - app/lib/core/network/api_client.g.dart
    - app/lib/core/network/network_notifier.dart
    - app/lib/core/network/network_notifier.g.dart
  modified:
    - app/lib/app.dart
decisions:
  - "QueuedInterceptorsWrapper chosen over plain Interceptor — queues parallel 401 requests so only one /auth/refresh call fires; others retry after refresh completes"
  - "Fresh Dio (not _ref.read(apiClientProvider).fetch()) used for retry — avoids re-entering the interceptor chain which would cause a second refresh attempt"
  - "Fresh Dio also used for /auth/refresh POST — keeps refresh call completely out of the interceptor to prevent infinite loops"
  - "NetworkNotifier returns true on init (assume connected) — connectivity_plus stream corrects state if actually offline"
  - "Offline banner is a Stack overlay, not a route redirect — brief connectivity drops do not log teachers out"
  - "Banner suppressed when authState is AuthNetworkError — that state has its own UI in the router guard, banner would be redundant"
  - "connectivity_plus v6+ emits List<ConnectivityResult> not ConnectivityResult — listener uses .any() to check for any non-none result"
metrics:
  duration: "4 min"
  completed: "2026-05-20"
  tasks_completed: 3
  files_created: 4
  files_modified: 1
---

# Phase 4 Plan 04: Dio JWT Refresh Interceptor and Network Overlay Summary

**One-liner:** Dio singleton with QueuedInterceptorsWrapper that silently refreshes JWTs on 401 (queuing concurrent requests) and a connectivity_plus-backed offline banner overlay in app.dart.

## What Was Built

### Task 1: ApiClient with QueuedInterceptorsWrapper

`app/lib/core/network/api_client.dart` — `@riverpod` Dio factory with `_JwtInterceptor`:

- **onRequest**: reads `access_token` from `SecureStorageService`, attaches as `Authorization: Bearer` header
- **onError(401)**: reads `refresh_token`, POSTs `/auth/refresh` with a fresh Dio (not the intercepted instance), on HTTP 200 saves new tokens + calls `authNotifier.login()` + retries original request via another fresh Dio
- **Refresh 401 or any exception**: calls `authNotifier.logout()`, propagates original error
- **QueuedInterceptorsWrapper**: concurrent 401 errors are queued — only one refresh fires, others retry after it completes

Key implementation detail: the retry uses a completely fresh `Dio` instance rather than `_ref.read(apiClientProvider).fetch()`. This prevents the retry from re-entering `_JwtInterceptor` and triggering a second refresh call.

### Task 2: NetworkNotifier + app.dart offline banner

`app/lib/core/network/network_notifier.dart` — `@riverpod class NetworkNotifier` that:
- Subscribes to `Connectivity().onConnectivityChanged` (emits `List<ConnectivityResult>` in connectivity_plus v6+)
- Converts to `bool` via `.any((r) => r != ConnectivityResult.none)`
- Initializes to `true` (assume connected); stream corrects if offline
- Cancels subscription on `ref.onDispose`

`app/lib/app.dart` updated with:
- `ref.watch(networkNotifierProvider)` for connectivity state
- `ref.watch(authNotifierProvider)` to suppress banner when already in `AuthNetworkError`
- `MaterialApp.router` `builder:` wraps content in `Stack` with a red `Positioned` banner at the top

### Task 3: build_runner + flutter analyze

- `build_runner build --delete-conflicting-outputs`: generated `api_client.g.dart` and `network_notifier.g.dart` (6 outputs written)
- `flutter analyze`: **No issues found** (0 errors, 0 warnings)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected retry approach from .fetch() to fresh Dio**
- **Found during:** Task 1 implementation review (plan noted this as a CRITICAL fix)
- **Issue:** Plan's task body used `_ref.read(apiClientProvider).fetch(err.requestOptions)` — `fetch` is an internal Dio method not accessible on the public interface, and using the same Dio instance re-enters `_JwtInterceptor` causing a second refresh
- **Fix:** Used fresh `Dio` instance for retry with `retryDio.request(path, data, queryParameters, options)` as specified in the CRITICAL note in the prompt
- **Files modified:** `api_client.dart`
- **Commit:** d69da00

None other — plan executed cleanly.

## flutter analyze Result

```
Analyzing app...
No issues found! (ran in 2.5s)
```

## Phase 4 Complete Declaration

All four plans of Phase 4 (Flutter Auth Shell) are complete:

| Plan | Name | Status |
|------|------|--------|
| 04-01 | Project scaffold, dependencies, analysis_options | Done |
| 04-02 | AuthState machine, AuthNotifier, SecureStorage, RouterNotifier, screen stubs | Done |
| 04-03 | Auth screens (OTP send/verify, PIN set/verify, Home) | Done |
| 04-04 | Dio JWT refresh interceptor, NetworkNotifier, offline overlay | Done |

The Flutter auth shell is complete: OTP login flow, JWT token storage, silent refresh, auth-guarded routing, queued JWT interceptor for all API calls, and connectivity-aware offline banner — all wired together with zero analysis errors.

## Self-Check: PASSED

All files confirmed present on disk. Commit d69da00 confirmed in git log.
