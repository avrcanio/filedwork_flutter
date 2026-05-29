import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/progress_bar.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../executions/confirm_execution_screen.dart';
import '../work_items/work_item_map_screen.dart';
import '../work_items/work_item_models.dart';
import 'resource_hours_sheet.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _fabCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed = _scrollController.offset > 24;
    if (collapsed != _fabCollapsed) {
      setState(() => _fabCollapsed = collapsed);
    }
  }

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

  Future<void> _refreshDetail(WidgetRef ref) async {
    ref.invalidate(workOrderDetailProvider(workOrderId));
  }

  String _todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  WorkOrderAssignment? _findOwnAssignmentToday(
    WorkOrder order,
    FieldworkCapabilities fieldwork,
  ) {
    final ownId = fieldwork.ownZaposlenikId;
    if (ownId == null) return null;
    final today = _todayIso();
    for (final a in order.assignments) {
      if (a.zaposlenikId == ownId && a.datum == today) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workOrderDetailProvider(workOrderId));
    final repo = ref.watch(workOrderRepositoryProvider);
    final fieldwork =
        ref.watch(authControllerProvider).user?.fieldwork ?? FieldworkCapabilities.empty;

    void onQuickLog(WorkOrder order) async {
      final ownId = fieldwork.ownZaposlenikId!;
      final existing = _findOwnAssignmentToday(order, fieldwork);
      final changed = await showQuickLogSheet(
        context,
        ref,
        workOrderId: workOrderId,
        zaposlenikId: ownId,
        zaposlenikName: fieldwork.ownZaposlenikName ?? 'Ja',
        existing: existing,
      );
      if (changed == true) await _refreshDetail(ref);
    }

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
      floatingActionButton: detail.maybeWhen(
        data: (order) {
          final showFab = order.status == 'in_progress' &&
              fieldwork.canEditHours &&
              fieldwork.ownZaposlenikId != null;
          if (!showFab) return null;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _fabCollapsed
                ? FloatingActionButton(
                    key: const ValueKey('fab_collapsed'),
                    tooltip: 'Unesi moje sate danas',
                    onPressed: () => onQuickLog(order),
                    child: const Icon(Icons.schedule),
                  )
                : FloatingActionButton.extended(
                    key: const ValueKey('fab_extended'),
                    onPressed: () => onQuickLog(order),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Unesi moje sate danas'),
                  ),
          );
        },
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(workOrderDetailProvider(workOrderId).future),
        child: AsyncValueView<WorkOrder>(
          value: detail,
          onRetry: () => ref.invalidate(workOrderDetailProvider(workOrderId)),
          data: (order) => ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              _Header(order: order),
              const SizedBox(height: 16),
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
                order: order,
                fieldwork: fieldwork,
                onEdit: (assignment, editable) async {
                  final changed = await showAssignmentHoursSheet(
                    context,
                    ref,
                    workOrderId: workOrderId,
                    assignment: assignment,
                    editable: editable,
                  );
                  if (changed == true) await _refreshDetail(ref);
                },
              ),
              const SizedBox(height: 16),
              _VehiclesSection(
                order: order,
                fieldwork: fieldwork,
                onEdit: (vehicle, editable) async {
                  final changed = await showVehicleHoursSheet(
                    context,
                    ref,
                    workOrderId: workOrderId,
                    vehicle: vehicle,
                    editable: editable,
                  );
                  if (changed == true) await _refreshDetail(ref);
                },
                onAdd: () async {
                  final changed = await showAddVehicleSheet(
                    context,
                    ref,
                    workOrderId: workOrderId,
                  );
                  if (changed == true) await _refreshDetail(ref);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Stavke (${order.workItems.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...order.workItems.map(
                (item) => _WorkItemTile(
                  item: item,
                  enabled: order.status == 'in_progress',
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ConfirmExecutionScreen(item: item),
                      ),
                    );
                    if (changed == true) {
                      ref.invalidate(workOrderDetailProvider(workOrderId));
                    }
                  },
                ),
              ),
              const SizedBox(height: 72),
            ],
          ),
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
                text: 'Planirano: ${order.scheduledDate}',
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

List<MapEntry<String?, List<WorkOrderAssignment>>> _groupByDate(
  List<WorkOrderAssignment> items,
) {
  final groups = <String?, List<WorkOrderAssignment>>{};
  for (final item in items) {
    final key = item.datum;
    groups.putIfAbsent(key, () => []).add(item);
  }
  final entries = groups.entries.toList();
  entries.sort((a, b) {
    if (a.key == null) return 1;
    if (b.key == null) return -1;
    return b.key!.compareTo(a.key!);
  });
  return entries;
}

List<MapEntry<String?, List<WorkOrderVehicle>>> _groupVehiclesByDate(
  List<WorkOrderVehicle> items,
) {
  final groups = <String?, List<WorkOrderVehicle>>{};
  for (final item in items) {
    final key = item.datum;
    groups.putIfAbsent(key, () => []).add(item);
  }
  final entries = groups.entries.toList();
  entries.sort((a, b) {
    if (a.key == null) return 1;
    if (b.key == null) return -1;
    return b.key!.compareTo(a.key!);
  });
  return entries;
}

String _dateGroupLabel(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'Bez datuma';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return DateFormat('dd.MM.yyyy.').format(parsed);
}

class _AssignmentsSection extends StatelessWidget {
  const _AssignmentsSection({
    required this.order,
    required this.fieldwork,
    required this.onEdit,
  });

  final WorkOrder order;
  final FieldworkCapabilities fieldwork;
  final void Function(WorkOrderAssignment assignment, bool editable) onEdit;

  @override
  Widget build(BuildContext context) {
    final totalHours = _sumHours(order.assignments.map((a) => a.sati));
    final groups = _groupByDate(order.assignments);
    final canEditOrder =
        order.status == 'in_progress' && fieldwork.canEditHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.people_outline, size: 20),
            const SizedBox(width: 6),
            Text(
              'Djelatnici (${order.assignments.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (order.assignments.isEmpty)
          Text(
            'Nema dodijeljenih djelatnika.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else
          ...groups.expand((group) sync* {
            yield Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                _dateGroupLabel(group.key),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            );
            for (final a in group.value) {
              final editable = canEditOrder &&
                  a.zaposlenikId != null &&
                  fieldwork.canManageZaposlenik(a.zaposlenikId!);
              yield Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(a.zaposlenikName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a.pozicijaName.isNotEmpty) Text(a.pozicijaName),
                      if (a.uloga.isNotEmpty) Text(a.uloga),
                      Text(_formatHours(a.sati)),
                    ],
                  ),
                  trailing: editable
                      ? const Icon(Icons.edit_outlined, size: 20)
                      : null,
                  onTap: () => onEdit(a, editable),
                ),
              );
            }
          }),
        if (order.assignments.isNotEmpty)
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

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection({
    required this.order,
    required this.fieldwork,
    required this.onEdit,
    required this.onAdd,
  });

  final WorkOrder order;
  final FieldworkCapabilities fieldwork;
  final void Function(WorkOrderVehicle vehicle, bool editable) onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final totalHours = _sumHours(order.vehicles.map((v) => v.sati));
    final groups = _groupVehiclesByDate(order.vehicles);
    final canEditOrder =
        order.status == 'in_progress' && fieldwork.canAddVehicles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_outlined, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Vozila (${order.vehicles.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canEditOrder)
              IconButton(
                tooltip: 'Dodaj vozilo',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAdd,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (order.vehicles.isEmpty)
          Text(
            'Nema dodijeljenih vozila.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else
          ...groups.expand((group) sync* {
            yield Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                _dateGroupLabel(group.key),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            );
            for (final v in group.value) {
              yield Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(v.voziloLabel),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (v.registracija.isNotEmpty) Text(v.registracija),
                      Text(_formatHours(v.sati)),
                    ],
                  ),
                  trailing: canEditOrder
                      ? const Icon(Icons.edit_outlined, size: 20)
                      : null,
                  onTap: canEditOrder ? () => onEdit(v, true) : null,
                ),
              );
            }
          }),
        if (order.vehicles.isNotEmpty)
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
              '${item.executedQuantity.toStringAsFixed(0)} / '
              '${item.quantity.toStringAsFixed(0)} $unit',
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
            ? const Icon(Icons.check_circle, color: Color(0xFF059669))
            : Icon(enabled ? Icons.add_task : Icons.lock_outline),
        onTap: enabled && !item.isFullyExecuted ? onTap : null,
      ),
    );
  }
}
