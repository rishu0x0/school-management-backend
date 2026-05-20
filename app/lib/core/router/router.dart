import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/auth/auth_notifier.dart';
import 'package:school_attendance/core/auth/auth_state.dart';
import 'package:school_attendance/features/auth/screens/login_screen.dart';
import 'package:school_attendance/features/auth/screens/no_internet_screen.dart';
import 'package:school_attendance/features/auth/screens/otp_screen.dart';
import 'package:school_attendance/features/auth/screens/register_screen.dart';
import 'package:school_attendance/features/auth/screens/splash_screen.dart';
import 'package:school_attendance/features/home/home_screen.dart';

part 'router.g.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);
    final location = state.matchedLocation;

    return switch (authState) {
      AuthInitial() || AuthLoading() =>
        location == '/splash' ? null : '/splash',
      AuthAuthenticated() => location == '/home' ? null : '/home',
      AuthUnauthenticated() =>
        (location == '/login' ||
                location == '/register' ||
                location == '/otp')
            ? null
            : '/login',
      AuthNetworkError() =>
        location == '/no-internet' ? null : '/no-internet',
    };
  }
}

@riverpod
GoRouter router(Ref ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            reqId: extra['reqId'] as String? ?? '',
            mobile: extra['mobile'] as String? ?? '',
            isRegistration: extra['isRegistration'] as bool? ?? true,
            name: extra['name'] as String?,
            schoolName: extra['schoolName'] as String?,
            password: extra['password'] as String?,
          );
        },
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/no-internet', builder: (_, __) => const NoInternetScreen()),
    ],
  );
}
