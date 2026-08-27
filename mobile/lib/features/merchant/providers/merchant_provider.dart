import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  return MerchantNotifier(repository: repository);
});

class MerchantNotifier extends StateNotifier<MerchantState> {
  final MerchantRepository repository;
  static const _storage = FlutterSecureStorage();
  static const _keyStore = 'merchant_partner_api_key';
  static const _storeIdKey = 'merchant_store_id';

  MerchantNotifier({required this.repository}) : super(const MerchantState()) {
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedKey = await _storage.read(key: _keyStore);
      final savedStoreId = await _storage.read(key: _storeIdKey) ?? 'STORE-01';

      if (savedKey != null && savedKey.isNotEmpty) {
        state = state.copyWith(partnerApiKey: savedKey, storeId: savedStoreId);
        await verifyApiKey(savedKey);
      }
    } catch (_) {}
  }

  Future<bool> setCredentials({required String apiKey, required String storeId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await repository.getPartnerInfo(apiKey.trim());
      await _storage.write(key: _keyStore, value: apiKey.trim());
      await _storage.write(key: _storeIdKey, value: storeId.trim());

      state = state.copyWith(
        isLoading: false,
        partnerApiKey: apiKey.trim(),
        storeId: storeId.trim(),
        partnerInfo: info,
        errorMessage: null,
      );
      await loadHistory();
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> verifyApiKey(String apiKey) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await repository.getPartnerInfo(apiKey.trim());
      state = state.copyWith(partnerInfo: info, isLoading: false);
      await loadHistory();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isLoading: false,
        clearPartnerInfo: true,
        errorMessage: 'Credentials verification failed: $msg',
      );
    }
  }

  Future<bool> validateCode(String codeOrToken) async {
    final key = state.partnerApiKey;
    if (key == null || key.isEmpty) {
      state = state.copyWith(errorMessage: 'Please configure Merchant Partner Key first');
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearMessages: true,
      clearValidation: true,
    );

    try {
      final validation = await repository.validateVoucher(
        partnerApiKey: key,
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
    final key = state.partnerApiKey;
    final val = state.activeValidation;
    if (key == null || val == null) return false;

    state = state.copyWith(isRedeeming: true, clearMessages: true);

    try {
      final result = await repository.redeemVoucher(
        partnerApiKey: key,
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
    final key = state.partnerApiKey;
    if (key == null || key.isEmpty) return;

    try {
      final history = await repository.getRedemptions(key);
      state = state.copyWith(history: history);
    } catch (_) {}
  }

  void clearActiveValidation() {
    state = state.copyWith(clearValidation: true, clearMessages: true);
  }

  Future<void> disconnectTerminal() async {
    try {
      await _storage.delete(key: _keyStore);
      await _storage.delete(key: _storeIdKey);
    } catch (_) {}
    state = const MerchantState();
  }
}
