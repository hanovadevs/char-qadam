class PartnerInfoModel {
  final String partnerId;
  final String name;
  final String status;

  const PartnerInfoModel({
    required this.partnerId,
    required this.name,
    required this.status,
  });

  factory PartnerInfoModel.fromJson(Map<String, dynamic> json) {
    return PartnerInfoModel(
      partnerId: json['partner_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partner_id': partnerId,
      'name': name,
      'status': status,
    };
  }
}

class VoucherValidationModel {
  final String voucherId;
  final String shortCode;
  final String offerTitle;
  final String discountType;
  final double discountValue;
  final DateTime expiresAt;
  final String nonce;

  const VoucherValidationModel({
    required this.voucherId,
    required this.shortCode,
    required this.offerTitle,
    required this.discountType,
    required this.discountValue,
    required this.expiresAt,
    required this.nonce,
  });

  factory VoucherValidationModel.fromJson(Map<String, dynamic> json) {
    return VoucherValidationModel(
      voucherId: json['voucher_id'] as String? ?? '',
      shortCode: json['short_code'] as String? ?? '',
      offerTitle: json['offer_title'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? 'PERCENT',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now(),
      nonce: json['nonce'] as String? ?? '',
    );
  }

  String get discountDisplay {
    if (discountType == 'PERCENT') {
      return '${discountValue.toInt()}% OFF';
    } else if (discountType == 'FIXED_AMOUNT') {
      return 'Rs. ${discountValue.toInt()} OFF';
    } else {
      return 'FREE ITEM';
    }
  }
}

class PartnerRedemptionResultModel {
  final String voucherId;
  final String shortCode;
  final DateTime redeemedAt;
  final String discountType;
  final double discountValue;

  const PartnerRedemptionResultModel({
    required this.voucherId,
    required this.shortCode,
    required this.redeemedAt,
    required this.discountType,
    required this.discountValue,
  });

  factory PartnerRedemptionResultModel.fromJson(Map<String, dynamic> json) {
    return PartnerRedemptionResultModel(
      voucherId: json['voucher_id'] as String? ?? '',
      shortCode: json['short_code'] as String? ?? '',
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.parse(json['redeemed_at'] as String)
          : DateTime.now(),
      discountType: json['discount_type'] as String? ?? 'PERCENT',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RedemptionHistoryItemModel {
  final String id;
  final String voucherId;
  final String shortCode;
  final String? storeId;
  final String? orderReference;
  final double discountValue;
  final DateTime redeemedAt;

  const RedemptionHistoryItemModel({
    required this.id,
    required this.voucherId,
    required this.shortCode,
    this.storeId,
    this.orderReference,
    required this.discountValue,
    required this.redeemedAt,
  });

  factory RedemptionHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return RedemptionHistoryItemModel(
      id: json['id'] as String? ?? '',
      voucherId: json['voucher_id'] as String? ?? '',
      shortCode: json['short_code'] as String? ?? '',
      storeId: json['store_id'] as String?,
      orderReference: json['order_reference'] as String?,
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.parse(json['redeemed_at'] as String)
          : DateTime.now(),
    );
  }
}
