import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/store_location.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';
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
  final ValueChanged<Uri>? onOpenLocation;
  const RewardCard({
    super.key,
    required this.offer,
    required this.balance,
    required this.onRedeem,
    this.busy = false,
    this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    final ready = balance != null && balance! >= offer.pointsCost;
    final available = offer.inventory == null || offer.inventory! > 0;
    final missing = (offer.pointsCost - (balance ?? 0)).clamp(
      0,
      offer.pointsCost,
    );
    final location = storeLocationUri(
      mapsUrl: offer.partnerGoogleMapsUrl,
      name: offer.partnerName,
      address: offer.partnerLocation,
    );
    final brand = offer.partnerName?.trim().isNotEmpty == true
        ? offer.partnerName!
        : 'Stepsy partner';
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.mintWash,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        brand.characters.first.toUpperCase(),
                        style: AppTheme.headlineStyle.copyWith(
                          color: AppTheme.accentDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        brand,
                        style: AppTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (location != null)
                      IconButton.filledTonal(
                        key: ValueKey('maps-${offer.id}'),
                        tooltip: 'Open $brand in Google Maps',
                        onPressed: () => onOpenLocation != null
                            ? onOpenLocation!(location)
                            : openStoreLocation(context, location),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surface,
                          foregroundColor: AppTheme.accentDeep,
                        ),
                        icon: const Icon(Icons.map_outlined, size: 22),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  discountLabel(offer.discountType, offer.discountValue),
                  style: AppTheme.largeTitleStyle.copyWith(
                    color: AppTheme.accentDeep,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 6),
                Text(offer.title, style: AppTheme.headlineStyle),
                if (offer.partnerLocation?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.location,
                        size: 16,
                        color: AppTheme.accentDeep,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          offer.partnerLocation!,
                          style: AppTheme.captionStyle.copyWith(
                            color: AppTheme.accentDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const TicketDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.description?.trim().isNotEmpty == true) ...[
                  Text(
                    offer.description!,
                    style: AppTheme.captionStyle.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                ],
                if (offer.minBasket != null && offer.minBasket! > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Minimum spend Rs ${number.format(offer.minBasket)}',
                      style: AppTheme.captionStyle,
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${number.format(offer.pointsCost)} pts',
                          style: AppTheme.titleStyle.copyWith(
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          offer.alreadyRedeemed
                              ? 'Already in My rewards · one per account'
                              : !available
                              ? 'Currently unavailable'
                              : balance == null
                              ? 'Checking your balance'
                              : ready
                              ? 'Ready when you are'
                              : '${number.format(missing)} more to unlock',
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                    ElevatedButton(
                      key: ValueKey('redeem-${offer.id}'),
                      onPressed:
                          ready && available && !busy && !offer.alreadyRedeemed
                          ? onRedeem
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentDeep,
                      ),
                      child: Text(
                        offer.alreadyRedeemed
                            ? 'Claimed'
                            : busy
                            ? 'Working…'
                            : !available
                            ? 'Unavailable'
                            : ready
                            ? 'Get reward'
                            : 'Keep walking',
                      ),
                    ),
                  ],
                ),
                if (!offer.alreadyRedeemed &&
                    !ready &&
                    balance != null &&
                    available &&
                    offer.pointsCost > 0) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    label:
                        '${number.format(balance)} of ${number.format(offer.pointsCost)} points saved',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (balance! / offer.pointsCost).clamp(0.0, 1.0),
                        minHeight: 5,
                        color: AppTheme.accentSolid,
                        backgroundColor: AppTheme.mintWash,
                      ),
                    ),
                  ),
                ],
                if (offer.endsAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Available until ${DateFormat('d MMM yyyy').format(offer.endsAt!.toLocal())}',
                      style: AppTheme.captionStyle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
