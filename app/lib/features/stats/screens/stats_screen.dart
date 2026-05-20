import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/features/stats/notifier/stats_notifier.dart';
import 'package:school_attendance/features/stats/repository/stats_repository.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsNotifierProvider(classID));

    return Scaffold(
      appBar: AppBar(
        title: Text('$className — Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/classes'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(statsNotifierProvider(classID).notifier).refresh(),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load statistics: $e',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () =>
                    ref.read(statsNotifierProvider(classID).notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () =>
              ref.read(statsNotifierProvider(classID).notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today section
                const _SectionHeader("Today's Attendance"),
                const SizedBox(height: 12),
                if (stats.today != null)
                  _TodayCard(today: stats.today!)
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No attendance recorded today'),
                    ),
                  ),

                const SizedBox(height: 24),

                // Monthly section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionHeader('Monthly Overview'),
                    _MonthPicker(
                      selected: stats.selectedMonth,
                      onChanged: (m) => ref
                          .read(statsNotifierProvider(classID).notifier)
                          .changeMonth(m),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (stats.monthly != null)
                  _MonthlyCard(monthly: stats.monthly!)
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No data for this month'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});
  final TodayStats today;

  @override
  Widget build(BuildContext context) {
    if (!today.submitted) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No attendance recorded today',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sections = <PieChartSectionData>[
      if (today.presentCount > 0)
        PieChartSectionData(
          value: today.presentCount.toDouble(),
          color: Colors.green,
          title: '${today.presentCount}',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
          radius: 60,
        ),
      if (today.absentCount > 0)
        PieChartSectionData(
          value: today.absentCount.toDouble(),
          color: Colors.red,
          title: '${today.absentCount}',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
          radius: 60,
        ),
      if (today.leaveCount > 0)
        PieChartSectionData(
          value: today.leaveCount.toDouble(),
          color: Colors.amber.shade700,
          title: '${today.leaveCount}',
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
          radius: 60,
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: sections.isEmpty
                  ? const Center(child: Text('No records'))
                  : PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Legend('Present', today.presentCount, Colors.green),
                _Legend('Absent', today.absentCount, Colors.red),
                _Legend('Leave', today.leaveCount, Colors.amber.shade700),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${today.totalCount} students — ${today.date}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$label: $count', style: const TextStyle(fontSize: 13)),
        ],
      );
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.monthly});
  final MonthlyStats monthly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatTile(
                    'Days\nRecorded', '${monthly.daysRecorded}', Colors.blue),
                _StatTile(
                  'Average\nAttendance',
                  '${monthly.averagePercentage.toStringAsFixed(1)}%',
                  monthly.averagePercentage >= 75 ? Colors.green : Colors.red,
                ),
                _StatTile(
                  'Below\n75%',
                  '${monthly.belowThreshold.length}',
                  monthly.belowThreshold.isEmpty ? Colors.green : Colors.red,
                ),
              ],
            ),
          ),
        ),
        if (monthly.belowThreshold.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Students Below 75%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
                ...monthly.belowThreshold.map(
                  (s) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.red.shade50,
                      child: Text('#${s.rollNumber}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(s.fullName),
                    trailing: Text(
                      '${s.attendancePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  List<String> _recentMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - i);
      return '${m.year}-${m.month.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = _recentMonths();
    return DropdownButton<String>(
      value: months.contains(selected) ? selected : months.first,
      underline: const SizedBox.shrink(),
      isDense: true,
      items: months
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
    );
  }
}
