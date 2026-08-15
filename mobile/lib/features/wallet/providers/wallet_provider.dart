import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/voucher_models.dart';
import '../../../data/wallet/wallet_repository.dart';

class WalletState {
  final String selectedStatus; // active | redeemed | expired
  final List<VoucherModel> vouchers;
  final bool isLoading;
  final String? errorMessage;

  const WalletState({
    this.selectedStatus = 'active',
    this.vouchers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  WalletState copyWith({
    String? selectedStatus,
    List<VoucherModel>? vouchers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WalletState(
      selectedStatus: selectedStatus ?? this.selectedStatus,
      vouchers: vouchers ?? this.vouchers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return WalletNotifier(walletRepository: walletRepository);
});

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository walletRepository;

  WalletNotifier({required this.walletRepository})
      : super(const WalletState()) {
    fetchVouchers(state.selectedStatus);
  }

  Future<void> fetchVouchers(String status) async {
    state = state.copyWith(
      selectedStatus: status,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final list = await walletRepository.getVouchers(status: status);
      state = state.copyWith(vouchers: list, isLoading: false);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> refresh() async {
    await fetchVouchers(state.selectedStatus);
  }
}
