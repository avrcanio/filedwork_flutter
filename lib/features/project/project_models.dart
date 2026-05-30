class FieldworkProject {
  const FieldworkProject({
    required this.id,
    required this.name,
    this.clientName = '',
    this.contractNumber = '',
    this.isActive = true,
  });

  final int id;
  final String name;
  final String clientName;
  final String contractNumber;
  final bool isActive;

  /// Kratka labela za UI: `#6 · Naziv projekta`.
  String get shortLabel => '#$id · $name';

  factory FieldworkProject.fromJson(Map<String, dynamic> json) {
    return FieldworkProject(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      contractNumber: json['contract_number'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
