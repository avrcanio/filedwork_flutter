double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class ExecutionPhoto {
  const ExecutionPhoto({
    required this.id,
    required this.url,
    this.caption = '',
    this.phase = 'after',
    this.uploadedAt,
    this.source = 'execution',
  });

  final int id;
  final String url;
  final String caption;
  final String phase;
  final String? uploadedAt;
  final String source;

  String get phaseLabel {
    switch (phase) {
      case 'before':
        return 'Prije';
      case 'after':
        return 'Poslije';
      default:
        return phase;
    }
  }

  factory ExecutionPhoto.fromJson(Map<String, dynamic> json) {
    return ExecutionPhoto(
      id: json['id'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      phase: json['phase'] as String? ?? 'after',
      uploadedAt: json['uploaded_at'] as String?,
      source: json['source'] as String? ?? 'execution',
    );
  }
}

class WorkExecution {
  const WorkExecution({
    required this.id,
    required this.workItem,
    required this.quantityExecuted,
    required this.status,
    this.statusDisplay = '',
    this.workItemDescription = '',
    this.workOrderNumber = '',
    this.executedByName = '',
    this.executionDate,
    this.notes = '',
    this.operationTypeUnit = '',
    this.roadSectionName = '',
    this.roadSideDisplay = '',
    this.photoUrls = const [],
  });

  final int id;
  final int workItem;
  final double quantityExecuted;
  final String status;
  final String statusDisplay;
  final String workItemDescription;
  final String workOrderNumber;
  final String executedByName;
  final String? executionDate;
  final String notes;
  final String operationTypeUnit;
  final String roadSectionName;
  final String roadSideDisplay;
  final List<ExecutionPhoto> photoUrls;

  String get locationLine {
    final parts = <String>[
      if (roadSectionName.isNotEmpty) roadSectionName,
      if (roadSideDisplay.isNotEmpty && roadSideDisplay != 'Nije primjenjivo')
        roadSideDisplay,
    ];
    return parts.join(' · ');
  }

  String get quantityWithUnit {
    final unit = operationTypeUnit;
    final qty = quantityExecuted == quantityExecuted.roundToDouble()
        ? quantityExecuted.toStringAsFixed(0)
        : quantityExecuted.toString();
    return unit.isEmpty ? qty : '$qty $unit';
  }

  factory WorkExecution.fromJson(Map<String, dynamic> json) {
    return WorkExecution(
      id: json['id'] as int,
      workItem: json['work_item'] as int? ?? 0,
      quantityExecuted: _toDouble(json['quantity_executed']),
      status: json['status'] as String? ?? '',
      statusDisplay: json['status_display'] as String? ?? '',
      workItemDescription: json['work_item_description'] as String? ?? '',
      workOrderNumber: json['work_order_number'] as String? ?? '',
      executedByName: json['executed_by_name'] as String? ?? '',
      executionDate: json['execution_date'] as String?,
      notes: json['notes'] as String? ?? '',
      operationTypeUnit: json['operation_type_unit'] as String? ?? '',
      roadSectionName: json['road_section_name'] as String? ?? '',
      roadSideDisplay: json['road_side_display'] as String? ?? '',
      photoUrls: (json['photo_urls'] as List?)
              ?.map((e) => ExecutionPhoto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
