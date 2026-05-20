import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/features/attendance/notifier/attendance_notifier.dart';
import 'package:school_attendance/features/attendance/repository/attendance_repository.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';

class AttendanceSummaryScreen extends ConsumerWidget {
  const AttendanceSummaryScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  Future<void> _showStatusPicker(
    BuildContext context,
    WidgetRef ref,
    StudentModel student,
    AttendanceStatus current,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _StatusPickerSheet(
        student: student,
        current: current,
        onSelected: (status) {
          ref
              .read(attendanceNotifierProvider(classID).notifier)
              .changeStatus(student.id, status);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(attendanceNotifierProvider(classID));

    return Scaffold(
      appBar: AppBar(
        title: Text('$className — Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) {
          final marks = session.marks;
          final students = session.students;

          final presentCount =
              marks.values.where((s) => s == AttendanceStatus.present).length;
          final absentCount =
              marks.values.where((s) => s == AttendanceStatus.absent).length;
          final leaveCount =
              marks.values.where((s) => s == AttendanceStatus.leave).length;
          final unmarked = students.length - marks.length;

          return Column(
            children: [
              // Aggregate counts
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CountChip(
                        label: 'Present',
                        count: presentCount,
                        color: Colors.green),
                    _CountChip(
                        label: 'Absent', count: absentCount, color: Colors.red),
                    _CountChip(
                        label: 'Leave',
                        count: leaveCount,
                        color: Colors.amber.shade700),
                    if (unmarked > 0)
                      _CountChip(
                          label: 'Pending',
                          count: unmarked,
                          color: Colors.grey),
                  ],
                ),
              ),

              // Student list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final student = students[i];
                    final status = marks[student.id];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(
                            '#${student.rollNumber}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(student.fullName),
                        trailing: status != null
                            ? GestureDetector(
                                onTap: () => _showStatusPicker(
                                    context, ref, student, status),
                                child: _StatusChip(status: status),
                              )
                            : const Chip(
                                label: Text('—',
                                    style: TextStyle(color: Colors.grey)),
                                backgroundColor: Colors.transparent,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: sessionAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (session) {
              final allMarked =
                  session.marks.length == session.students.length;
              return FilledButton.icon(
                onPressed: allMarked
                    ? () => context.push(
                          '/classes/$classID/attendance/submit',
                          extra: {'className': className},
                        )
                    : null,
                icon: const Icon(Icons.send),
                label: Text(
                  allMarked
                      ? 'Submit Attendance'
                      : 'Mark all students first (${session.students.length - session.marks.length} remaining)',
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('Present', Colors.green),
      AttendanceStatus.absent => ('Absent', Colors.red),
      AttendanceStatus.leave => ('Leave', Colors.amber.shade700),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatusPickerSheet extends StatelessWidget {
  const _StatusPickerSheet({
    required this.student,
    required this.current,
    required this.onSelected,
  });

  final StudentModel student;
  final AttendanceStatus current;
  final ValueChanged<AttendanceStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change status for ${student.fullName}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          for (final status in AttendanceStatus.values)
            ListTile(
              leading: Icon(
                switch (status) {
                  AttendanceStatus.present => Icons.check_circle,
                  AttendanceStatus.absent => Icons.cancel,
                  AttendanceStatus.leave => Icons.event_busy,
                },
                color: switch (status) {
                  AttendanceStatus.present => Colors.green,
                  AttendanceStatus.absent => Colors.red,
                  AttendanceStatus.leave => Colors.amber.shade700,
                },
              ),
              title: Text(
                  status.name[0].toUpperCase() + status.name.substring(1)),
              selected: status == current,
              onTap: () => onSelected(status),
            ),
        ],
      ),
    );
  }
}
