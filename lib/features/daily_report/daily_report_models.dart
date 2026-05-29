import '../executions/execution_models.dart';

class DailyReportSummary {
  const DailyReportSummary({
    required this.executionsCount,
    required this.workOrdersCount,
    required this.itemsCount,
    required this.totalQuantityByUnit,
  });

  final int executionsCount;
  final int workOrdersCount;
  final int itemsCount;
  final Map<String, String> totalQuantityByUnit;

  factory DailyReportSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['total_quantity_by_unit'] as Map?) ?? {};
    return DailyReportSummary(
      executionsCount: json['executions_count'] as int? ?? 0,
      workOrdersCount: json['work_orders_count'] as int? ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
      totalQuantityByUnit:
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }
}

class DailyReportGroup {
  const DailyReportGroup({
    required this.workOrderId,
    required this.workOrderNumber,
    required this.workOrderTitle,
    required this.executionsCount,
    required this.executions,
  });

  final int workOrderId;
  final String workOrderNumber;
  final String workOrderTitle;
  final int executionsCount;
  final List<WorkExecution> executions;

  factory DailyReportGroup.fromJson(Map<String, dynamic> json) {
    return DailyReportGroup(
      workOrderId: json['work_order_id'] as int? ?? 0,
      workOrderNumber: json['work_order_number'] as String? ?? '',
      workOrderTitle: json['work_order_title'] as String? ?? '',
      executionsCount: json['executions_count'] as int? ?? 0,
      executions: (json['executions'] as List?)
              ?.map((e) => WorkExecution.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class DailyReport {
  const DailyReport({
    required this.date,
    required this.summary,
    required this.executions,
    required this.byWorkOrder,
    this.executedByName = '',
  });

  final String date;
  final String executedByName;
  final DailyReportSummary summary;
  final List<WorkExecution> executions;
  final List<DailyReportGroup> byWorkOrder;

  bool get isEmpty => executions.isEmpty;

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final executedBy = json['executed_by'] as Map<String, dynamic>?;
    return DailyReport(
      date: json['date'] as String? ?? '',
      executedByName: executedBy?['name'] as String? ?? '',
      summary: DailyReportSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      executions: (json['executions'] as List?)
              ?.map((e) => WorkExecution.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      byWorkOrder: (json['by_work_order'] as List?)
              ?.map((e) => DailyReportGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
