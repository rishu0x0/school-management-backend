import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stub — full implementation in plan 06-02.
class AttendanceSummaryScreen extends StatelessWidget {
  const AttendanceSummaryScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$className — Summary'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.summarize_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Attendance Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Full implementation coming in plan 06-02',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(
                '/classes/$classID/attendance/submit',
                extra: {'className': className},
              ),
              icon: const Icon(Icons.send),
              label: const Text('Submit Attendance'),
            ),
          ],
        ),
      ),
    );
  }
}
