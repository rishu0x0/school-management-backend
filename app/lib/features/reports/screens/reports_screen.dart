import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_attendance/features/classes/notifier/classes_notifier.dart';
import 'package:school_attendance/features/reports/notifier/reports_notifier.dart';
import 'package:school_attendance/features/reports/repository/reports_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selectedClassId;
  String _selectedMonth = _defaultMonth();
  bool _generating = false;
  String? _genError;

  static String _defaultMonth() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
  }

  List<String> _last6Months() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _generate(String format) async {
    if (_selectedClassId == null) {
      setState(() => _genError = 'Select a class first');
      return;
    }
    setState(() {
      _generating = true;
      _genError = null;
    });
    try {
      await ref.read(reportsNotifierProvider.notifier).generate(
            classId: _selectedClassId!,
            month: _selectedMonth,
            format: format,
          );
    } catch (e) {
      setState(() => _genError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(reportsNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Generator card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate Report',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ClassSelector(
                    selectedId: _selectedClassId,
                    onChanged: (id) => setState(() => _selectedClassId = id),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _last6Months()
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMonth = v!),
                  ),
                  if (_genError != null) ...[
                    const SizedBox(height: 8),
                    Text(_genError!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _generating ? null : () => _generate('pdf'),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _generating ? null : () => _generate('excel'),
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Excel'),
                        ),
                      ),
                    ],
                  ),
                  if (_generating) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 4),
                    const Text(
                      'Generating… this may take up to 30 seconds',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text('Your Reports',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          reportsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(child: Text('Error loading reports: $e')),
            data: (rpts) {
              if (rpts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                      child: Text('No reports yet. Generate one above.')),
                );
              }
              return Column(
                children: rpts
                    .map((r) => _ReportTile(
                          report: r,
                          onDownload: r.signedUrl != null
                              ? () => _openUrl(r.signedUrl!)
                              : null,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClassSelector extends ConsumerWidget {
  const _ClassSelector(
      {required this.selectedId, required this.onChanged});
  final String? selectedId;
  final void Function(String id) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesNotifierProvider);
    return classesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading classes: $e'),
      data: (classes) => DropdownButtonFormField<String>(
        value: selectedId,
        decoration: const InputDecoration(
          labelText: 'Class',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        hint: const Text('Select a class'),
        items: classes
            .map((c) =>
                DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: (id) {
          if (id != null) onChanged(id);
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, this.onDownload});
  final ReportModel report;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (report.status) {
      'ready' => (Colors.green, Icons.check_circle),
      'processing' => (Colors.blue, Icons.hourglass_top),
      'pending' => (Colors.grey, Icons.schedule),
      _ => (Colors.red, Icons.error),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          report.format == 'pdf'
              ? Icons.picture_as_pdf
              : Icons.table_chart,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '${report.month} — ${report.format.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(report.status,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
            if (report.errorMsg != null)
              Text(report.errorMsg!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 11)),
          ],
        ),
        trailing: report.status == 'ready' && onDownload != null
            ? IconButton(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
                tooltip: 'Download',
              )
            : report.status == 'processing'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
      ),
    );
  }
}
