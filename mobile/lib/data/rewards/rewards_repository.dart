import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import '../api/api_client.dart';
import '../models/offer_models.dart';
import 'redemption_journal.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return RewardsRepository(apiClient: apiClient, cacheService: cacheService);
});

class RewardsRepository {
  final ApiClient apiClient;
  final CacheService cacheService;
  final RedemptionJournal journal;

  RewardsRepository({
    required this.apiClient,
    required this.cacheService,
    RedemptionJournal? journal,
  }) : journal = journal ?? RedemptionJournal(userId: cacheService.userId);

  Future<Map<String, PendingPurchase>> pendingPurchases() => journal.pending();

  Future<void> acknowledgePurchase(String offerId, String requestKey) =>
      journal.acknowledge(offerId, requestKey);

  /// Fetch active redeemable offers catalog (with offline cache fallback).
  Future<List<OfferModel>> getOffers() async {
    const cacheKey = 'offers_catalog';
    try {
      final response = await apiClient.get('/offers');
      final list = response.data as List<dynamic>;
      await cacheService.cacheData(cacheKey, list);
      return list
          .map((json) => OfferModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is List<dynamic>) {
        return cached
            .map((json) => OfferModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      if (e is DioException) {
        throw Exception(
          e.response?.data?['detail']?.toString() ??
              'Failed to load offers catalog',
        );
      }
      throw Exception('Unexpected error loading catalog: $e');
    }
  }

  /// Redeem an offer by ID, spending points and issuing a voucher.
  Future<RedeemResultModel> redeemOffer(
    String offerId, {
    int? expectedPointsCost,
  }) async {
    final purchase = await journal.getOrCreate(
      offerId,
      expectedPointsCost: expectedPointsCost,
    );
    final requestKey = purchase.requestKey;
    try {
      final response = await apiClient.post(
        '/offers/$offerId/redeem',
        data: {'expected_points_cost': purchase.expectedPointsCost},
        options: Options(headers: {'Idempotency-Key': requestKey}),
      );
      return RedeemResultModel.fromJson(
        response.data as Map<String, dynamic>,
        requestKey: requestKey,
      );
    } on DioException catch (e) {
      if ([400, 402, 404, 409, 410, 422].contains(e.response?.statusCode)) {
        await journal.acknowledge(offerId, requestKey);
      }
      final payload = e.response?.data;
      final detail = payload is Map ? payload['detail']?.toString() : null;
      if (e.response?.statusCode == 402) {
        throw Exception(detail ?? 'Insufficient points balance');
      } else if (e.response?.statusCode == 409) {
        throw Exception(detail ?? 'Offer is out of stock or expired');
      }
      throw Exception(
        detail ??
            'Could not confirm the purchase. Use Recover purchase to check it safely.',
      );
    } catch (e) {
      throw Exception('Unexpected error during redemption: $e');
    }
  }
}
