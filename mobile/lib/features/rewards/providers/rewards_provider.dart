import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/offer_models.dart';
import '../../../data/rewards/rewards_repository.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../points/providers/points_provider.dart';

class RewardsState {
  final List<OfferModel> offers;
  final bool isLoading;
  final bool isRedeeming;
  final String? errorMessage;
  final RedeemResultModel? lastRedeemedResult;

  const RewardsState({
    this.offers = const [],
    this.isLoading = false,
    this.isRedeeming = false,
    this.errorMessage,
    this.lastRedeemedResult,
  });

  RewardsState copyWith({
    List<OfferModel>? offers,
    bool? isLoading,
    bool? isRedeeming,
    String? errorMessage,
    RedeemResultModel? lastRedeemedResult,
  }) {
    return RewardsState(
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      errorMessage: errorMessage,
      lastRedeemedResult: lastRedeemedResult ?? this.lastRedeemedResult,
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
      ref.invalidate(walletProvider);
      ref.invalidate(pointsProvider);
    },
  );
});

class RewardsNotifier extends StateNotifier<RewardsState> {
  final RewardsRepository rewardsRepository;
  final void Function()? onRedeemed;

  RewardsNotifier({required this.rewardsRepository, this.onRedeemed})
    : super(const RewardsState()) {
    fetchOffers();
  }

  Future<void> fetchOffers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final catalog = await rewardsRepository.getOffers();
      if (!mounted) return;
      state = RewardsState(offers: catalog, isLoading: false);
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
      final result = await rewardsRepository.redeemOffer(offerId);
      if (!mounted) return result;
      state = state.copyWith(isRedeeming: false, lastRedeemedResult: result);
      onRedeemed?.call();
      // Trigger instant notification
      NotificationService.showVoucherMinted(
        offerTitle: offerTitle,
        shortCode: result.shortCode,
      );
      // Refresh catalog after redeem (inventory count might change)
      fetchOffers();
      return result;
    } catch (e) {
      if (!mounted) return null;
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isRedeeming: false, errorMessage: msg);
      return null;
    }
  }
}
