import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/network/api_client.dart';

part 'attendance_repository.g.dart';

enum AttendanceStatus { present, absent, leave }

extension AttendanceStatusExt on AttendanceStatus {
  String get value => name; // 'present' | 'absent' | 'leave'
}

AttendanceStatus statusFromString(String s) {
  switch (s) {
    case 'present':
      return AttendanceStatus.present;
    case 'leave':
      return AttendanceStatus.leave;
    default:
      return AttendanceStatus.absent;
  }
}

class AttendanceRecord {
  const AttendanceRecord({required this.studentId, required this.status});
  final String studentId;
  final AttendanceStatus status;
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.date,
    required this.records,
  });
  final String id;
  final String classId;
  final String date;
  final List<AttendanceRecord> records;

  factory AttendanceSession.fromJson(Map<String, dynamic> j) {
    final rawRecords = j['records'] as List? ?? [];
    return AttendanceSession(
      id: j['id'] as String,
      classId: j['class_id'] as String,
      date: j['date'] as String,
      records: rawRecords
          .map((r) => AttendanceRecord(
                studentId: r['student_id'] as String,
                status: statusFromString(r['status'] as String),
              ))
          .toList(),
    );
  }
}

@riverpod
AttendanceRepository attendanceRepository(Ref ref) =>
    AttendanceRepository(ref.watch(apiClientProvider));

class AttendanceRepository {
  AttendanceRepository(this._dio);
  final Dio _dio;

  /// Returns null if no session exists for the given date.
  Future<AttendanceSession?> getByDate({
    required String classID,
    required String date,
  }) async {
    final res = await _dio.get(
      '/classes/$classID/attendance',
      queryParameters: {'date': date},
    );
    final data = res.data as Map<String, dynamic>;
    final session = data['session'];
    if (session == null) return null;
    return AttendanceSession.fromJson(session as Map<String, dynamic>);
  }

  Future<AttendanceSession> submitBatch({
    required String classID,
    required String date,
    required List<AttendanceRecord> records,
  }) async {
    final res = await _dio.post('/classes/$classID/attendance', data: {
      'date': date,
      'records': records
          .map((r) => {'student_id': r.studentId, 'status': r.status.value})
          .toList(),
    });
    final data = res.data as Map<String, dynamic>;
    return AttendanceSession.fromJson(
        data['session'] as Map<String, dynamic>? ?? data);
  }

  Future<AttendanceSession> editRecords({
    required String classID,
    required String sessionID,
    required List<AttendanceRecord> records,
  }) async {
    final res = await _dio.put(
      '/classes/$classID/attendance/$sessionID',
      data: {
        'records': records
            .map((r) => {'student_id': r.studentId, 'status': r.status.value})
            .toList(),
      },
    );
    final data = res.data as Map<String, dynamic>;
    return AttendanceSession.fromJson(
        data['session'] as Map<String, dynamic>? ?? data);
  }
}
