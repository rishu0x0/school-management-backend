import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_attendance/features/classes/notifier/classes_notifier.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';

/// Shows delete warning fetched from Go API, then the confirmation dialog.
Future<void> showDeleteClassFlow({
  required BuildContext context,
  required WidgetRef ref,
  required ClassModel classModel,
}) async {
  // Step 1: Fetch the warning (student count) from the server
  DeleteWarning? warning;
  try {
    warning = await ref
        .read(classesNotifierProvider.notifier)
        .getDeleteWarning(classModel.id);
  } catch (_) {
    // proceed without warning
  }

  if (!context.mounted) return;

  // Step 2: Show confirmation dialog with warning
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Class?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            warning != null
                ? warning.message
                : 'This will permanently delete "${classModel.name}" and all related data.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // Step 3: Confirm delete
  try {
    await ref
        .read(classesNotifierProvider.notifier)
        .confirmDelete(classModel.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${classModel.name}" deleted')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete class')),
      );
    }
  }
}
