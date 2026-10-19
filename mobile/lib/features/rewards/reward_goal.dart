import '../../data/models/offer_models.dart';

bool eligibleReward(OfferModel offer, {DateTime? now}) {
  final time = now ?? DateTime.now();
  return offer.status == 'ACTIVE' &&
      !offer.alreadyRedeemed &&
      (offer.inventory == null || offer.inventory! > 0) &&
      (offer.startsAt == null || !offer.startsAt!.isAfter(time)) &&
      (offer.endsAt == null || offer.endsAt!.isAfter(time));
}

OfferModel? suggestedReward(List<OfferModel> offers, int? balance) {
  final available = offers.where((o) => eligibleReward(o)).toList()
    ..sort((a, b) => a.pointsCost.compareTo(b.pointsCost));
  if (available.isEmpty) return null;
  return available.where((o) => o.pointsCost >= (balance ?? 0)).firstOrNull ??
      available.last;
}
