import '../work_items/work_item_models.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class WorkerLookup {
  const WorkerLookup({
    required this.id,
    required this.label,
    this.ime = '',
    this.prezime = '',
    this.pozicijaName = '',
  });

  final int id;
  final String label;
  final String ime;
  final String prezime;
  final String pozicijaName;

  factory WorkerLookup.fromJson(Map<String, dynamic> json) {
    return WorkerLookup(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      ime: json['ime'] as String? ?? '',
      prezime: json['prezime'] as String? ?? '',
      pozicijaName: json['pozicija_name'] as String? ?? '',
    );
  }
}

class VehicleLookup {
  const VehicleLookup({
    required this.id,
    required this.label,
    this.registracija = '',
    this.tip = '',
  });

  final int id;
  final String label;
  final String registracija;
  final String tip;

  factory VehicleLookup.fromJson(Map<String, dynamic> json) {
    return VehicleLookup(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      registracija: json['registracija'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
    );
  }
}

class WorkOrderAssignment {
  const WorkOrderAssignment({
    required this.id,
    this.zaposlenikId,
    required this.zaposlenikName,
    this.pozicijaName = '',
    this.voziloId,
    this.voziloLabel = '',
    this.datum,
    this.sati = 0,
    this.uloga = '',
    this.satnica = 0,
    this.trosak = 0,
    this.napomena = '',
  });

  final int id;
  final int? zaposlenikId;
  final String zaposlenikName;
  final String pozicijaName;
  final int? voziloId;
  final String voziloLabel;
  final String? datum;
  final double sati;
  final String uloga;
  final double satnica;
  final double trosak;
  final String napomena;

  factory WorkOrderAssignment.fromJson(Map<String, dynamic> json) {
    return WorkOrderAssignment(
      id: json['id'] as int,
      zaposlenikId: (json['zaposlenik'] as num?)?.toInt(),
      zaposlenikName: json['zaposlenik_name'] as String? ?? '',
      pozicijaName: json['pozicija_name'] as String? ?? '',
      voziloId: (json['vozilo'] as num?)?.toInt(),
      voziloLabel: json['vozilo_label'] as String? ?? '',
      datum: json['datum'] as String?,
      sati: _toDouble(json['sati']),
      uloga: json['uloga'] as String? ?? '',
      satnica: _toDouble(json['satnica']),
      trosak: _toDouble(json['trosak']),
      napomena: json['napomena'] as String? ?? '',
    );
  }
}

class WorkOrderVehicle {
  const WorkOrderVehicle({
    required this.id,
    this.voziloId,
    required this.voziloLabel,
    this.registracija = '',
    this.datum,
    this.sati = 0,
    this.cijena = 0,
    this.trosak = 0,
    this.napomena = '',
  });

  final int id;
  final int? voziloId;
  final String voziloLabel;
  final String registracija;
  final String? datum;
  final double sati;
  final double cijena;
  final double trosak;
  final String napomena;

  factory WorkOrderVehicle.fromJson(Map<String, dynamic> json) {
    return WorkOrderVehicle(
      id: json['id'] as int,
      voziloId: (json['vozilo'] as num?)?.toInt(),
      voziloLabel: json['vozilo_label'] as String? ?? '',
      registracija: json['registracija'] as String? ?? '',
      datum: json['datum'] as String?,
      sati: _toDouble(json['sati']),
      cijena: _toDouble(json['cijena']),
      trosak: _toDouble(json['trosak']),
      napomena: json['napomena'] as String? ?? '',
    );
  }
}

class MachineSummaryEntry {
  const MachineSummaryEntry({
    this.datum,
    required this.voziloId,
    required this.voziloLabel,
    required this.hours,
  });

  final String? datum;
  final int voziloId;
  final String voziloLabel;
  final double hours;

  factory MachineSummaryEntry.fromJson(Map<String, dynamic> json) {
    return MachineSummaryEntry(
      datum: json['datum'] as String?,
      voziloId: json['vozilo_id'] as int,
      voziloLabel: json['vozilo_label'] as String? ?? '',
      hours: _toDouble(json['hours']),
    );
  }
}

class EmployeeHoursSummary {
  const EmployeeHoursSummary({
    required this.zaposlenikId,
    required this.zaposlenikName,
    this.pozicijaName = '',
    this.totalHours = 0,
  });

  final int zaposlenikId;
  final String zaposlenikName;
  final String pozicijaName;
  final double totalHours;

  factory EmployeeHoursSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeHoursSummary(
      zaposlenikId: json['zaposlenik_id'] as int? ?? 0,
      zaposlenikName: json['zaposlenik_name'] as String? ?? '',
      pozicijaName: json['pozicija_name'] as String? ?? '',
      totalHours: _toDouble(json['total_hours']),
    );
  }
}

class EmployeeLaborDetailEntry {
  const EmployeeLaborDetailEntry({
    required this.executionDate,
    required this.workItemId,
    required this.operationName,
    this.roadSectionName = '',
    this.roadSideDisplay = '',
    this.laborHours = 0,
  });

  final String executionDate;
  final int workItemId;
  final String operationName;
  final String roadSectionName;
  final String roadSideDisplay;
  final double laborHours;

  String get locationLine {
    final parts = <String>[
      if (roadSectionName.isNotEmpty) roadSectionName,
      if (roadSideDisplay.isNotEmpty &&
          roadSideDisplay != 'Nije primjenjivo')
        roadSideDisplay,
    ];
    return parts.join(' · ');
  }

  factory EmployeeLaborDetailEntry.fromJson(Map<String, dynamic> json) {
    return EmployeeLaborDetailEntry(
      executionDate: json['execution_date'] as String? ?? '',
      workItemId: json['work_item_id'] as int? ?? 0,
      operationName: json['operation_name'] as String? ?? '',
      roadSectionName: json['road_section_name'] as String? ?? '',
      roadSideDisplay: json['road_side_display'] as String? ?? '',
      laborHours: _toDouble(json['labor_hours']),
    );
  }
}

class EmployeeLaborDetail {
  const EmployeeLaborDetail({
    required this.zaposlenikId,
    required this.zaposlenikName,
    this.totalHours = 0,
    this.entries = const [],
  });

  final int zaposlenikId;
  final String zaposlenikName;
  final double totalHours;
  final List<EmployeeLaborDetailEntry> entries;

  factory EmployeeLaborDetail.fromJson(Map<String, dynamic> json) {
    return EmployeeLaborDetail(
      zaposlenikId: json['zaposlenik_id'] as int? ?? 0,
      zaposlenikName: json['zaposlenik_name'] as String? ?? '',
      totalHours: _toDouble(json['total_hours']),
      entries: (json['entries'] as List?)
              ?.map(
                (e) => EmployeeLaborDetailEntry.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
  }
}

class WorkOrderRosterEntry {
  const WorkOrderRosterEntry({
    required this.id,
    required this.name,
    this.pozicijaName = '',
  });

  final int id;
  final String name;
  final String pozicijaName;
}

/// Kratki prikaz imena za uske mobilne kontrole (npr. „M. Vukman”).
String shortWorkerDisplayName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return fullName;
  if (parts.length == 1) return parts.first;
  final first = parts.first;
  if (first.isEmpty) return parts.last;
  return '${first[0]}. ${parts.last}';
}

List<WorkOrderRosterEntry> uniqueRosterFromAssignments(
  List<WorkOrderAssignment> assignments,
) {
  final seen = <int>{};
  final result = <WorkOrderRosterEntry>[];
  for (final assignment in assignments) {
    final id = assignment.zaposlenikId;
    if (id == null || !seen.add(id)) continue;
    result.add(
      WorkOrderRosterEntry(
        id: id,
        name: assignment.zaposlenikName,
        pozicijaName: assignment.pozicijaName,
      ),
    );
  }
  return result;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    required this.statusDisplay,
    this.projectId,
    this.projectName = '',
    this.clientName = '',
    this.description = '',
    this.scheduledDate,
    this.completedDate,
    this.totalValue = 0,
    this.laborCost = 0,
    this.vehicleCost = 0,
    this.workItems = const [],
    this.assignments = const [],
    this.vehicles = const [],
    this.machineSummary = const [],
    this.totalItemLaborHours = 0,
    this.employeeHoursSummary = const [],
  });

  final int id;
  final String number;
  final String title;
  final String status;
  final String statusDisplay;
  final int? projectId;
  final String projectName;
  final String clientName;
  final String description;
  final String? scheduledDate;
  final String? completedDate;
  final double totalValue;
  final double laborCost;
  final double vehicleCost;
  final List<WorkItem> workItems;
  final List<WorkOrderAssignment> assignments;
  final List<WorkOrderVehicle> vehicles;
  final List<MachineSummaryEntry> machineSummary;
  final double totalItemLaborHours;
  final List<EmployeeHoursSummary> employeeHoursSummary;

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
      projectId: (json['project'] as num?)?.toInt(),
      projectName: json['project_name'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String?,
      completedDate: json['completed_date'] as String?,
      totalValue: _toDouble(json['total_value']),
      laborCost: _toDouble(json['labor_cost']),
      vehicleCost: _toDouble(json['vehicle_cost']),
      workItems: (json['work_items'] as List?)
              ?.map((e) => WorkItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      assignments: (json['assignments'] as List?)
              ?.map((e) => WorkOrderAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      vehicles: (json['vehicles'] as List?)
              ?.map((e) => WorkOrderVehicle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      machineSummary: (json['machine_summary'] as List?)
              ?.map((e) => MachineSummaryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalItemLaborHours: _toDouble(json['total_item_labor_hours']),
      employeeHoursSummary: (json['employee_hours_summary'] as List?)
              ?.map((e) =>
                  EmployeeHoursSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
