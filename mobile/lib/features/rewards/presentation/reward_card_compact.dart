import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/store_location.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/offer_models.dart';

String discountLabel(String type, double value) => switch (type) {
  'PERCENT' => '${NumberFormat('0.##').format(value)}% off',
  'FIXED' => 'Rs ${NumberFormat('#,##0.##').format(value)} off',
  'FREE_ITEM' => 'On the house',
  _ => 'A little extra',
};

class RewardCard extends StatelessWidget {
  final OfferModel offer;
  final int? balance;
  final bool busy;
  final VoidCallback onRedeem;
  final VoidCallback? onDetails, onClaimed;
  final ValueChanged<Uri>? onOpenLocation;
  const RewardCard({
    super.key,
    required this.offer,
    required this.balance,
    required this.onRedeem,
    this.busy = false,
    this.onOpenLocation,
    this.onDetails,
    this.onClaimed,
  });
  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final available = offer.inventory == null || offer.inventory! > 0;
    final ready = balance != null && balance! >= offer.pointsCost;
    final missing = (offer.pointsCost - (balance ?? 0)).clamp(
      0,
      offer.pointsCost,
    );
    final location = storeLocationUri(
      mapsUrl: offer.partnerGoogleMapsUrl,
      name: offer.partnerName,
      address: offer.partnerLocation,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: ValueKey('cover-${offer.id}'),
                width: 82,
                height: 108,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.peachWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: offer.partnerCoverImageUrl == null
                    ? const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppTheme.accentSolid,
                        size: 30,
                      )
                    : Image.network(
                        offer.partnerCoverImageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 256,
                        semanticLabel: '${offer.partnerName ?? 'Store'} cover',
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.accentSolid,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.partnerName ?? 'Stepsy partner',
                      style: AppTheme.captionStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      discountLabel(offer.discountType, offer.discountValue),
                      style: AppTheme.titleStyle.copyWith(fontSize: 23),
                    ),
                    Text(offer.title, style: AppTheme.headlineStyle),
                    const SizedBox(height: 6),
                    if (offer.alreadyRedeemed)
                      const Text(
                        'Claimed · One per account',
                        style: AppTheme.captionStyle,
                      ),
                  ],
                ),
              ),
              if (onDetails != null)
                SizedBox(
                  width: 32,
                  child: IconButton(
                    tooltip: 'Details & terms',
                    padding: EdgeInsets.zero,
                    onPressed: onDetails,
                    icon: const Icon(Icons.more_vert, size: 21),
                  ),
                ),
            ],
          ),
          if (offer.partnerLocation?.isNotEmpty == true ||
              location != null ||
              offer.minBasket != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (offer.partnerLocation?.isNotEmpty == true)
                        offer.partnerLocation!,
                      if (offer.minBasket != null && offer.minBasket! > 0)
                        'Min. spend Rs ${number.format(offer.minBasket)}',
                    ].join(' · '),
                    style: AppTheme.captionStyle,
                  ),
                ),
                if (location != null)
                  IconButton(
                    key: ValueKey('maps-${offer.id}'),
                    tooltip: 'Open store in Google Maps',
                    onPressed: () => onOpenLocation != null
                        ? onOpenLocation!(location)
                        : openStoreLocation(context, location),
                    icon: const Icon(Icons.location_on_outlined, size: 19),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${number.format(offer.pointsCost)} pts',
                    style: AppTheme.headlineStyle.copyWith(
                      color: AppTheme.accentDeep,
                    ),
                  ),
                  if (!ready && !offer.alreadyRedeemed)
                    Text(
                      !available
                          ? 'Out of stock'
                          : balance == null
                          ? 'Checking balance'
                          : '${number.format(missing)} pts to go',
                      style: AppTheme.captionStyle,
                    ),
                ],
              ),
              ElevatedButton(
                key: ValueKey('redeem-${offer.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ready || offer.alreadyRedeemed
                      ? AppTheme.accentSolid
                      : AppTheme.sageWash,
                  foregroundColor: ready || offer.alreadyRedeemed
                      ? AppTheme.onDeep
                      : AppTheme.accentDeep,
                  minimumSize: const Size(124, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                onPressed: busy
                    ? null
                    : offer.alreadyRedeemed
                    ? onClaimed
                    : onDetails ?? (ready && available ? onRedeem : null),
                child: Text(
                  offer.alreadyRedeemed
                      ? 'View voucher'
                      : busy
                      ? 'Getting reward…'
                      : ready
                      ? 'View reward'
                      : 'View details',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
