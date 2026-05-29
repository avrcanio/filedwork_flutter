double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class WorkItem {
  const WorkItem({
    required this.id,
    required this.workOrder,
    required this.quantity,
    required this.executedQuantity,
    required this.remainingQuantity,
    required this.isFullyExecuted,
    required this.progressPercent,
    this.operationTypeId,
    this.operationTypeName = '',
    this.operationTypeUnit = '',
    this.roadSectionName = '',
    this.roadSideDisplay = '',
    this.description = '',
    this.notes = '',
  });

  final int id;
  final int workOrder;
  final double quantity;
  final double executedQuantity;
  final double remainingQuantity;
  final bool isFullyExecuted;
  final double progressPercent;
  final int? operationTypeId;
  final String operationTypeName;
  final String operationTypeUnit;
  final String roadSectionName;
  final String roadSideDisplay;
  final String description;
  final String notes;

  String get unit => operationTypeUnit;

  String get title {
    if (operationTypeName.isNotEmpty) return operationTypeName;
    if (description.isNotEmpty) return description;
    return 'Stavka #$id';
  }

  /// Strana ceste za prikaz; prazno za "Nije primjenjivo" (notap).
  String get roadSideLabel {
    if (roadSideDisplay.isEmpty || roadSideDisplay == 'Nije primjenjivo') {
      return '';
    }
    return roadSideDisplay;
  }

  /// Lokacija (dionica) i strana ceste spojeni u jednu liniju.
  String get locationWithRoadSide {
    return [
      if (roadSectionName.isNotEmpty) roadSectionName,
      if (roadSideLabel.isNotEmpty) roadSideLabel,
    ].join(' - ');
  }

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    return WorkItem(
      id: json['id'] as int,
      workOrder: json['work_order'] as int? ?? 0,
      quantity: _toDouble(json['quantity']),
      executedQuantity: _toDouble(json['executed_quantity']),
      remainingQuantity: _toDouble(json['remaining_quantity']),
      isFullyExecuted: json['is_fully_executed'] as bool? ?? false,
      progressPercent: _toDouble(json['execution_progress_percent']),
      operationTypeId: json['operation_type'] as int?,
      operationTypeName: json['operation_type_name'] as String? ?? '',
      operationTypeUnit: json['operation_type_unit'] as String? ?? '',
      roadSectionName: json['road_section_name'] as String? ?? '',
      roadSideDisplay: json['road_side_display'] as String? ?? '',
      description: json['description'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}
