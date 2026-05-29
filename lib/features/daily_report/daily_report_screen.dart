import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/photo_gallery.dart';
import '../executions/execution_models.dart';
import 'daily_report_models.dart';
import 'daily_report_repository.dart';

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dailyReportProvider);
    final date = ref.watch(dailyReportDateProvider);

    return Column(
      children: [
        _DateBar(date: date),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(dailyReportProvider.future),
            child: AsyncValueView<DailyReport>(
              value: report,
              onRetry: () => ref.invalidate(dailyReportProvider),
              data: (data) {
                if (data.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Nema unosa za odabrani dan.')),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(summary: data.summary),
                    const SizedBox(height: 20),
                    Text('Po radnom nalogu',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...data.byWorkOrder.map((g) => _GroupCard(group: g)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyReportDateProvider.notifier);
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => notifier.state =
                  date.subtract(const Duration(days: 1)),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(DateFormat('EEEE, dd.MM.yyyy.', 'hr').format(date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) notifier.state = picked;
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isToday
                  ? null
                  : () =>
                      notifier.state = date.add(const Duration(days: 1)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final DailyReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sažetak', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(value: '${summary.executionsCount}', label: 'Izvršenja'),
                _Stat(value: '${summary.workOrdersCount}', label: 'Naloga'),
                _Stat(value: '${summary.itemsCount}', label: 'Stavki'),
              ],
            ),
            if (summary.totalQuantityByUnit.isNotEmpty) ...[
              const Divider(height: 28),
              Text('Količine po jedinici',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in summary.totalQuantityByUnit.entries)
                    Chip(
                      label: Text(
                          '${_trimQty(entry.value)} ${entry.key}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _trimQty(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    return parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toString();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final DailyReportGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(group.workOrderNumber,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(group.workOrderTitle),
        trailing: Chip(
          visualDensity: VisualDensity.compact,
          label: Text('${group.executionsCount}'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: group.executions
            .map((e) => _ExecutionRow(execution: e))
            .toList(),
      ),
    );
  }
}

class _ExecutionRow extends StatelessWidget {
  const _ExecutionRow({required this.execution});

  final WorkExecution execution;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  execution.workItemDescription.isEmpty
                      ? 'Stavka #${execution.workItem}'
                      : execution.workItemDescription,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(execution.quantityExecuted.toStringAsFixed(0)),
            ],
          ),
          if (execution.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(execution.notes,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (execution.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            PhotoGallery(photos: execution.photoUrls, size: 56),
          ],
        ],
      ),
    );
  }
}
