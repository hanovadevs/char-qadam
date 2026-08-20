import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/offer_models.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RewardsRepository(apiClient: apiClient);
});

class RewardsRepository {
  final ApiClient apiClient;

  RewardsRepository({required this.apiClient});

  /// Fetch active redeemable offers catalog.
  Future<List<OfferModel>> getOffers() async {
    try {
      final response = await apiClient.get('/offers');
      final list = response.data as List<dynamic>;
      return list.map((json) => OfferModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to load offers catalog');
    } catch (e) {
      throw Exception('Unexpected error loading catalog: $e');
    }
  }

  /// Redeem an offer by ID, spending points and issuing a voucher.
  Future<RedeemResultModel> redeemOffer(String offerId) async {
    try {
      final response = await apiClient.post('/offers/$offerId/redeem');
      return RedeemResultModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail']?.toString();
      if (e.response?.statusCode == 402) {
        throw Exception(detail ?? 'Insufficient points balance');
      } else if (e.response?.statusCode == 409) {
        throw Exception(detail ?? 'Offer is out of stock or expired');
      }
      throw Exception(detail ?? 'Failed to redeem offer');
    } catch (e) {
      throw Exception('Unexpected error during redemption: $e');
    }
  }
}
