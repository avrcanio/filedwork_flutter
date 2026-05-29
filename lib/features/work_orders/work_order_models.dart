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
    this.laborCost = 0,
    this.vehicleCost = 0,
    this.workItems = const [],
    this.assignments = const [],
    this.vehicles = const [],
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
  final double laborCost;
  final double vehicleCost;
  final List<WorkItem> workItems;
  final List<WorkOrderAssignment> assignments;
  final List<WorkOrderVehicle> vehicles;

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
    );
  }
}
