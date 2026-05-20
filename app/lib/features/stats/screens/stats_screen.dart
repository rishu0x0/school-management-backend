import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stub — full implementation in a later phase.
class StatsScreen extends StatelessWidget {
  const StatsScreen({
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
        title: Text('$className — Stats'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Attendance Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Full implementation coming in a later phase',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
