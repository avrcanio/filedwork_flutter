class FieldworkCapabilities {
  const FieldworkCapabilities({
    this.ownZaposlenikId,
    this.ownZaposlenikName,
    this.managedZaposlenikIds = const [],
    this.canAddVehicles = false,
    this.canEditHours = false,
  });

  static const empty = FieldworkCapabilities();

  final int? ownZaposlenikId;
  final String? ownZaposlenikName;
  final List<int> managedZaposlenikIds;
  final bool canAddVehicles;
  final bool canEditHours;

  factory FieldworkCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return FieldworkCapabilities.empty;
    final managed = (json['managed_zaposlenik_ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [];
    return FieldworkCapabilities(
      ownZaposlenikId: (json['own_zaposlenik_id'] as num?)?.toInt(),
      ownZaposlenikName: json['own_zaposlenik_name'] as String?,
      managedZaposlenikIds: managed,
      canAddVehicles: json['can_add_vehicles'] as bool? ?? false,
      canEditHours: json['can_edit_hours'] as bool? ?? false,
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.fieldwork = FieldworkCapabilities.empty,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final FieldworkCapabilities fieldwork;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fieldwork: FieldworkCapabilities.fromJson(
        json['fieldwork'] as Map<String, dynamic>?,
      ),
    );
  }

  AuthUser copyWith({FieldworkCapabilities? fieldwork}) {
    return AuthUser(
      id: id,
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      fieldwork: fieldwork ?? this.fieldwork,
    );
  }
}
