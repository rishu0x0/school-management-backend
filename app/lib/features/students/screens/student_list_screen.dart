import 'package:flutter/material.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(className)),
      body: const Center(child: Text('Students — implemented in plan 05-02')),
    );
  }
}
