import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/env_config.dart';
import '../models/merchant_models.dart';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  return MerchantRepository();
});

class MerchantRepository {
  Dio _createPartnerDio(String partnerApiKey) {
    return Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Partner-Key': partnerApiKey,
        },
      ),
    );
  }

  Future<PartnerInfoModel> getPartnerInfo(String partnerApiKey) async {
    try {
      final dio = _createPartnerDio(partnerApiKey);
      final response = await dio.get('/partner/v1/info');
      return PartnerInfoModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Invalid Partner API Key';
      throw Exception(msg);
    }
  }

  Future<VoucherValidationModel> validateVoucher({
    required String partnerApiKey,
    required String codeOrToken,
  }) async {
    try {
      final dio = _createPartnerDio(partnerApiKey);
      final response = await dio.post(
        '/partner/v1/vouchers/validate',
        data: {'token': codeOrToken.trim()},
      );
      return VoucherValidationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Voucher validation failed';
      throw Exception(msg);
    }
  }

  Future<PartnerRedemptionResultModel> redeemVoucher({
    required String partnerApiKey,
    required String nonce,
    String? storeId,
    String? orderReference,
  }) async {
    try {
      final dio = _createPartnerDio(partnerApiKey);
      final response = await dio.post(
        '/partner/v1/vouchers/redeem',
        data: {
          'nonce': nonce,
          if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
          if (orderReference != null && orderReference.isNotEmpty)
            'order_reference': orderReference,
        },
      );
      return PartnerRedemptionResultModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Voucher redemption failed';
      throw Exception(msg);
    }
  }

  Future<List<RedemptionHistoryItemModel>> getRedemptions(String partnerApiKey) async {
    try {
      final dio = _createPartnerDio(partnerApiKey);
      final response = await dio.get('/partner/v1/redemptions');
      return (response.data as List<dynamic>)
          .map((e) => RedemptionHistoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to load redemption history';
      throw Exception(msg);
    }
  }
}
