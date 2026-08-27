import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/leaderboard_models.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return LeaderboardRepository(apiClient: apiClient);
});

class LeaderboardRepository {
  final ApiClient apiClient;

  LeaderboardRepository({required this.apiClient});

  Future<LeaderboardResponseModel> getLeaderboard({
    String scope = 'week',
    int limit = 50,
  }) async {
    try {
      final response = await apiClient.get(
        '/leaderboard',
        queryParameters: {
          'scope': scope,
          'limit': limit,
        },
      );
      return LeaderboardResponseModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to load leaderboard';
      throw Exception(msg);
    }
  }
}
