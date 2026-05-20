import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/network/api_client.dart';

part 'reports_repository.g.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.classId,
    required this.month,
    required this.format,
    required this.status,
    this.fileName,
    this.signedUrl,
    this.errorMsg,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String month;
  final String format;
  final String status; // pending, processing, ready, error
  final String? fileName;
  final String? signedUrl;
  final String? errorMsg;
  final DateTime createdAt;

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as String,
        classId: json['class_id'] as String,
        month: json['month'] as String,
        format: json['format'] as String,
        status: json['status'] as String,
        fileName: json['file_name'] as String?,
        signedUrl: json['signed_url'] as String?,
        errorMsg: json['error_msg'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ReportsRepository {
  const ReportsRepository(this._dio);
  final Dio _dio;

  Future<String> generateReport({
    required String classId,
    required String month,
    required String format,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/reports/generate',
      data: {'class_id': classId, 'month': month, 'format': format},
    );
    return response.data!['report_id'] as String;
  }

  Future<List<ReportModel>> listReports() async {
    final response = await _dio.get<List<dynamic>>('/reports');
    return (response.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ReportModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> getReportStatus(String reportId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/reports/$reportId/status');
    return response.data!;
  }
}

@riverpod
ReportsRepository reportsRepository(Ref ref) =>
    ReportsRepository(ref.watch(apiClientProvider));
