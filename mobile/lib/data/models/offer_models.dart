class OfferModel {
  final String id;
  final String partnerId;
  final String title;
  final String? description;
  final String discountType;
  final double discountValue;
  final int pointsCost;
  final double? minBasket;
  final int? inventory;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;

  OfferModel({
    required this.id,
    required this.partnerId,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.pointsCost,
    this.minBasket,
    this.inventory,
    this.startsAt,
    this.endsAt,
    required this.status,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      pointsCost: json['points_cost'] as int,
      minBasket: (json['min_basket'] as num?)?.toDouble(),
      inventory: json['inventory'] as int?,
      startsAt: json['starts_at'] != null ? DateTime.parse(json['starts_at'] as String) : null,
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
      status: json['status'] as String,
    );
  }
}

class RedeemResultModel {
  final String voucherId;
  final String shortCode;
  final String token;
  final DateTime expiresAt;
  final int pointsSpent;
  final int balance;

  RedeemResultModel({
    required this.voucherId,
    required this.shortCode,
    required this.token,
    required this.expiresAt,
    required this.pointsSpent,
    required this.balance,
  });

  factory RedeemResultModel.fromJson(Map<String, dynamic> json) {
    return RedeemResultModel(
      voucherId: json['voucher_id'] as String,
      shortCode: json['short_code'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      pointsSpent: json['points_spent'] as int,
      balance: json['balance'] as int,
    );
  }
}
