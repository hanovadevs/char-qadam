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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.partnerName ?? 'Stepsy partner',
                      style: AppTheme.captionStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      discountLabel(offer.discountType, offer.discountValue),
                      style: AppTheme.titleStyle.copyWith(
                        fontSize: 26,
                        color: AppTheme.accentDeep,
                      ),
                    ),
                  ],
                ),
              ),
              if (offer.partnerCoverImageUrl != null)
                SizedBox(
                  width: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        offer.partnerCoverImageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 256,
                        semanticLabel: '${offer.partnerName ?? 'Store'} cover',
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppTheme.mintWash,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: AppTheme.accentDeep,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(offer.title, style: AppTheme.headlineStyle),
          if (offer.minBasket != null && offer.minBasket! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Minimum spend Rs ${number.format(offer.minBasket)}',
                style: AppTheme.captionStyle,
              ),
            ),
          if (offer.partnerLocation?.isNotEmpty == true || location != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.partnerLocation ?? 'View branch location',
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
                    icon: const Icon(Icons.map_outlined, size: 22),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${number.format(offer.pointsCost)} pts',
                    style: AppTheme.headlineStyle,
                  ),
                  Text(
                    offer.alreadyRedeemed
                        ? 'One per account'
                        : !available
                        ? 'Out of stock'
                        : balance == null
                        ? 'Checking balance'
                        : ready
                        ? 'Within your points'
                        : '${number.format(missing)} more to unlock',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
              ElevatedButton(
                key: ValueKey('redeem-${offer.id}'),
                onPressed: offer.alreadyRedeemed
                    ? onClaimed
                    : ready && available && !busy
                    ? onRedeem
                    : null,
                child: Text(
                  offer.alreadyRedeemed
                      ? 'View voucher'
                      : busy
                      ? 'Getting reward…'
                      : 'Get reward',
                ),
              ),
            ],
          ),
          if (onDetails != null)
            TextButton(
              onPressed: onDetails,
              child: const Text('Details & terms'),
            ),
        ],
      ),
    );
  }
}
