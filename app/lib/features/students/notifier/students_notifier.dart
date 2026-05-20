import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';

part 'students_notifier.g.dart';

@riverpod
class StudentsNotifier extends _$StudentsNotifier {
  @override
  Future<List<StudentModel>> build(String classID) => _fetch();

  Future<List<StudentModel>> _fetch() =>
      ref.read(studentRepositoryProvider).list(classID);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> create({
    required String fullName,
    int? rollNumber,
    String? photoUrl,
  }) async {
    await ref.read(studentRepositoryProvider).create(
          classID: classID,
          fullName: fullName,
          rollNumber: rollNumber,
          photoUrl: photoUrl,
        );
    await refresh();
  }

  Future<void> updateStudent({
    required String studentID,
    required String fullName,
    int? rollNumber,
    String? photoUrl,
  }) async {
    await ref.read(studentRepositoryProvider).update(
          classID: classID,
          studentID: studentID,
          fullName: fullName,
          rollNumber: rollNumber,
          photoUrl: photoUrl,
        );
    await refresh();
  }

  Future<void> softRemove(String studentID) async {
    await ref.read(studentRepositoryProvider).softRemove(
          classID: classID,
          studentID: studentID,
        );
    await refresh();
  }

  Future<int> seed({int count = 30}) async {
    final created = await ref.read(studentRepositoryProvider).seed(
          classID: classID,
          count: count,
        );
    await refresh();
    return created;
  }
}
