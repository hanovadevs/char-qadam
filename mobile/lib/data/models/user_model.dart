class UserModel {
  final String id;
  final String email;
  final String status;
  final String? country;
  final String? timezone;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.status,
    this.country,
    this.timezone,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      status: json['status'] as String,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'status': status,
      'country': country,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
