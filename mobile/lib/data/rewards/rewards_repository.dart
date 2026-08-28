import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import '../api/api_client.dart';
import '../models/offer_models.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return RewardsRepository(apiClient: apiClient, cacheService: cacheService);
});

class RewardsRepository {
  final ApiClient apiClient;
  final CacheService cacheService;

  RewardsRepository({required this.apiClient, required this.cacheService});

  /// Fetch active redeemable offers catalog (with offline cache fallback).
  Future<List<OfferModel>> getOffers() async {
    const cacheKey = 'offers_catalog';
    try {
      final response = await apiClient.get('/offers');
      final list = response.data as List<dynamic>;
      await cacheService.cacheData(cacheKey, list);
      return list.map((json) => OfferModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is List<dynamic>) {
        return cached.map((json) => OfferModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      if (e is DioException) {
        throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to load offers catalog');
      }
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
