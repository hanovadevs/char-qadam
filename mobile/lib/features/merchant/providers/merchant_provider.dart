import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/auth/auth_state_provider.dart';
import '../../../data/merchant/merchant_repository.dart';
import '../../../data/models/merchant_models.dart';

class MerchantState {
  final String? partnerApiKey;
  final String storeId;
  final PartnerInfoModel? partnerInfo;
  final VoucherValidationModel? activeValidation;
  final PartnerRedemptionResultModel? lastRedemption;
  final List<RedemptionHistoryItemModel> history;
  final bool isLoading;
  final bool isRedeeming;
  final String? errorMessage;
  final String? successMessage;

  const MerchantState({
    this.partnerApiKey,
    this.storeId = 'STORE-01',
    this.partnerInfo,
    this.activeValidation,
    this.lastRedemption,
    this.history = const [],
    this.isLoading = false,
    this.isRedeeming = false,
    this.errorMessage,
    this.successMessage,
  });

  MerchantState copyWith({
    String? partnerApiKey,
    String? storeId,
    PartnerInfoModel? partnerInfo,
    VoucherValidationModel? activeValidation,
    PartnerRedemptionResultModel? lastRedemption,
    List<RedemptionHistoryItemModel>? history,
    bool? isLoading,
    bool? isRedeeming,
    String? errorMessage,
    String? successMessage,
    bool clearValidation = false,
    bool clearMessages = false,
    bool clearPartnerInfo = false,
  }) {
    return MerchantState(
      partnerApiKey: partnerApiKey ?? this.partnerApiKey,
      storeId: storeId ?? this.storeId,
      partnerInfo: clearPartnerInfo ? null : (partnerInfo ?? this.partnerInfo),
      activeValidation: clearValidation ? null : (activeValidation ?? this.activeValidation),
      lastRedemption: lastRedemption ?? this.lastRedemption,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

final merchantProvider =
    StateNotifierProvider<MerchantNotifier, MerchantState>((ref) {
  final repository = ref.watch(merchantRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  return MerchantNotifier(repository: repository, authState: authState);
});

class MerchantNotifier extends StateNotifier<MerchantState> {
  final MerchantRepository repository;
  final AuthState authState;

  MerchantNotifier({required this.repository, required this.authState})
      : super(const MerchantState()) {
    initMerchantSession();
  }

  Future<void> initMerchantSession() async {
    // If merchant has cached partner name from user model, populate initial state
    final user = authState.user;
    if (user != null && user.partnerId != null) {
      state = state.copyWith(
        partnerInfo: PartnerInfoModel(
          partnerId: user.partnerId!,
          name: user.partnerName ?? 'Merchant Store',
          status: 'ACTIVE',
        ),
      );
    }

    await loadPartnerInfo();
    await loadHistory();
  }

  Future<void> loadPartnerInfo() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await repository.getPartnerInfo();
      state = state.copyWith(partnerInfo: info, isLoading: false);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<bool> validateCode(String codeOrToken) async {
    state = state.copyWith(
      isLoading: true,
      clearMessages: true,
      clearValidation: true,
    );

    try {
      final validation = await repository.validateVoucher(
        codeOrToken: codeOrToken,
      );
      state = state.copyWith(
        isLoading: false,
        activeValidation: validation,
      );
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<bool> confirmRedeem({String? orderReference}) async {
    final val = state.activeValidation;
    if (val == null) return false;

    state = state.copyWith(isRedeeming: true, clearMessages: true);

    try {
      final result = await repository.redeemVoucher(
        nonce: val.nonce,
        storeId: state.storeId,
        orderReference: orderReference,
      );

      state = state.copyWith(
        isRedeeming: false,
        lastRedemption: result,
        successMessage: 'VOUCHER REDEEMED • DISCOUNT ${val.discountDisplay} APPLIED',
        clearValidation: true,
      );
      await loadHistory();
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isRedeeming: false,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<void> loadHistory() async {
    try {
      final history = await repository.getRedemptions();
      state = state.copyWith(history: history);
    } catch (_) {}
  }

  void clearActiveValidation() {
    state = state.copyWith(clearValidation: true, clearMessages: true);
  }

  void setStoreId(String storeId) {
    state = state.copyWith(storeId: storeId.trim());
  }
}
