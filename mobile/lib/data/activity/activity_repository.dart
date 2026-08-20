import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/activity_models.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ActivityRepository(apiClient: apiClient);
});

class ActivityRepository {
  final ApiClient apiClient;

  ActivityRepository({required this.apiClient});

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
      return SyncResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail']?.toString() ?? 'Failed to sync steps';
      throw Exception(detail);
    } catch (e) {
      throw Exception('Unexpected sync error: $e');
    }
  }

  /// Get aggregated step history for range: 'today' | 'week' | 'month'.
  Future<ActivityRangeModel> getActivityHistory({String range = 'today'}) async {
    try {
      final response = await apiClient.get(
        '/activity',
        queryParameters: {'range': range},
      );
      return ActivityRangeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail']?.toString() ?? 'Failed to load activity history';
      throw Exception(detail);
    } catch (e) {
      throw Exception('Unexpected error loading activity: $e');
    }
  }
}
