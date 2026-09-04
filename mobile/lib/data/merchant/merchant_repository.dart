import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/merchant_models.dart';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MerchantRepository(apiClient: apiClient);
});

class MerchantRepository {
  final ApiClient apiClient;

  MerchantRepository({required this.apiClient});

  Future<PartnerInfoModel> getPartnerInfo({String? partnerApiKey}) async {
    try {
      final options = partnerApiKey != null && partnerApiKey.isNotEmpty
          ? Options(headers: {'X-Partner-Key': partnerApiKey})
          : null;
      final response = await apiClient.get('/partner/v1/info', options: options);
      return PartnerInfoModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to load merchant store info';
      throw Exception(msg);
    }
  }

  Future<VoucherValidationModel> validateVoucher({
    required String codeOrToken,
    String? partnerApiKey,
  }) async {
    try {
      final options = partnerApiKey != null && partnerApiKey.isNotEmpty
          ? Options(headers: {'X-Partner-Key': partnerApiKey})
          : null;
      final response = await apiClient.post(
        '/partner/v1/vouchers/validate',
        data: {'token': codeOrToken.trim()},
        options: options,
      );
      return VoucherValidationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Voucher validation failed';
      throw Exception(msg);
    }
  }

  Future<PartnerRedemptionResultModel> redeemVoucher({
    required String nonce,
    String? storeId,
    String? orderReference,
    String? partnerApiKey,
  }) async {
    try {
      final options = partnerApiKey != null && partnerApiKey.isNotEmpty
          ? Options(headers: {'X-Partner-Key': partnerApiKey})
          : null;
      final response = await apiClient.post(
        '/partner/v1/vouchers/redeem',
        data: {
          'nonce': nonce,
          if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
          if (orderReference != null && orderReference.isNotEmpty)
            'order_reference': orderReference,
        },
        options: options,
      );
      return PartnerRedemptionResultModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Voucher redemption failed';
      throw Exception(msg);
    }
  }

  Future<List<RedemptionHistoryItemModel>> getRedemptions({String? partnerApiKey}) async {
    try {
      final options = partnerApiKey != null && partnerApiKey.isNotEmpty
          ? Options(headers: {'X-Partner-Key': partnerApiKey})
          : null;
      final response = await apiClient.get('/partner/v1/redemptions', options: options);
      return (response.data as List<dynamic>)
          .map((e) => RedemptionHistoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to load redemption history';
      throw Exception(msg);
    }
  }
}
