import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/core/network/api_client.dart';

part 'stats_repository.g.dart';

class TodayStats {
  const TodayStats({
    required this.classId,
    required this.date,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
    required this.totalCount,
    required this.submitted,
  });
  final String classId;
  final String date;
  final int presentCount;
  final int absentCount;
  final int leaveCount;
  final int totalCount;
  final bool submitted;

  factory TodayStats.fromJson(Map<String, dynamic> j) => TodayStats(
        classId: j['class_id'] as String,
        date: j['date'] as String,
        presentCount: j['present_count'] as int,
        absentCount: j['absent_count'] as int,
        leaveCount: j['leave_count'] as int,
        totalCount: j['total_count'] as int,
        submitted: j['submitted'] as bool,
      );
}

class StudentStat {
  const StudentStat({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    required this.attendancePercent,
  });
  final String studentId;
  final String fullName;
  final int rollNumber;
  final double attendancePercent;

  factory StudentStat.fromJson(Map<String, dynamic> j) => StudentStat(
        studentId: j['student_id'] as String,
        fullName: j['full_name'] as String,
        rollNumber: j['roll_number'] as int,
        attendancePercent: (j['attendance_percentage'] as num).toDouble(),
      );
}

class MonthlyStats {
  const MonthlyStats({
    required this.classId,
    required this.month,
    required this.daysRecorded,
    required this.averagePercentage,
    required this.belowThreshold,
  });
  final String classId;
  final String month;
  final int daysRecorded;
  final double averagePercentage;
  final List<StudentStat> belowThreshold;

  factory MonthlyStats.fromJson(Map<String, dynamic> j) => MonthlyStats(
        classId: j['class_id'] as String,
        month: j['month'] as String,
        daysRecorded: j['days_recorded'] as int,
        averagePercentage: (j['average_percentage'] as num).toDouble(),
        belowThreshold: (j['below_threshold'] as List)
            .map((e) => StudentStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@riverpod
StatsRepository statsRepository(Ref ref) =>
    StatsRepository(ref.watch(apiClientProvider));

class StatsRepository {
  StatsRepository(this._dio);
  final Dio _dio;

  Future<TodayStats> getToday(String classID) async {
    final res = await _dio.get('/classes/$classID/stats/today');
    return TodayStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MonthlyStats> getMonthly(String classID, String month) async {
    final res = await _dio.get(
      '/classes/$classID/stats/monthly',
      queryParameters: {'month': month},
    );
    return MonthlyStats.fromJson(res.data as Map<String, dynamic>);
  }
}
