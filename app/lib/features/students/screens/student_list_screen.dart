import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:school_attendance/features/students/notifier/students_notifier.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';
import 'package:school_attendance/features/students/widgets/student_form_sheet.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentFormSheet(classID: classID),
    );
  }

  Future<void> _openEditSheet(
      BuildContext context, WidgetRef ref, StudentModel student) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StudentFormSheet(classID: classID, editStudent: student),
    );
  }

  Future<void> _handleSeed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Generating 30 test students...'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final created = await ref
          .read(studentsNotifierProvider(classID).notifier)
          .seed();
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Generated $created students')),
        );
      }
    } catch (_) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to generate students'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _softRemove(BuildContext context, WidgetRef ref, StudentModel student) {
    ref.read(studentsNotifierProvider(classID).notifier).softRemove(student.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${student.fullName}" removed'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          // Note: undo dismisses the snack but does NOT re-activate the student.
          // The soft-remove is already committed server-side when this snack appears.
          // True undo would require a re-activate endpoint which is out of Phase 5 scope.
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsNotifierProvider(classID));

    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'seed') {
                _handleSeed(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'seed',
                child: ListTile(
                  leading: Icon(Icons.group_add),
                  title: Text('Generate Test Students'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load students',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.read(studentsNotifierProvider(classID).notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No students yet',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Add students manually or generate test students',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openAddSheet(context, ref),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Student'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(studentsNotifierProvider(classID).notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: students.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final student = students[i];
                final isRemoved = !student.isActive;

                return Slidable(
                  key: ValueKey(student.id),
                  endActionPane: isRemoved
                      ? null
                      : ActionPane(
                          motion: const DrawerMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) =>
                                  _openEditSheet(context, ref, student),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              icon: Icons.edit,
                              label: 'Edit',
                            ),
                            SlidableAction(
                              onPressed: (_) =>
                                  _softRemove(context, ref, student),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              icon: Icons.person_remove,
                              label: 'Remove',
                            ),
                          ],
                        ),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isRemoved
                            ? Colors.grey.shade200
                            : Theme.of(context).colorScheme.secondaryContainer,
                        child: Text(
                          '#${student.rollNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isRemoved
                                ? Colors.grey
                                : Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        student.displayName,
                        style: TextStyle(
                          color: isRemoved ? Colors.grey : null,
                          fontStyle: isRemoved ? FontStyle.italic : null,
                        ),
                      ),
                      subtitle: isRemoved
                          ? const Text('Removed',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12))
                          : null,
                      trailing: isRemoved
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _openEditSheet(context, ref, student),
                            ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
