import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import '../api/api_client.dart';
import '../models/activity_models.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return ActivityRepository(apiClient: apiClient, cacheService: cacheService);
});

class ActivitySummaryUnavailable implements Exception {}

class ActivityRepository {
  final ApiClient apiClient;
  final CacheService cacheService;

  ActivityRepository({required this.apiClient, required this.cacheService});

  Future<SyncResponse?> getCachedTodaySummary() async {
    final cached = await cacheService.getCachedData('activity_today');
    return cached is Map<String, dynamic>
        ? SyncResponse.fromJson(cached)
        : null;
  }

  Future<SyncResponse> getTodaySummary() async {
    final Response response;
    try {
      response = await apiClient.get('/activity/today');
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) throw ActivitySummaryUnavailable();
      rethrow;
    }
    await cacheService.cacheData('activity_today', response.data);
    return SyncResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Post a daily step count to the backend server.
  /// Idempotent via [syncKey].
  Future<SyncResponse> syncActivity({
    required String localDate,
    required int eligibleSteps,
    required String source,
    required String syncKey,
  }) async {
    try {
      final response = await apiClient.post(
        '/activity/sync',
        data: {
          'local_date': localDate,
          'eligible_steps': eligibleSteps,
          'source': source,
          'sync_key': syncKey,
        },
      );
      await cacheService.cacheData('activity_today', response.data);
      return SyncResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail']?.toString() ?? 'Failed to sync steps';
      throw Exception(detail);
    } catch (e) {
      throw Exception('Unexpected sync error: $e');
    }
  }

  /// Get aggregated step history for range: 'today' | 'week' | 'month' (with offline cache fallback).
  Future<ActivityRangeModel> getActivityHistory({
    String range = 'today',
  }) async {
    final cacheKey = 'activity_history_$range';
    try {
      final response = await apiClient.get(
        '/activity',
        queryParameters: {'range': range},
      );
      final data = response.data as Map<String, dynamic>;
      await cacheService.cacheData(cacheKey, data);
      return ActivityRangeModel.fromJson(data);
    } catch (e) {
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return ActivityRangeModel.fromJson(cached);
      }
      if (e is DioException) {
        final detail =
            e.response?.data?['detail']?.toString() ??
            'Failed to load activity history';
        throw Exception(detail);
      }
      throw Exception('Unexpected error loading activity: $e');
    }
  }
}
