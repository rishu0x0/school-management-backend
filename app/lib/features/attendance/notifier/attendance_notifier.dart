import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/features/attendance/repository/attendance_repository.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';

part 'attendance_notifier.g.dart';

class AttendanceSession2 {
  AttendanceSession2({
    required this.students,
    required this.marks,
    required this.currentIndex,
    this.submittedSession,
  });

  final List<StudentModel> students;
  final Map<String, AttendanceStatus> marks;
  final int currentIndex;
  final AttendanceSession? submittedSession;

  bool get allMarked => currentIndex >= students.length;
  int get remaining => students.length - currentIndex;

  AttendanceSession2 copyWith({
    List<StudentModel>? students,
    Map<String, AttendanceStatus>? marks,
    int? currentIndex,
    AttendanceSession? submittedSession,
  }) =>
      AttendanceSession2(
        students: students ?? this.students,
        marks: marks ?? this.marks,
        currentIndex: currentIndex ?? this.currentIndex,
        submittedSession: submittedSession ?? this.submittedSession,
      );
}

@riverpod
class AttendanceNotifier extends _$AttendanceNotifier {
  @override
  Future<AttendanceSession2> build(String classID) async {
    final students = await ref.read(studentRepositoryProvider).list(classID);
    final active = students.where((s) => s.isActive).toList();
    return AttendanceSession2(
      students: active,
      marks: {},
      currentIndex: 0,
    );
  }

  void mark(String studentId, AttendanceStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;
    final newMarks = Map<String, AttendanceStatus>.from(current.marks)
      ..[studentId] = status;
    state = AsyncData(current.copyWith(
      marks: newMarks,
      currentIndex: current.currentIndex + 1,
    ));
  }

  void undo() {
    final current = state.valueOrNull;
    if (current == null || current.currentIndex == 0) return;
    final prevStudent = current.students[current.currentIndex - 1];
    final newMarks = Map<String, AttendanceStatus>.from(current.marks)
      ..remove(prevStudent.id);
    state = AsyncData(current.copyWith(
      marks: newMarks,
      currentIndex: current.currentIndex - 1,
    ));
  }

  void changeStatus(String studentId, AttendanceStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;
    final newMarks = Map<String, AttendanceStatus>.from(current.marks)
      ..[studentId] = status;
    state = AsyncData(current.copyWith(marks: newMarks));
  }

  void setSubmitted(AttendanceSession session) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(submittedSession: session));
  }

  List<AttendanceRecord> get records {
    final current = state.valueOrNull;
    if (current == null) return [];
    return current.marks.entries
        .map((e) => AttendanceRecord(studentId: e.key, status: e.value))
        .toList();
  }
}
