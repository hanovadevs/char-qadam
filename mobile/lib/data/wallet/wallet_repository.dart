import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/voucher_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WalletRepository(apiClient: apiClient);
});

class WalletRepository {
  final ApiClient apiClient;

  WalletRepository({required this.apiClient});

  /// Fetch user vouchers filtered by status: 'active' | 'redeemed' | 'expired'.
  Future<List<VoucherModel>> getVouchers({String status = 'active'}) async {
    try {
      final response = await apiClient.get(
        '/vouchers',
        queryParameters: {'status': status},
      );
      final list = response.data as List<dynamic>;
      return list.map((j) => VoucherModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail']?.toString() ?? 'Failed to load wallet vouchers');
    } catch (e) {
      throw Exception('Unexpected error loading wallet: $e');
    }
  }
}
