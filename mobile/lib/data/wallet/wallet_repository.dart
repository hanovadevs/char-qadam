import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cache_service.dart';
import '../api/api_client.dart';
import '../models/voucher_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return WalletRepository(apiClient: apiClient, cacheService: cacheService);
});

class WalletRepository {
  final ApiClient apiClient;
  final CacheService cacheService;

  WalletRepository({required this.apiClient, required this.cacheService});

  Future<List<VoucherModel>?> getCachedVouchers(String status) async {
    final data = await cacheService.getCachedData('wallet_vouchers_$status');
    return data is List
        ? data
              .map(
                (item) => VoucherModel.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : null;
  }

  /// Fetch user vouchers filtered by status: 'active' | 'redeemed' | 'expired' (with offline cache fallback).
  Future<List<VoucherModel>> getVouchers({String status = 'active'}) async {
    final cacheKey = await cacheService.scopedKey('wallet_vouchers_$status');
    try {
      final response = await apiClient.get(
        '/vouchers',
        queryParameters: {'status': status},
      );
      final list = response.data as List<dynamic>;
      await cacheService.cacheData(cacheKey, list);
      return list
          .map((j) => VoucherModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        throw Exception('Please sign in again to access this data.');
      }
      final cached = await cacheService.getCachedData(cacheKey);
      if (cached != null && cached is List<dynamic>) {
        return cached
            .map((j) => VoucherModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      if (e is DioException) {
        throw Exception(
          e.response?.data?['detail']?.toString() ??
              'Failed to load wallet vouchers',
        );
      }
      throw Exception('Unexpected error loading wallet: $e');
    }
  }
}
