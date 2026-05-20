import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/network/api_client.dart';
import 'package:school_attendance/features/classes/repository/class_repository.dart';

part 'student_repository.g.dart';

class StudentModel {
  const StudentModel({
    required this.id,
    required this.classId,
    required this.fullName,
    required this.rollNumber,
    required this.isActive,
    this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String fullName;
  final int rollNumber;
  final bool isActive;
  final String? photoUrl;
  final String createdAt;

  factory StudentModel.fromJson(Map<String, dynamic> j) => StudentModel(
        id: j['id'] as String,
        classId: j['class_id'] as String,
        fullName: j['full_name'] as String,
        rollNumber: j['roll_number'] as int,
        isActive: j['is_active'] as bool? ?? true,
        photoUrl: j['photo_url'] as String?,
        createdAt: j['created_at'] as String,
      );

  String get displayName => isActive ? fullName : '(Removed)';
}

@riverpod
StudentRepository studentRepository(Ref ref) =>
    StudentRepository(ref.watch(apiClientProvider));

class StudentRepository {
  StudentRepository(this._dio);
  final Dio _dio;

  Future<List<StudentModel>> list(String classID) async {
    final res = await _dio.get('/classes/$classID/students');
    return (res.data['students'] as List)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudentModel> create({
    required String classID,
    required String fullName,
    int? rollNumber,
    String? photoUrl,
  }) async {
    try {
      final res = await _dio.post('/classes/$classID/students', data: {
        'full_name': fullName,
        if (rollNumber != null) 'roll_number': rollNumber,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
      });
      return StudentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Failed to add student',
        );
      }
      rethrow;
    }
  }

  Future<StudentModel> update({
    required String classID,
    required String studentID,
    required String fullName,
    int? rollNumber,
    String? photoUrl,
  }) async {
    try {
      final res = await _dio.put(
        '/classes/$classID/students/$studentID',
        data: {
          'full_name': fullName,
          if (rollNumber != null) 'roll_number': rollNumber,
          if (photoUrl != null) 'photo_url': photoUrl,
        },
      );
      return StudentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Failed to update student',
        );
      }
      rethrow;
    }
  }

  Future<void> softRemove({
    required String classID,
    required String studentID,
  }) async {
    await _dio.delete('/classes/$classID/students/$studentID');
  }

  Future<int> seed({required String classID, int count = 30}) async {
    final res = await _dio.post(
      '/classes/$classID/students/seed',
      data: {'count': count},
    );
    return (res.data as Map<String, dynamic>)['created'] as int? ?? count;
  }
}
