import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/offer_models.dart';
import '../../../data/models/voucher_models.dart';
import '../../rewards/presentation/reward_card.dart';

class VoucherTicket extends StatelessWidget {
  final VoucherModel voucher;
  final OfferModel? offer;
  final bool selected;
  final VoidCallback onShow, onShare;
  const VoucherTicket({
    super.key,
    required this.voucher,
    this.offer,
    this.selected = false,
    required this.onShow,
    required this.onShare,
  });
  @override
  Widget build(BuildContext context) {
    final ready =
        voucher.status == 'ISSUED' && voucher.expiresAt.isAfter(DateTime.now());
    final used = voucher.status == 'REDEEMED';
    final cancelled = voucher.status == 'CANCELLED';
    final status = ready
        ? 'Ready to use'
        : used
        ? 'Used'
        : cancelled
        ? 'Cancelled'
        : 'Expired';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipPath(
        clipper: const _TicketShape(),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.accentSolid : AppTheme.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 9, color: AppTheme.peachWash),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 76,
                              height: 94,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: AppTheme.sageWash,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: offer?.partnerCoverImageUrl == null
                                  ? const Icon(
                                      Icons.card_giftcard_outlined,
                                      color: AppTheme.accentSolid,
                                      size: 28,
                                    )
                                  : Image.network(
                                      offer!.partnerCoverImageUrl!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 224,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.storefront_outlined,
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
                                    offer?.partnerName ?? 'Stepsy reward',
                                    style: AppTheme.captionStyle,
                                  ),
                                  Text(
                                    discountLabel(
                                      voucher.offerDiscountType,
                                      voucher.offerDiscountValue,
                                    ),
                                    style: AppTheme.titleStyle.copyWith(
                                      fontSize: 23,
                                    ),
                                  ),
                                  Text(
                                    voucher.offerTitle,
                                    style: AppTheme.headlineStyle,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.sageWash,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: AppTheme.captionStyle.copyWith(
                                        color: AppTheme.accentDeep,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (ready)
                              SizedBox(
                                width: 26,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Voucher options',
                                  padding: EdgeInsets.zero,
                                  onSelected: (_) => onShare(),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Text('Share voucher'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cancelled
                              ? 'Cancelled. Contact support if you need help with this reward.'
                              : used
                              ? voucher.redeemedAt == null
                                    ? 'Used in store'
                                    : 'Used ${DateFormat('d MMM yyyy').format(voucher.redeemedAt!.toLocal())}'
                              : '${ready ? 'Valid until' : 'Expired'} ${DateFormat('d MMM yyyy').format(voucher.expiresAt.toLocal())}',
                          style: AppTheme.captionStyle,
                        ),
                        if (ready) ...[
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: onShow,
                            child: const Text('Show voucher'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketShape extends CustomClipper<Path> {
  const _TicketShape();
  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
    ),
    Path()
      ..addOval(
        Rect.fromCircle(center: Offset(0, size.height * .56), radius: 9),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height * .56),
          radius: 9,
        ),
      ),
  );
  @override
  bool shouldReclip(_TicketShape oldClipper) => false;
}
