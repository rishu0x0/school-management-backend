import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_attendance/features/stats/repository/stats_repository.dart';

part 'stats_notifier.g.dart';

class StatsState {
  const StatsState({
    required this.today,
    required this.monthly,
    required this.selectedMonth,
  });
  final TodayStats? today;
  final MonthlyStats? monthly;
  final String selectedMonth;

  StatsState copyWith({
    TodayStats? today,
    MonthlyStats? monthly,
    String? selectedMonth,
  }) =>
      StatsState(
        today: today ?? this.today,
        monthly: monthly ?? this.monthly,
        selectedMonth: selectedMonth ?? this.selectedMonth,
      );
}

String _currentMonth() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

@riverpod
class StatsNotifier extends _$StatsNotifier {
  @override
  Future<StatsState> build(String classID) async {
    final month = _currentMonth();
    final results = await Future.wait([
      ref.read(statsRepositoryProvider).getToday(classID),
      ref.read(statsRepositoryProvider).getMonthly(classID, month),
    ]);
    return StatsState(
      today: results[0] as TodayStats,
      monthly: results[1] as MonthlyStats,
      selectedMonth: month,
    );
  }

  Future<void> changeMonth(String month) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedMonth: month));
    final monthly =
        await ref.read(statsRepositoryProvider).getMonthly(classID, month);
    final updated = state.valueOrNull;
    if (updated != null) {
      state = AsyncData(updated.copyWith(monthly: monthly));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(classID));
  }
}
