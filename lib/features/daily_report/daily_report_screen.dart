import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/photo_gallery.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../executions/execution_models.dart';
import '../home/home_shell_providers.dart';
import '../work_orders/work_order_detail_screen.dart';
import '../work_orders/work_order_repository.dart';
import 'daily_report_models.dart';
import 'daily_report_repository.dart';

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dailyReportViewModeProvider);

    return Column(
      children: [
        const _DateBar(),
        Expanded(
          child: mode == DailyReportViewMode.week
              ? const _WeeklyReportBody()
              : const _DailyReportBody(),
        ),
      ],
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dailyReportViewModeProvider);
    final date = ref.watch(dailyReportDateProvider);
    final weekStart = ref.watch(dailyReportWeekStartProvider);
    final dateNotifier = ref.read(dailyReportDateProvider.notifier);
    final modeNotifier = ref.read(dailyReportViewModeProvider.notifier);
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    void shift(int days) {
      dateNotifier.state = date.add(Duration(days: days));
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: SegmentedButton<DailyReportViewMode>(
              segments: const [
                ButtonSegment(
                  value: DailyReportViewMode.day,
                  label: Text('Dan'),
                ),
                ButtonSegment(
                  value: DailyReportViewMode.week,
                  label: Text('Tjedan'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => modeNotifier.state = s.first,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => shift(mode == DailyReportViewMode.week ? -7 : -1),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      mode == DailyReportViewMode.week
                          ? '${DateFormat('dd.MM.', 'hr').format(weekStart)} – '
                              '${DateFormat('dd.MM.yyyy.', 'hr').format(weekStart.add(const Duration(days: 6)))}'
                          : DateFormat('EEEE, dd.MM.yyyy.', 'hr').format(date),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) dateNotifier.state = picked;
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday && mode == DailyReportViewMode.day
                      ? null
                      : () => shift(mode == DailyReportViewMode.week ? 7 : 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyReportBody extends ConsumerWidget {
  const _DailyReportBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dailyReportProvider);
    final fieldwork =
        ref.watch(authControllerProvider).user?.fieldwork ?? FieldworkCapabilities.empty;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(dailyReportProvider.future),
      child: AsyncValueView<DailyReport>(
        value: report,
        onRetry: () => ref.invalidate(dailyReportProvider),
        data: (data) {
          if (data.isEmpty) {
            return _EmptyDayView(fieldwork: fieldwork);
          }
          final photos = _collectPhotos(data.executions);
          final groups = data.unifiedWorkOrders;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(summary: data.summary),
              if (photos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DayPhotoGallery(photos: photos),
              ],
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Po radnom nalogu',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...groups.map((g) => _UnifiedWorkOrderCard(group: g)),
              ],
            ],
          );
        },
      ),
    );
  }

  List<ExecutionPhoto> _collectPhotos(List<WorkExecution> executions) {
    final seen = <String>{};
    final photos = <ExecutionPhoto>[];
    for (final e in executions) {
      for (final p in e.photoUrls) {
        if (p.url.isNotEmpty && seen.add(p.url)) {
          photos.add(p);
        }
      }
    }
    return photos;
  }
}

class _WeeklyReportBody extends ConsumerWidget {
  const _WeeklyReportBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weeklyReportProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(weeklyReportProvider.future),
      child: AsyncValueView<WeeklyReport>(
        value: report,
        onRetry: () => ref.invalidate(weeklyReportProvider),
        data: (data) {
          if (data.days.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Nema podataka za odabrani tjedan.')),
              ],
            );
          }

          final maxScore = data.days
              .map((d) => d.activityScore)
              .fold(0.0, (a, b) => a > b ? a : b);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ovaj tjedan',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final day in data.days)
                              Expanded(
                                child: _WeekBar(
                                  day: day,
                                  maxScore: maxScore > 0 ? maxScore : 1,
                                  onTap: () {
                                    final parsed = DateTime.tryParse(day.date);
                                    if (parsed == null) return;
                                    ref.read(dailyReportDateProvider.notifier).state =
                                        parsed;
                                    ref.read(dailyReportViewModeProvider.notifier).state =
                                        DailyReportViewMode.day;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...data.days.map((day) => _WeeklyDayTile(day: day)),
            ],
          );
        },
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.day,
    required this.maxScore,
    required this.onTap,
  });

  final WeeklyReportDay day;
  final double maxScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(day.date);
    final label = parsed != null
        ? DateFormat('E', 'hr').format(parsed).substring(0, 2)
        : '';
    final heightFactor = day.activityScore / maxScore;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: heightFactor.clamp(0.05, 1.0),
                  widthFactor: 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _WeeklyDayTile extends StatelessWidget {
  const _WeeklyDayTile({required this.day});

  final WeeklyReportDay day;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(day.date);
    final dateLabel = parsed != null
        ? DateFormat('EEEE, dd.MM.', 'hr').format(parsed)
        : day.date;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(dateLabel),
        subtitle: Text(
          '${day.executionsCount} izvršenja · '
          '${day.totalLaborHours.toStringAsFixed(1)} h rada · '
          '${day.totalVehicleHours.toStringAsFixed(1)} h vozila',
        ),
        trailing: day.quantityByUnit.isNotEmpty
            ? Text(day.quantityByUnit.entries.first.value)
            : null,
      ),
    );
  }
}

class _EmptyDayView extends ConsumerWidget {
  const _EmptyDayView({required this.fieldwork});

  final FieldworkCapabilities fieldwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.event_busy_outlined,
            size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          'Nema izvršenih radova',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (fieldwork.ownZaposlenikId != null) ...[
          const SizedBox(height: 8),
          Text(
            'Nema unesenih sati rada',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            ref.read(workOrderStatusFilterProvider.notifier).state =
                'in_progress';
            ref.read(homeShellTabProvider.notifier).state = 0;
          },
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Pogledaj naloge u tijeku'),
        ),
      ],
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
            const Divider(height: 28),
            Text(
              'Ukupno: ${summary.totalLaborHours.toStringAsFixed(1)} h rada · '
              '${summary.totalVehicleHours.toStringAsFixed(1)} h vozila',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                      label: Text('${_trimQty(entry.value)} ${entry.key}'),
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

class _DayPhotoGallery extends StatelessWidget {
  const _DayPhotoGallery({required this.photos});

  final List<ExecutionPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fotografije dana',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            PhotoGallery(photos: photos, size: 72),
          ],
        ),
      ),
    );
  }
}

class _UnifiedWorkOrderCard extends StatelessWidget {
  const _UnifiedWorkOrderCard({required this.group});

  final DailyReportGroup group;

  @override
  Widget build(BuildContext context) {
    final execLabel = group.executionsCount == 1
        ? '1 izvršenje'
        : '${group.executionsCount} izvršenja';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text(group.workOrderNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: 'Otvori nalog',
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      WorkOrderDetailScreen(workOrderId: group.workOrderId),
                ),
              ),
            ),
          ],
        ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.workOrderTitle.isNotEmpty) Text(group.workOrderTitle),
              if (group.quantitySummary.isNotEmpty)
                Text('Izvršeno: ${group.quantitySummary} ($execLabel)'),
              if (group.laborHours > 0)
                Text('Moji sati: ${group.laborHours.toStringAsFixed(1)} h'),
              if (group.vehicleHours > 0)
                Text(
                  group.vehicles.isNotEmpty
                      ? 'Vozilo: ${group.vehicles.first.voziloLabel} · '
                          '${group.vehicleHours.toStringAsFixed(1)} h'
                      : 'Vozilo: ${group.vehicleHours.toStringAsFixed(1)} h',
                ),
            ],
          ),
          trailing: group.executionsCount > 0
              ? Tooltip(
                  message: execLabel,
                  child: Chip(
                    avatar: const Icon(Icons.checklist, size: 16),
                    visualDensity: VisualDensity.compact,
                    label: Text('${group.executionsCount}'),
                  ),
                )
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: group.executions.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nema detalja izvršenja.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]
              : group.executions
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  execution.workItemDescription.isEmpty
                      ? 'Stavka #${execution.workItem}'
                      : execution.workItemDescription,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(execution.quantityWithUnit),
            ],
          ),
          if (execution.statusDisplay.isNotEmpty) ...[
            const SizedBox(height: 4),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                execution.statusDisplay,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
          if (execution.locationLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                execution.locationLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
