import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/progress_bar.dart';
import '../executions/confirm_execution_screen.dart';
import '../work_items/work_item_map_screen.dart';
import '../work_items/work_item_models.dart';
import 'employee_labor_detail_sheet.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';
import 'work_order_status.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final int workOrderId;

  @override
  ConsumerState<WorkOrderDetailScreen> createState() =>
      _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingPhoto = false;

  int get workOrderId => widget.workOrderId;

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    Future<String> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      ref.invalidate(workOrderDetailProvider(workOrderId));
      ref.invalidate(workOrderListProvider);
      ref.invalidate(workOrderStatusCountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.describeError(error))),
        );
      }
    }
  }

  Future<void> _uploadWorkOrderPhoto(BuildContext context, WorkOrder order) async {
    if (_uploadingPhoto) return;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null || !context.mounted) return;
      setState(() => _uploadingPhoto = true);
      await ref.read(workOrderRepositoryProvider).uploadWorkOrderPhoto(
            workOrderId: order.id,
            filePath: file.path,
            takenAt: _todayIso(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotografija spremljena.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.describeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _todayIso() => toApiDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workOrderDetailProvider(workOrderId));
    final repo = ref.watch(workOrderRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radni nalog'),
        actions: [
          detail.maybeWhen(
            data: (order) => IconButton(
              tooltip: 'Karta stavki',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkItemMapScreen(
                    workOrderId: workOrderId,
                    title: order.number,
                  ),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workOrderDetailProvider(workOrderId).future),
        child: AsyncValueView<WorkOrder>(
          value: detail,
          onRetry: () => ref.invalidate(workOrderDetailProvider(workOrderId)),
          data: (order) {
            final roster = uniqueRosterFromAssignments(order.assignments);
            return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(order: order),
              const SizedBox(height: 16),
              if (order.status == 'draft' || order.status == 'approved') ...[
                OutlinedButton.icon(
                  onPressed: _uploadingPhoto
                      ? null
                      : () => _uploadWorkOrderPhoto(context, order),
                  icon: _uploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Dodaj fotografiju'),
                ),
                const SizedBox(height: 16),
              ],
              _ActionButtons(
                order: order,
                onStart: () => _runAction(
                  context,
                  ref,
                  () => repo.startOrder(order.id),
                  'Nalog pokrenut.',
                ),
                onComplete: () => _runAction(
                  context,
                  ref,
                  () => repo.completeOrder(order.id),
                  'Nalog završen.',
                ),
              ),
              const SizedBox(height: 20),
              _AssignmentsSection(
                workOrderId: order.id,
                order: order,
                roster: roster,
              ),
              if (order.machineSummary.isNotEmpty) ...[
                const SizedBox(height: 16),
                _MachineSummarySection(summary: order.machineSummary),
              ],
              const SizedBox(height: 16),
              _VehiclesSection(order: order),
              const SizedBox(height: 20),
              Text(
                'Stavke (${order.workItems.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (order.totalItemLaborHours > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Ukupno sati po stavkama: '
                  '${order.totalItemLaborHours.toStringAsFixed(1)} h',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              ...order.workItems.map(
                (item) => _WorkItemTile(
                  item: item,
                  enabled: order.status == 'in_progress' ||
                      order.status == 'completed',
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ConfirmExecutionScreen(
                          item: item,
                          workOrderStatus: order.status,
                          roster: roster,
                        ),
                      ),
                    );
                    if (changed == true) {
                      ref.invalidate(workOrderDetailProvider(workOrderId));
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.number,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                WorkOrderStatusChip(
                  status: order.status,
                  label: order.statusDisplay,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(order.title,
                style: Theme.of(context).textTheme.titleMedium),
            if (order.clientName.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.business_outlined, text: order.clientName),
            ],
            if (order.projectName.isNotEmpty)
              _InfoRow(
                  icon: Icons.folder_outlined, text: order.projectName),
            if (order.scheduledDate != null)
              _InfoRow(
                icon: Icons.event_outlined,
                text: 'Planirano: ${formatDateForDisplay(order.scheduledDate)}',
              ),
            if (order.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(order.description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.order,
    required this.onStart,
    required this.onComplete,
  });

  final WorkOrder order;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (order.canStart) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Pokreni nalog'),
      );
    }
    if (order.canComplete) {
      final ready = order.allItemsExecuted;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: ready ? onComplete : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Završi nalog'),
          ),
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sve stavke moraju biti u potpunosti izvršene.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

String _formatHours(double value) => '${value.toStringAsFixed(1)} h';

double _sumHours(Iterable<double> values) =>
    values.fold(0.0, (sum, v) => sum + v);

String _dateGroupLabel(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'Bez datuma';
  final display = formatDateForDisplay(isoDate);
  return display.isEmpty ? isoDate : display;
}

class _AssignmentsSection extends ConsumerWidget {
  const _AssignmentsSection({
    required this.workOrderId,
    required this.order,
    required this.roster,
  });

  final int workOrderId;
  final WorkOrder order;
  final List<WorkOrderRosterEntry> roster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoursByWorker = {
      for (final entry in order.employeeHoursSummary)
        entry.zaposlenikId: entry.totalHours,
    };
    final totalHours = order.employeeHoursSummary.fold<double>(
      0,
      (sum, entry) => sum + entry.totalHours,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, size: 20),
            const SizedBox(width: 6),
            Text(
              'Djelatnici (${roster.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (roster.isEmpty)
          Text(
            'Nema dodijeljenih djelatnika. Dodajte ih u web aplikaciji.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else
          for (final worker in roster)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(worker.name),
                subtitle: worker.pozicijaName.isNotEmpty
                    ? Text(worker.pozicijaName)
                    : null,
                trailing: Text(
                  _formatHours(hoursByWorker[worker.id] ?? 0),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => showEmployeeLaborDetailSheet(
                  context,
                  ref,
                  workOrderId: workOrderId,
                  worker: worker,
                ),
              ),
            ),
        if (roster.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ukupno: ${_formatHours(totalHours)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }
}

class _MachineSummarySection extends StatelessWidget {
  const _MachineSummarySection({required this.summary});

  final List<MachineSummaryEntry> summary;

  @override
  Widget build(BuildContext context) {
    final groups = <String?, List<MachineSummaryEntry>>{};
    for (final entry in summary) {
      groups.putIfAbsent(entry.datum, () => []).add(entry);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              'Sažetak strojeva',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sortedKeys.expand((key) sync* {
          yield Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              _dateGroupLabel(key),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          );
          for (final entry in groups[key]!) {
            yield Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(entry.voziloLabel),
                trailing: Text(_formatHours(entry.hours)),
              ),
            );
          }
        }),
      ],
    );
  }
}

class _VehicleAggregate {
  const _VehicleAggregate({
    required this.label,
    this.registracija = '',
    this.hours = 0,
  });

  final String label;
  final String registracija;
  final double hours;
}

List<_VehicleAggregate> _aggregateVehicles(List<WorkOrderVehicle> vehicles) {
  final byKey = <String, _VehicleAggregate>{};
  for (final vehicle in vehicles) {
    final key = vehicle.voziloId?.toString() ?? vehicle.voziloLabel;
    final existing = byKey[key];
    byKey[key] = _VehicleAggregate(
      label: vehicle.voziloLabel,
      registracija: vehicle.registracija.isNotEmpty
          ? vehicle.registracija
          : (existing?.registracija ?? ''),
      hours: (existing?.hours ?? 0) + vehicle.sati,
    );
  }
  final result = byKey.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  return result;
}

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final aggregated = _aggregateVehicles(order.vehicles);
    final totalHours = _sumHours(aggregated.map((v) => v.hours));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              'Strojevi bez vozača (${aggregated.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (aggregated.isEmpty)
          Text(
            'Nema strojeva bez vozača.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else
          for (final vehicle in aggregated)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(vehicle.label),
                subtitle: vehicle.registracija.isNotEmpty
                    ? Text(vehicle.registracija)
                    : null,
                trailing: Text(
                  _formatHours(vehicle.hours),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        if (aggregated.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ukupno: ${_formatHours(totalHours)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }
}

class _WorkItemTile extends StatelessWidget {
  const _WorkItemTile({
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  final WorkItem item;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unit = item.unit;
    final locationLine = item.locationWithRoadSide;
    final qtyLine = '${item.executedQuantity.toStringAsFixed(0)} / '
        '${item.quantity.toStringAsFixed(0)} $unit';
    final hoursSuffix = item.totalLaborHours > 0
        ? ' · ${item.totalLaborHours.toStringAsFixed(1)} h'
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(item.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$qtyLine$hoursSuffix',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (locationLine.isNotEmpty)
              Text(locationLine,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ExecutionProgressBar(percent: item.progressPercent),
          ],
        ),
        trailing: item.isFullyExecuted
            ? Icon(
                enabled ? Icons.check_circle : Icons.check_circle_outlined,
                color: enabled ? const Color(0xFF059669) : null,
              )
            : Icon(enabled ? Icons.add_task : Icons.lock_outline),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
