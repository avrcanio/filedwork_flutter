import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/app_dates.dart';
import '../../shared/widgets/async_value_view.dart';
import '../project/project_repository.dart';
import '../project/project_selector_bar.dart';
import '../project/selected_project_controller.dart';
import 'work_order_detail_screen.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';
import 'work_order_status.dart';

class WorkOrderListScreen extends ConsumerWidget {
  const WorkOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(selectedProjectIdProvider);
    final orders = ref.watch(workOrderListProvider);
    final filter = ref.watch(workOrderStatusFilterProvider);

    if (projectId == null) {
      return const Column(
        children: [
          ProjectSelectorBar(),
          Expanded(
            child: Center(child: Text('Nema aktivnih projekata.')),
          ),
        ],
      );
    }

    return Column(
      children: [
        const ProjectSelectorBar(),
        _StatusFilterBar(selected: filter),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              ref.invalidate(activeProjectsProvider);
              ref.invalidate(workOrderStatusCountsProvider);
              return ref.refresh(workOrderListProvider.future);
            },
            child: AsyncValueView<List<WorkOrder>>(
              value: orders,
              onRetry: () => ref.invalidate(workOrderListProvider),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Nema radnih naloga.')),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _WorkOrderCard(
                    order: list[index],
                    showProjectName: false,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusFilterBar extends ConsumerWidget {
  const _StatusFilterBar({required this.selected});

  final String? selected;

  static const _filters = <(String?, String)>[
    (null, 'Svi'),
    ('approved', 'Odobreni'),
    ('in_progress', 'U tijeku'),
    ('completed', 'Završeni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(workOrderStatusCountsProvider).valueOrNull;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final (value, label) in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                isLabelVisible: counts != null,
                label: Text('${counts?.countFor(value) ?? 0}'),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected == value,
                  onSelected: (_) => ref
                      .read(workOrderStatusFilterProvider.notifier)
                      .state = value,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.order,
    this.showProjectName = true,
  });

  final WorkOrder order;
  final bool showProjectName;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          order.number,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(order.title),
            if (showProjectName && order.projectName.isNotEmpty)
              Text(
                order.projectName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!showProjectName && order.scheduledDate != null)
              Text(
                formatDateForDisplay(order.scheduledDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            WorkOrderStatusChip(
              status: order.status,
              label: order.statusDisplay,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderDetailScreen(workOrderId: order.id),
          ),
        ),
      ),
    );
  }
}
