import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/offer_models.dart';
import '../../../data/rewards/rewards_repository.dart';
import '../../../data/rewards/redemption_journal.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../points/providers/points_provider.dart';

class RewardsState {
  final List<OfferModel> offers;
  final bool isLoading;
  final bool isRedeeming;
  final String? errorMessage;
  final RedeemResultModel? lastRedeemedResult;
  final Map<String, PendingPurchase> pendingPurchases;

  const RewardsState({
    this.offers = const [],
    this.isLoading = false,
    this.isRedeeming = false,
    this.errorMessage,
    this.lastRedeemedResult,
    this.pendingPurchases = const {},
  });

  RewardsState copyWith({
    List<OfferModel>? offers,
    bool? isLoading,
    bool? isRedeeming,
    String? errorMessage,
    RedeemResultModel? lastRedeemedResult,
    Map<String, PendingPurchase>? pendingPurchases,
  }) {
    return RewardsState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      errorMessage: errorMessage,
      lastRedeemedResult: lastRedeemedResult ?? this.lastRedeemedResult,
      pendingPurchases: pendingPurchases ?? this.pendingPurchases,
    );
  }
}

final rewardsProvider = StateNotifierProvider<RewardsNotifier, RewardsState>((
  ref,
) {
  final rewardsRepository = ref.watch(rewardsRepositoryProvider);
  return RewardsNotifier(
    rewardsRepository: rewardsRepository,
    onRedeemed: () {
      ref.read(walletProvider.notifier).refreshAfterMutation();
      ref.read(pointsProvider.notifier).refreshAfterMutation();
    },
  );
});

class RewardsNotifier extends StateNotifier<RewardsState> {
  final RewardsRepository rewardsRepository;
  final void Function()? onRedeemed;
  Future<void>? _fetching;
  bool _restored = false;

  RewardsNotifier({required this.rewardsRepository, this.onRedeemed})
    : super(const RewardsState()) {
    fetchOffers();
  }

  Future<void> fetchOffers() => _fetching ??= _fetchOffers().whenComplete(() {
    _fetching = null;
  });

  Future<void> _refreshAfterMutation() async {
    final pending = _fetching;
    if (pending != null) await pending;
    if (mounted) await fetchOffers();
  }

  Future<void> _fetchOffers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    if (!_restored) {
      _restored = true;
      try {
        final catalog = await rewardsRepository.getCachedOffers();
        if (!mounted) return;
        if (catalog != null) state = state.copyWith(offers: catalog);
      } catch (_) {}
    }
    try {
      final (catalog, pending) = await (
        rewardsRepository.getOffers(),
        rewardsRepository.pendingPurchases(),
      ).wait;
      if (!mounted) return;
      state = state.copyWith(
        offers: catalog,
        pendingPurchases: pending,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<RedeemResultModel?> redeem(String offerId) async {
    if (state.isRedeeming) return null;
    state = state.copyWith(isRedeeming: true, errorMessage: null);
    try {
      final offerTitle =
          state.offers
              .where((o) => o.id == offerId)
              .map((o) => o.title)
              .firstOrNull ??
          'Reward Offer';
      final result = await rewardsRepository.redeemOffer(
        offerId,
        expectedPointsCost: state.offers
            .where((o) => o.id == offerId)
            .firstOrNull
            ?.pointsCost,
      );
      if (!mounted) return result;
      state = state.copyWith(isRedeeming: false, lastRedeemedResult: result);
      onRedeemed?.call();
      // Trigger instant notification
      if (!result.isReplay) {
        NotificationService.showVoucherMinted(
          offerTitle: offerTitle,
          shortCode: result.shortCode,
        );
      }
      // Refresh catalog after redeem (inventory count might change)
      _refreshAfterMutation();
      return result;
    } catch (e) {
      if (!mounted) return null;
      final msg = e.toString().replaceAll('Exception: ', '');
      var pending = state.pendingPurchases;
      try {
        pending = await rewardsRepository.pendingPurchases();
      } catch (_) {}
      if (!mounted) return null;
      state = state.copyWith(
        isRedeeming: false,
        errorMessage: msg,
        pendingPurchases: pending,
      );
      return null;
    }
  }

  Future<void> acknowledgePurchase(String offerId, String? requestKey) async {
    if (requestKey == null) return;
    try {
      await rewardsRepository.acknowledgePurchase(offerId, requestKey);
      if (mounted) await _refreshAfterMutation();
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          errorMessage:
              'Your voucher is in your wallet. Purchase recovery is still pending.',
        );
      }
    }
  }
}
