import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/core/auth/auth_notifier.dart';
import 'package:school_attendance/features/classes/notifier/classes_notifier.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';
import 'package:school_attendance/features/classes/widgets/class_form_sheet.dart';
import 'package:school_attendance/features/classes/widgets/delete_class_dialog.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ClassFormSheet(),
    );
  }

  Future<void> _openEditSheet(
      BuildContext context, WidgetRef ref, ClassModel cls) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClassFormSheet(editClass: cls),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load classes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.read(classesNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No classes yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to create your first class',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openCreateSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Class'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(classesNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final cls = classes[i];
                final subtitle = [cls.section, cls.subject]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' • ');
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        cls.name[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      cls.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        subtitle.isNotEmpty ? Text(subtitle) : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await _openEditSheet(context, ref, cls);
                        } else if (action == 'delete') {
                          await showDeleteClassFlow(
                            context: context,
                            ref: ref,
                            classModel: cls,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push(
                      '/classes/${cls.id}/students',
                      extra: {'className': cls.name},
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
