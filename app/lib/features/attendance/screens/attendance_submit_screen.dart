import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Stub — full implementation in plan 06-02.
class AttendanceSubmitScreen extends StatelessWidget {
  const AttendanceSubmitScreen({
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
        title: Text('$className — Submit'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Submit Attendance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Full implementation coming in plan 06-02',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
