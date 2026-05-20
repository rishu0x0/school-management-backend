import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';

part 'classes_notifier.g.dart';

@riverpod
class ClassesNotifier extends _$ClassesNotifier {
  @override
  Future<List<ClassModel>> build() => _fetch();

  Future<List<ClassModel>> _fetch() =>
      ref.read(classRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> create({
    required String name,
    String? section,
    String? subject,
  }) async {
    await ref.read(classRepositoryProvider).create(
          name: name,
          section: section,
          subject: subject,
        );
    await refresh();
  }

  Future<void> update({
    required String classID,
    required String name,
  }) async {
    await ref.read(classRepositoryProvider).update(
          classID: classID,
          name: name,
        );
    await refresh();
  }

  Future<DeleteWarning?> getDeleteWarning(String classID) =>
      ref.read(classRepositoryProvider).delete(classID: classID, confirm: false);

  Future<void> confirmDelete(String classID) async {
    await ref.read(classRepositoryProvider).delete(
          classID: classID,
          confirm: true,
        );
    await refresh();
  }
}
