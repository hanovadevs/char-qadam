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
  final _claimedOfferIds = <String>{};

  RewardsRepository({
    required this.apiClient,
    required this.cacheService,
    RedemptionJournal? journal,
  }) : journal = journal ?? RedemptionJournal(userId: cacheService.userId);

  Future<Map<String, PendingPurchase>> pendingPurchases() => journal.pending();

  Future<List<OfferModel>?> getCachedOffers() async {
    final data = await cacheService.getCachedData('offers_catalog');
    return data is List
        ? data
              .map(
                (item) => OfferModel.fromJson(
                  _withClaim(item as Map<String, dynamic>),
                ),
              )
              .toList()
        : null;
  }

  Future<void> acknowledgePurchase(String offerId, String requestKey) =>
      journal.acknowledge(offerId, requestKey);

  Map<String, dynamic> _withClaim(Map<String, dynamic> item) {
    final id = item['id'] as String;
    if (item['already_redeemed'] == true) _claimedOfferIds.add(id);
    return {
      ...item,
      if (_claimedOfferIds.contains(id)) 'already_redeemed': true,
    };
  }

  Future<void> _rememberClaim(String offerId) async {
    _claimedOfferIds.add(offerId);
    // A local cache failure cannot turn a completed purchase into a failure.
    try {
      final saved = await cacheService.getCachedData('offers_catalog');
      if (saved is List) {
        await cacheService.cacheData(
          'offers_catalog',
          saved
              .map((item) => _withClaim(item as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (_) {}
  }

  /// Fetch active redeemable offers catalog (with offline cache fallback).
  Future<List<OfferModel>> getOffers() async {
    final cacheKey = await cacheService.scopedKey('offers_catalog');
    try {
      final response = await apiClient.get('/offers');
      final list = (response.data as List<dynamic>)
          .map((item) => _withClaim(item as Map<String, dynamic>))
          .toList();
      await cacheService.cacheData(cacheKey, list);
      return list.map(OfferModel.fromJson).toList();
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        throw Exception('Please sign in again to access this data.');
      }
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is List<dynamic>) {
        return cached
            .map(
              (json) =>
                  OfferModel.fromJson(_withClaim(json as Map<String, dynamic>)),
            )
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
      await _rememberClaim(offerId);
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
