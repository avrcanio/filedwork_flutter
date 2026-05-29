import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/progress_bar.dart';
import '../executions/confirm_execution_screen.dart';
import '../work_items/work_item_map_screen.dart';
import '../work_items/work_item_models.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';
import 'work_order_status.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  final int workOrderId;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          data: (order) => ListView(
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
              _AssignmentsSection(order: order),
              const SizedBox(height: 16),
              _VehiclesSection(order: order),
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

String _formatEur(double value) {
  return '€${value.toStringAsFixed(2)}';
}

class _AssignmentsSection extends StatelessWidget {
  const _AssignmentsSection({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
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
          ...order.assignments.map(
            (a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(a.zaposlenikName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.pozicijaName.isNotEmpty) Text(a.pozicijaName),
                    if (a.uloga.isNotEmpty) Text(a.uloga),
                    Text('${a.sati.toStringAsFixed(1)} h · ${_formatEur(a.trosak)}'),
                    if (a.datum != null) Text('Datum: ${a.datum}'),
                  ],
                ),
              ),
            ),
          ),
        if (order.assignments.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ukupno: ${_formatEur(order.laborCost)}',
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
  const _VehiclesSection({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_shipping_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              'Vozila (${order.vehicles.length})',
              style: Theme.of(context).textTheme.titleMedium,
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
          ...order.vehicles.map(
            (v) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(v.voziloLabel),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.registracija.isNotEmpty) Text(v.registracija),
                    Text('${v.sati.toStringAsFixed(1)} h · ${_formatEur(v.trosak)}'),
                    if (v.datum != null) Text('Datum: ${v.datum}'),
                  ],
                ),
              ),
            ),
          ),
        if (order.vehicles.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ukupno: ${_formatEur(order.vehicleCost)}',
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
            if (item.roadSectionName.isNotEmpty)
              Text(item.roadSectionName,
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
