import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/network/api_client.dart';

part 'class_repository.g.dart';

class ClassModel {
  const ClassModel({
    required this.id,
    required this.name,
    this.section,
    this.subject,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? section;
  final String? subject;
  final String createdAt;

  factory ClassModel.fromJson(Map<String, dynamic> j) => ClassModel(
        id: j['id'] as String,
        name: j['name'] as String,
        section: j['section'] as String?,
        subject: j['subject'] as String?,
        createdAt: j['created_at'] as String,
      );
}

class DeleteWarning {
  const DeleteWarning({required this.studentCount, required this.message});
  final int studentCount;
  final String message;
}

class ApiException implements Exception {
  const ApiException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

@riverpod
ClassRepository classRepository(Ref ref) =>
    ClassRepository(ref.watch(apiClientProvider));

class ClassRepository {
  ClassRepository(this._dio);
  final Dio _dio;

  Future<List<ClassModel>> list() async {
    final res = await _dio.get('/classes');
    final classes = (res.data['classes'] as List)
        .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return classes;
  }

  Future<ClassModel> create({
    required String name,
    String? section,
    String? subject,
  }) async {
    try {
      final res = await _dio.post('/classes', data: {
        'name': name,
        if (section != null && section.isNotEmpty) 'section': section,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });
      return ClassModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Failed to create class',
        );
      }
      rethrow;
    }
  }

  Future<ClassModel> update({
    required String classID,
    required String name,
  }) async {
    try {
      final res = await _dio.put('/classes/$classID', data: {'name': name});
      return ClassModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw ApiException(
          data['error'] as String? ?? 'unknown',
          data['message'] as String? ?? 'Failed to update class',
        );
      }
      rethrow;
    }
  }

  /// Returns DeleteWarning if confirm=false (server sends warning).
  /// Returns null if confirm=true (class deleted).
  Future<DeleteWarning?> delete({
    required String classID,
    required bool confirm,
  }) async {
    final res = await _dio.delete(
      '/classes/$classID',
      queryParameters: confirm ? {'confirm': 'true'} : {},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['confirm_required'] == true) {
      final w = data['warning'] as Map<String, dynamic>;
      return DeleteWarning(
        studentCount: w['student_count'] as int,
        message: w['message'] as String,
      );
    }
    return null;
  }
}
