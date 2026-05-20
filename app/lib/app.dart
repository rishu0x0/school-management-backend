import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_attendance/core/auth/auth_notifier.dart';
import 'package:school_attendance/core/auth/auth_state.dart';
import 'package:school_attendance/core/network/network_notifier.dart';
import 'package:school_attendance/core/router/router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isConnected = ref.watch(networkNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    // Show no-internet banner only when disconnected AND not already showing
    // AuthNetworkError state (which has its own error UI in the router).
    final showOfflineBanner = !isConnected && authState is! AuthNetworkError;

    return MaterialApp.router(
      title: 'School Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (showOfflineBanner)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No internet connection',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(authNotifierProvider.notifier)
                              .silentRefresh(),
                          child: const Text(
                            'RETRY',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
