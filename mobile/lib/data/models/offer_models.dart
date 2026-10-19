class OfferModel {
  final String id;
  final String partnerId;
  final String? partnerName;
  final String? partnerLocation;
  final String? partnerGoogleMapsUrl;
  final String? partnerCoverImageUrl;
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
  final bool alreadyRedeemed;

  OfferModel({
    required this.id,
    required this.partnerId,
    this.partnerName,
    this.partnerLocation,
    this.partnerGoogleMapsUrl,
    this.partnerCoverImageUrl,
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
    this.alreadyRedeemed = false,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      partnerName: json['partner_name'] as String?,
      partnerLocation: json['partner_location'] as String?,
      partnerGoogleMapsUrl: json['partner_google_maps_url'] as String?,
      partnerCoverImageUrl: json['partner_cover_image_url'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      pointsCost: json['points_cost'] as int,
      minBasket: (json['min_basket'] as num?)?.toDouble(),
      inventory: json['inventory'] as int?,
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      status: json['status'] as String,
      alreadyRedeemed: json['already_redeemed'] as bool? ?? false,
    );
  }

  OfferModel asClaimed() => OfferModel(
    id: id,
    partnerId: partnerId,
    partnerName: partnerName,
    partnerLocation: partnerLocation,
    partnerGoogleMapsUrl: partnerGoogleMapsUrl,
    partnerCoverImageUrl: partnerCoverImageUrl,
    title: title,
    description: description,
    discountType: discountType,
    discountValue: discountValue,
    pointsCost: pointsCost,
    minBasket: minBasket,
    inventory: inventory,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status,
    alreadyRedeemed: true,
  );
}

class RedeemResultModel {
  final String voucherId;
  final String shortCode;
  final String token;
  final DateTime expiresAt;
  final int pointsSpent;
  final int balance;
  final bool isReplay;
  final String? requestKey;

  RedeemResultModel({
    required this.voucherId,
    required this.shortCode,
    required this.token,
    required this.expiresAt,
    required this.pointsSpent,
    required this.balance,
    this.isReplay = false,
    this.requestKey,
  });

  factory RedeemResultModel.fromJson(
    Map<String, dynamic> json, {
    String? requestKey,
  }) {
    return RedeemResultModel(
      voucherId: json['voucher_id'] as String,
      shortCode: json['short_code'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      pointsSpent: json['points_spent'] as int,
      balance: json['balance'] as int,
      isReplay: json['is_replay'] as bool? ?? false,
      requestKey: requestKey,
    );
  }
}
