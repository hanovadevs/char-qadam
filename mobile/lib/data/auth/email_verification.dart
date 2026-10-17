class EmailVerificationRequired implements Exception {
  final String token;
  final String email;
  final int resendAfterSeconds;

  const EmailVerificationRequired({
    required this.token,
    required this.email,
    required this.resendAfterSeconds,
  });

  factory EmailVerificationRequired.fromJson(Map<String, dynamic> json) =>
      EmailVerificationRequired(
        token: json['verification_token'] as String,
        email: json['email'] as String,
        resendAfterSeconds: json['resend_after_seconds'] as int? ?? 60,
      );
}
