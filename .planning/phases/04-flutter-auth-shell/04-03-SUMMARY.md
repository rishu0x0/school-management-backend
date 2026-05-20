---
phase: 04-flutter-auth-shell
plan: "03"
type: summary
status: complete
---

# Phase 04-03 Summary: Auth Screens Connected to Go Backend

## Screens Implemented

### LoginScreen (`app/lib/features/auth/screens/login_screen.dart`)
- Mobile number field (10-digit, +91 prefix) + password field (show/hide toggle)
- On submit: calls `authRepository.login()` → Go `POST /auth/login`
- On success: calls `authNotifier.login()` with access_token, refresh_token, teacher_id
- Inline error display; loading spinner on submit button
- Link to RegisterScreen via `/register`

### RegisterScreen (`app/lib/features/auth/screens/register_screen.dart`)
- Fields: full name, mobile (+91 prefix), school name, password (show/hide, min 8 chars)
- On submit: calls `authRepository.sendRegistrationOtp()` → Go `POST /auth/register/send-otp`
- On success: navigates to `/otp` passing `{reqId, mobile, name, schoolName, password, isRegistration: true}` as route extra
- Inline error display; loading spinner on submit button

### OtpScreen (`app/lib/features/auth/screens/otp_screen.dart`)
- Constructor: `OtpScreen({reqId, mobile, isRegistration, name?, schoolName?, password?})`
- 6-digit OTP input with `FilteringTextInputFormatter.digitsOnly`, font size 24, letter spacing
- Auto-submits when 6 digits entered (onChanged callback)
- On submit: calls `authRepository.verifyRegistrationOtp()` → Go `POST /auth/register/verify-otp`
- On success: calls `authNotifier.login()` with returned tokens
- 60-second countdown resend timer (dart:async Timer.periodic); resend calls `authRepository.retryOtp()` → Go `POST /auth/otp/retry`
- Back button navigates to `/register`

## Auth Flows

### Registration flow
1. RegisterScreen → `POST /auth/register/send-otp` → OtpScreen
2. OtpScreen → `POST /auth/register/verify-otp` → authNotifier.login() → GoRouter redirects to `/home`

### Login flow
1. LoginScreen → `POST /auth/login` → authNotifier.login() → GoRouter redirects to `/home`

## Router Update (`app/lib/core/router/router.dart`)
- OTP route builder updated to pass `name`, `schoolName`, `password` from route extra to OtpScreen constructor

## Build & Analysis
- `build_runner build` ran successfully (2 outputs written)
- `flutter analyze` passes with **zero issues**

## Deviations
- None. All screens match plan specification exactly.
- `curly_braces_in_flow_control_structures` lint (2 info items in login_screen.dart) fixed by wrapping `if (mounted)` branches in braces.
