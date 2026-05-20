import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/features/reports/repository/reports_repository.dart';

part 'reports_notifier.g.dart';

@riverpod
class ReportsNotifier extends _$ReportsNotifier {
  @override
  Future<List<ReportModel>> build() => _fetch();

  Future<List<ReportModel>> _fetch() =>
      ref.read(reportsRepositoryProvider).listReports();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<String> generate({
    required String classId,
    required String month,
    required String format,
  }) async {
    final id = await ref.read(reportsRepositoryProvider).generateReport(
          classId: classId,
          month: month,
          format: format,
        );
    refresh();
    return id;
  }
}
