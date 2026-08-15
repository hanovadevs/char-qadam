import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/points_models.dart';

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PointsRepository(apiClient: apiClient);
});

class PointsRepository {
  final ApiClient apiClient;

  PointsRepository({required this.apiClient});

  /// Fetch current balance and lifetime earned/spent stats.
  Future<BalanceModel> getBalance() async {
    try {
      final response = await apiClient.get('/points/balance');
      return BalanceModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to load balance');
    } catch (e) {
      throw Exception('Unexpected error loading balance: $e');
    }
  }

  /// Fetch paginated points ledger entries (newest first).
  Future<LedgerPageModel> getHistory({int limit = 20, int offset = 0}) async {
    try {
      final response = await apiClient.get(
        '/points/history',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return LedgerPageModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to load history');
    } catch (e) {
      throw Exception('Unexpected error loading history: $e');
    }
  }
}
