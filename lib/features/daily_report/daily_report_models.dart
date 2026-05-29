import '../executions/execution_models.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class DailyReportSummary {
  const DailyReportSummary({
    required this.executionsCount,
    required this.workOrdersCount,
    required this.itemsCount,
    required this.totalQuantityByUnit,
    this.totalLaborHours = 0,
    this.totalVehicleHours = 0,
  });

  final int executionsCount;
  final int workOrdersCount;
  final int itemsCount;
  final Map<String, String> totalQuantityByUnit;
  final double totalLaborHours;
  final double totalVehicleHours;

  factory DailyReportSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['total_quantity_by_unit'] as Map?) ?? {};
    return DailyReportSummary(
      executionsCount: json['executions_count'] as int? ?? 0,
      workOrdersCount: json['work_orders_count'] as int? ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
      totalQuantityByUnit:
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
      totalLaborHours: _toDouble(json['total_labor_hours']),
      totalVehicleHours: _toDouble(json['total_vehicle_hours']),
    );
  }
}

class DailyReportVehicleEntry {
  const DailyReportVehicleEntry({
    required this.id,
    required this.voziloLabel,
    required this.registracija,
    required this.sati,
  });

  final int id;
  final String voziloLabel;
  final String registracija;
  final double sati;

  factory DailyReportVehicleEntry.fromJson(Map<String, dynamic> json) {
    return DailyReportVehicleEntry(
      id: json['id'] as int? ?? 0,
      voziloLabel: json['vozilo_label'] as String? ?? '',
      registracija: json['registracija'] as String? ?? '',
      sati: _toDouble(json['sati']),
    );
  }
}

class DailyReportVehicleGroup {
  const DailyReportVehicleGroup({
    required this.workOrderId,
    required this.workOrderNumber,
    required this.hours,
    required this.vehicles,
  });

  final int workOrderId;
  final String workOrderNumber;
  final double hours;
  final List<DailyReportVehicleEntry> vehicles;

  factory DailyReportVehicleGroup.fromJson(Map<String, dynamic> json) {
    return DailyReportVehicleGroup(
      workOrderId: json['work_order_id'] as int? ?? 0,
      workOrderNumber: json['work_order_number'] as String? ?? '',
      hours: _toDouble(json['hours']),
      vehicles: (json['vehicles'] as List?)
              ?.map((e) =>
                  DailyReportVehicleEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class DailyReportVehicleHours {
  const DailyReportVehicleHours({
    required this.totalHours,
    required this.byWorkOrder,
  });

  final double totalHours;
  final List<DailyReportVehicleGroup> byWorkOrder;

  bool get hasEntries => totalHours > 0 || byWorkOrder.isNotEmpty;

  factory DailyReportVehicleHours.fromJson(Map<String, dynamic> json) {
    return DailyReportVehicleHours(
      totalHours: _toDouble(json['total_hours']),
      byWorkOrder: (json['by_work_order'] as List?)
              ?.map((e) =>
                  DailyReportVehicleGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class DailyReportLaborAssignment {
  const DailyReportLaborAssignment({
    required this.id,
    required this.zaposlenikName,
    required this.sati,
  });

  final int id;
  final String zaposlenikName;
  final double sati;

  factory DailyReportLaborAssignment.fromJson(Map<String, dynamic> json) {
    return DailyReportLaborAssignment(
      id: json['id'] as int? ?? 0,
      zaposlenikName: json['zaposlenik_name'] as String? ?? '',
      sati: _toDouble(json['sati']),
    );
  }
}

class DailyReportLaborGroup {
  const DailyReportLaborGroup({
    required this.workOrderId,
    required this.workOrderNumber,
    required this.hours,
    required this.assignments,
  });

  final int workOrderId;
  final String workOrderNumber;
  final double hours;
  final List<DailyReportLaborAssignment> assignments;

  factory DailyReportLaborGroup.fromJson(Map<String, dynamic> json) {
    return DailyReportLaborGroup(
      workOrderId: json['work_order_id'] as int? ?? 0,
      workOrderNumber: json['work_order_number'] as String? ?? '',
      hours: _toDouble(json['hours']),
      assignments: (json['assignments'] as List?)
              ?.map((e) =>
                  DailyReportLaborAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class DailyReportLaborHours {
  const DailyReportLaborHours({
    required this.totalHours,
    required this.byWorkOrder,
  });

  final double totalHours;
  final List<DailyReportLaborGroup> byWorkOrder;

  bool get hasEntries => totalHours > 0 || byWorkOrder.isNotEmpty;

  factory DailyReportLaborHours.fromJson(Map<String, dynamic> json) {
    return DailyReportLaborHours(
      totalHours: _toDouble(json['total_hours']),
      byWorkOrder: (json['by_work_order'] as List?)
              ?.map((e) =>
                  DailyReportLaborGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
    this.quantityByUnit = const {},
    this.laborHours = 0,
    this.vehicleHours = 0,
    this.vehicles = const [],
  });

  final int workOrderId;
  final String workOrderNumber;
  final String workOrderTitle;
  final int executionsCount;
  final Map<String, String> quantityByUnit;
  final double laborHours;
  final double vehicleHours;
  final List<DailyReportVehicleEntry> vehicles;
  final List<WorkExecution> executions;

  bool get hasContent =>
      executionsCount > 0 ||
      laborHours > 0 ||
      vehicleHours > 0;

  String get quantitySummary {
    if (quantityByUnit.isEmpty) return '';
    return quantityByUnit.entries
        .map((e) => '${_trimQty(e.value)} ${e.key}')
        .join(', ');
  }

  static String _trimQty(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    return parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toString();
  }

  factory DailyReportGroup.fromJson(Map<String, dynamic> json) {
    final qtyRaw = (json['quantity_by_unit'] as Map?) ?? {};
    return DailyReportGroup(
      workOrderId: json['work_order_id'] as int? ?? 0,
      workOrderNumber: json['work_order_number'] as String? ?? '',
      workOrderTitle: json['work_order_title'] as String? ?? '',
      executionsCount: json['executions_count'] as int? ?? 0,
      quantityByUnit:
          qtyRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
      laborHours: _toDouble(json['labor_hours']),
      vehicleHours: _toDouble(json['vehicle_hours']),
      vehicles: (json['vehicles'] as List?)
              ?.map((e) =>
                  DailyReportVehicleEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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
    this.laborHours,
    this.vehicleHours,
  });

  final String date;
  final String executedByName;
  final DailyReportSummary summary;
  final List<WorkExecution> executions;
  final List<DailyReportGroup> byWorkOrder;
  final DailyReportLaborHours? laborHours;
  final DailyReportVehicleHours? vehicleHours;

  bool get hasExecutions => executions.isNotEmpty;

  bool get hasLaborHours => laborHours?.hasEntries ?? false;

  bool get hasVehicleHours => vehicleHours?.hasEntries ?? false;

  bool get isEmpty =>
      !hasExecutions && !hasLaborHours && !hasVehicleHours;

  List<DailyReportGroup> get unifiedWorkOrders {
    if (byWorkOrder.isNotEmpty &&
        byWorkOrder.any((g) => g.quantityByUnit.isNotEmpty || g.laborHours > 0)) {
      return byWorkOrder.where((g) => g.hasContent).toList();
    }
    return _mergeLegacyGroups();
  }

  List<DailyReportGroup> _mergeLegacyGroups() {
    final map = <int, DailyReportGroup>{};

    for (final g in byWorkOrder) {
      map[g.workOrderId] = g;
    }

    if (laborHours != null) {
      for (final lg in laborHours!.byWorkOrder) {
        final existing = map[lg.workOrderId];
        if (existing != null) {
          map[lg.workOrderId] = DailyReportGroup(
            workOrderId: existing.workOrderId,
            workOrderNumber: existing.workOrderNumber,
            workOrderTitle: existing.workOrderTitle,
            executionsCount: existing.executionsCount,
            executions: existing.executions,
            quantityByUnit: existing.quantityByUnit,
            laborHours: lg.hours,
            vehicleHours: existing.vehicleHours,
            vehicles: existing.vehicles,
          );
        } else {
          map[lg.workOrderId] = DailyReportGroup(
            workOrderId: lg.workOrderId,
            workOrderNumber: lg.workOrderNumber,
            workOrderTitle: lg.workOrderNumber,
            executionsCount: 0,
            executions: const [],
            laborHours: lg.hours,
          );
        }
      }
    }

    if (vehicleHours != null) {
      for (final vg in vehicleHours!.byWorkOrder) {
        final existing = map[vg.workOrderId];
        if (existing != null) {
          map[vg.workOrderId] = DailyReportGroup(
            workOrderId: existing.workOrderId,
            workOrderNumber: existing.workOrderNumber,
            workOrderTitle: existing.workOrderTitle,
            executionsCount: existing.executionsCount,
            executions: existing.executions,
            quantityByUnit: existing.quantityByUnit,
            laborHours: existing.laborHours,
            vehicleHours: vg.hours,
            vehicles: vg.vehicles,
          );
        } else {
          map[vg.workOrderId] = DailyReportGroup(
            workOrderId: vg.workOrderId,
            workOrderNumber: vg.workOrderNumber,
            workOrderTitle: vg.workOrderNumber,
            executionsCount: 0,
            executions: const [],
            vehicleHours: vg.hours,
            vehicles: vg.vehicles,
          );
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.workOrderNumber.compareTo(b.workOrderNumber));
    return list;
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final executedBy = json['executed_by'] as Map<String, dynamic>?;
    final laborRaw = json['labor_hours'] as Map<String, dynamic>?;
    final vehicleRaw = json['vehicle_hours'] as Map<String, dynamic>?;
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
      laborHours: laborRaw != null
          ? DailyReportLaborHours.fromJson(laborRaw)
          : null,
      vehicleHours: vehicleRaw != null
          ? DailyReportVehicleHours.fromJson(vehicleRaw)
          : null,
    );
  }
}

class WeeklyReportDay {
  const WeeklyReportDay({
    required this.date,
    required this.executionsCount,
    required this.totalLaborHours,
    required this.totalVehicleHours,
    required this.quantityByUnit,
  });

  final String date;
  final int executionsCount;
  final double totalLaborHours;
  final double totalVehicleHours;
  final Map<String, String> quantityByUnit;

  double get activityScore {
    var qty = 0.0;
    for (final v in quantityByUnit.values) {
      qty += double.tryParse(v) ?? 0;
    }
    return executionsCount + totalLaborHours + totalVehicleHours + qty / 1000;
  }

  factory WeeklyReportDay.fromJson(Map<String, dynamic> json) {
    final raw = (json['quantity_by_unit'] as Map?) ?? {};
    return WeeklyReportDay(
      date: json['date'] as String? ?? '',
      executionsCount: json['executions_count'] as int? ?? 0,
      totalLaborHours: _toDouble(json['total_labor_hours']),
      totalVehicleHours: _toDouble(json['total_vehicle_hours']),
      quantityByUnit:
          raw.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
  });

  final String weekStart;
  final String weekEnd;
  final List<WeeklyReportDay> days;

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      weekStart: json['week_start'] as String? ?? '',
      weekEnd: json['week_end'] as String? ?? '',
      days: (json['days'] as List?)
              ?.map((e) => WeeklyReportDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
