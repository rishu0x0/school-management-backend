import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirect immediately to /classes — home is now the class list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/classes');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
