import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import '../api/api_client.dart';
import '../models/points_models.dart';

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return PointsRepository(apiClient: apiClient, cacheService: cacheService);
});

class PointsRepository {
  final ApiClient apiClient;
  final CacheService cacheService;

  PointsRepository({required this.apiClient, required this.cacheService});

  Future<BalanceModel?> getCachedBalance() async {
    final data = await cacheService.getCachedData('points_balance');
    return data is Map<String, dynamic> ? BalanceModel.fromJson(data) : null;
  }

  Future<LedgerPageModel?> getCachedHistory() async {
    final data = await cacheService.getCachedData('points_history_offset_0');
    return data is Map<String, dynamic> ? LedgerPageModel.fromJson(data) : null;
  }

  /// Fetch current balance and lifetime earned/spent stats (with offline cache fallback).
  Future<BalanceModel> getBalance() async {
    final cacheKey = await cacheService.scopedKey('points_balance');
    try {
      final response = await apiClient.get('/points/balance');
      final data = response.data as Map<String, dynamic>;
      await cacheService.cacheData(cacheKey, data);
      return BalanceModel.fromJson(data);
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        throw Exception('Please sign in again to access this data.');
      }
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return BalanceModel.fromJson(cached);
      }
      if (e is DioException) {
        throw Exception(
          e.response?.data?['detail']?.toString() ?? 'Failed to load balance',
        );
      }
      throw Exception('Unexpected error loading balance: $e');
    }
  }

  /// Fetch paginated points ledger entries (newest first, with offline cache fallback for initial page).
  Future<LedgerPageModel> getHistory({int limit = 20, int offset = 0}) async {
    final cacheKey = await cacheService.scopedKey('points_history_offset_$offset');
    try {
      final response = await apiClient.get(
        '/points/history',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data as Map<String, dynamic>;
      if (offset == 0) {
        await cacheService.cacheData(cacheKey, data);
      }
      return LedgerPageModel.fromJson(data);
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        throw Exception('Please sign in again to access this data.');
      }
      if (offset == 0) {
        final cached = await cacheService.getCachedData(cacheKey);
        if (cached != null && cached is Map<String, dynamic>) {
          return LedgerPageModel.fromJson(cached);
        }
      }
      if (e is DioException) {
        throw Exception(
          e.response?.data?['detail']?.toString() ?? 'Failed to load history',
        );
      }
      throw Exception('Unexpected error loading history: $e');
    }
  }
}
