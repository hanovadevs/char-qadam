class VoucherModel {
  final String id;
  final String offerId;
  final String shortCode;
  final String status; // ISSUED | REDEEMED | EXPIRED | CANCELLED
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? redeemedAt;
  final String offerTitle;
  final String offerDiscountType;
  final double offerDiscountValue;

  VoucherModel({
    required this.id,
    required this.offerId,
    required this.shortCode,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    this.redeemedAt,
    required this.offerTitle,
    required this.offerDiscountType,
    required this.offerDiscountValue,
  });

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] as String,
      offerId: json['offer_id'] as String,
      shortCode: json['short_code'] as String,
      status: json['status'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      redeemedAt: json['redeemed_at'] != null ? DateTime.parse(json['redeemed_at'] as String) : null,
      offerTitle: json['offer_title'] as String,
      offerDiscountType: json['offer_discount_type'] as String,
      offerDiscountValue: (json['offer_discount_value'] as num).toDouble(),
    );
  }
}
