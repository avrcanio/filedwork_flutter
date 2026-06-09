import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';

Future<void> showEmployeeLaborDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required WorkOrderRosterEntry worker,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return _EmployeeLaborDetailBody(
          scrollController: scrollController,
          workOrderId: workOrderId,
          worker: worker,
        );
      },
    ),
  );
}

class _EmployeeLaborDetailBody extends ConsumerStatefulWidget {
  const _EmployeeLaborDetailBody({
    required this.scrollController,
    required this.workOrderId,
    required this.worker,
  });

  final ScrollController scrollController;
  final int workOrderId;
  final WorkOrderRosterEntry worker;

  @override
  ConsumerState<_EmployeeLaborDetailBody> createState() =>
      _EmployeeLaborDetailBodyState();
}

class _EmployeeLaborDetailBodyState
    extends ConsumerState<_EmployeeLaborDetailBody> {
  late Future<EmployeeLaborDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<EmployeeLaborDetail> _load() {
    return ref.read(workOrderRepositoryProvider).fetchEmployeeLaborDetail(
          workOrderId: widget.workOrderId,
          zaposlenikId: widget.worker.id,
        );
  }

  Map<String, List<EmployeeLaborDetailEntry>> _groupByDate(
    List<EmployeeLaborDetailEntry> entries,
  ) {
    final groups = <String, List<EmployeeLaborDetailEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.executionDate, () => []).add(entry);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.worker.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (widget.worker.pozicijaName.isNotEmpty)
                        Text(
                          widget.worker.pozicijaName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zatvori',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<EmployeeLaborDetail>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(ApiClient.describeError(snapshot.error!)),
                    ),
                  );
                }
                final detail = snapshot.data!;
                if (detail.entries.isEmpty) {
                  return const Center(
                    child: Text('Nema unesenih sati za ovog djelatnika.'),
                  );
                }

                final groups = _groupByDate(detail.entries);
                final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Ukupno: ${detail.totalHours.toStringAsFixed(1)} h',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final date in sortedDates) ...[
                      _DateGroupHeader(
                        date: date,
                        hours: groups[date]!
                            .fold<double>(0, (sum, e) => sum + e.laborHours),
                      ),
                      for (final entry in groups[date]!)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(entry.operationName),
                            subtitle: entry.locationLine.isNotEmpty
                                ? Text(entry.locationLine)
                                : null,
                            trailing: Text(
                              '${entry.laborHours.toStringAsFixed(1)} h',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.date, required this.hours});

  final String date;
  final double hours;

  @override
  Widget build(BuildContext context) {
    final display = formatDateForDisplay(date);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              display.isEmpty ? date : display,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Text(
            '${hours.toStringAsFixed(1)} h',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
