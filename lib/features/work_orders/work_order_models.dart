import '../work_items/work_item_models.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    required this.statusDisplay,
    this.projectName = '',
    this.clientName = '',
    this.description = '',
    this.scheduledDate,
    this.completedDate,
    this.totalValue = 0,
    this.workItems = const [],
  });

  final int id;
  final String number;
  final String title;
  final String status;
  final String statusDisplay;
  final String projectName;
  final String clientName;
  final String description;
  final String? scheduledDate;
  final String? completedDate;
  final double totalValue;
  final List<WorkItem> workItems;

  bool get canStart => status == 'approved';
  bool get canComplete => status == 'in_progress';
  bool get allItemsExecuted =>
      workItems.isNotEmpty && workItems.every((i) => i.isFullyExecuted);

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] as int,
      number: json['number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusDisplay: json['status_display'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String?,
      completedDate: json['completed_date'] as String?,
      totalValue: _toDouble(json['total_value']),
      workItems: (json['work_items'] as List?)
              ?.map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
