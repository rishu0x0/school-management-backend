import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/features/attendance/notifier/attendance_notifier.dart';
import 'package:school_attendance/features/attendance/repository/attendance_repository.dart';

class AttendanceSubmitScreen extends ConsumerStatefulWidget {
  const AttendanceSubmitScreen({
    super.key,
    required this.classID,
    required this.className,
  });
  final String classID;
  final String className;

  @override
  ConsumerState<AttendanceSubmitScreen> createState() =>
      _AttendanceSubmitScreenState();
}

class _AttendanceSubmitScreenState
    extends ConsumerState<AttendanceSubmitScreen> {
  bool _submitting = false;
  String? _error;

  String _todayIST() {
    // Use device date — assumed IST locale on teacher's device
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Attendance?'),
        content: const Text(
          'Once submitted, attendance can be edited until midnight. '
          'After midnight the record is locked permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final notifier =
          ref.read(attendanceNotifierProvider(widget.classID).notifier);
      final records = notifier.records;
      final session = await ref
          .read(attendanceRepositoryProvider)
          .submitBatch(
            classID: widget.classID,
            date: _todayIST(),
            records: records,
          );
      notifier.setSubmitted(session);

      if (mounted) {
        context.go(
          '/classes/${widget.classID}/stats',
          extra: {'className': widget.className},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Submission failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync =
        ref.watch(attendanceNotifierProvider(widget.classID));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.className} — Submit')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) {
          final presentCount = session.marks.values
              .where((s) => s == AttendanceStatus.present)
              .length;
          final absentCount = session.marks.values
              .where((s) => s == AttendanceStatus.absent)
              .length;
          final leaveCount = session.marks.values
              .where((s) => s == AttendanceStatus.leave)
              .length;

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.summarize,
                      size: 80, color: Color(0xFF1565C0)),
                  const SizedBox(height: 24),
                  Text('Ready to Submit',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '${session.students.length} students — ${_todayIST()}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryCount('Present', presentCount, Colors.green),
                      _SummaryCount('Absent', absentCount, Colors.red),
                      _SummaryCount(
                          'Leave', leaveCount, Colors.amber.shade700),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                          _submitting ? 'Submitting…' : 'Submit Attendance'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Back to Review'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}
