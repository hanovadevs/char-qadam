class UserModel {
  final String id;
  final String email;
  final String status;
  final String role;
  final String? partnerId;
  final String? partnerName;
  final String? country;
  final String? timezone;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.status,
    this.role = 'USER',
    this.partnerId,
    this.partnerName,
    this.country,
    this.timezone,
    required this.createdAt,
  });

  bool get isMerchant => role.toUpperCase() == 'MERCHANT';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      role: json['role'] as String? ?? 'USER',
      partnerId: json['partner_id'] as String?,
      partnerName: json['partner_name'] as String?,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'status': status,
      'role': role,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'country': country,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? status,
    String? role,
    String? partnerId,
    String? partnerName,
    String? country,
    String? timezone,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      status: status ?? this.status,
      role: role ?? this.role,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
