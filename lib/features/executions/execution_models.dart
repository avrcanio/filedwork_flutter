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
    this.uploadedAt,
  });

  final int id;
  final String url;
  final String caption;
  final String? uploadedAt;

  factory ExecutionPhoto.fromJson(Map<String, dynamic> json) {
    return ExecutionPhoto(
      id: json['id'] as int,
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      uploadedAt: json['uploaded_at'] as String?,
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
  final List<ExecutionPhoto> photoUrls;

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
      photoUrls: (json['photo_urls'] as List?)
              ?.map((e) => ExecutionPhoto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
