import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/swiss_skeleton.dart';
import '../../points/providers/points_provider.dart';
import '../providers/rewards_provider.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    // Pull the latest balance + catalog when the screen first mounts so the
    // redeem button reflects points earned after app launch (the points
    // provider otherwise only loads once at startup).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pointsProvider.notifier).refresh();
      ref.read(rewardsProvider.notifier).fetchOffers();
    });
  }

  /// Refresh both the offer catalog and the redeemable balance together.
  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(rewardsProvider.notifier).fetchOffers(),
      ref.read(pointsProvider.notifier).refresh(),
    ]);
  }

  void _showRedeemBottomSheet(BuildContext context, WidgetRef ref, dynamic offer, int userBalance) {
    final cost = offer.pointsCost as int;
    final title = offer.title as String;
    final remainingAfter = userBalance - cost;
    HapticsService.light();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
        side: BorderSide(color: AppTheme.borderDark, width: 1),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'CONFIRM REDEMPTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

              // Points Math Breakdown Box (Swiss Grid Light)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.beige,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  children: [
                    _buildMathRow('CURRENT BALANCE', '${NumberFormat('#,###').format(userBalance)} PTS', AppTheme.black),
                    const SizedBox(height: 8),
                    _buildMathRow('POINTS COST', '-${NumberFormat('#,###').format(cost)} PTS', AppTheme.taupe),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppTheme.borderDark, height: 1),
                    ),
                    _buildMathRow('REMAINING BALANCE', '${NumberFormat('#,###').format(remainingAfter)} PTS', AppTheme.black, isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Close the sheet using ITS OWN context, then drive all
                        // post-redeem UI from the screen's State (this.context /
                        // this.mounted). Using the popped sheet context here was
                        // the bug: it's unmounted after pop, so the success modal
                        // and error snackbar were silently skipped.
                        Navigator.pop(sheetContext);
                        final messenger = ScaffoldMessenger.of(this.context);
                        final result = await ref.read(rewardsProvider.notifier).redeem(offer.id);
                        if (!mounted) return;
                        if (result != null) {
                          HapticsService.heavy();
                          ref.read(pointsProvider.notifier).refresh();
                          _showSuccessModal(this.context, result);
                        } else {
                          final error = ref.read(rewardsProvider).errorMessage ?? 'Redemption failed';
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: AppTheme.accentRed,
                            ),
                          );
                        }
                      },
                      child: const Text('CONFIRM & REDEEM'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessModal(BuildContext context, dynamic result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
        side: BorderSide(color: AppTheme.borderDark, width: 1),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppTheme.borderDark,
                    borderRadius: BorderRadius.circular(AppTheme.radiusNone),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'VOUCHER MINTED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Single-use pass added to wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 16),

              // Code Capsule
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: result.shortCode as String));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher code copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.beige,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        result.shortCode as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: AppTheme.black,
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: AppTheme.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SPENT ${result.pointsSpent} PTS  •  REMAINING: ${result.balance} PTS',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: AppTheme.monoFont,
                  color: AppTheme.grey,
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/wallet');
                },
                child: const Text('OPEN IN WALLET'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rewardsState = ref.watch(rewardsProvider);
    final pointsState = ref.watch(pointsProvider);

    final userBalance = pointsState.balanceData?.balance ?? 0;
    final offers = rewardsState.offers;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REWARDS MARKET',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'PARTNER OFFERS & VOUCHERS',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: rewardsState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  )
                : const Icon(Icons.refresh, size: 20, color: AppTheme.black),
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // Available Balance Strip (Swiss Beige Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'REDEEMABLE BALANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(userBalance)} PTS',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: AppTheme.monoFont,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Catalog Header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE CATALOG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.black,
                  ),
                ),
                Text(
                  'SINGLE-USE PASSES',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: AppTheme.monoFont,
                    color: AppTheme.grey,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Offers List
            if (offers.isNotEmpty)
              ...offers.map((offer) {
                final canAfford = userBalance >= offer.pointsCost;
                final inStock = offer.inventory == null || offer.inventory! > 0;
                final isAvailable = canAfford && inStock;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.black,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  ),
                                  child: Text(
                                    _discountLabel(offer.discountType, offer.discountValue),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontFamily: AppTheme.monoFont,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: inStock ? AppTheme.offWhite : AppTheme.white,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    border: Border.all(color: inStock ? AppTheme.border : AppTheme.accentRed),
                                  ),
                                  child: Text(
                                    inStock ? 'IN STOCK' : 'OUT OF STOCK',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontFamily: AppTheme.monoFont,
                                      fontWeight: FontWeight.w700,
                                      color: inStock ? AppTheme.grey : AppTheme.accentRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.black,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (offer.description != null && offer.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                offer.description!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COST',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.grey,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  '${NumberFormat('#,###').format(offer.pointsCost)} PTS',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: AppTheme.monoFont,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.black,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: isAvailable
                                    ? () => _showRedeemBottomSheet(context, ref, offer, userBalance)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                child: Text(
                                  !inStock
                                      ? 'SOLD OUT'
                                      : !canAfford
                                          ? 'NEED ${offer.pointsCost - userBalance} PTS'
                                          : 'REDEEM VOUCHER',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              })
            else if (rewardsState.isLoading)
              const SwissSkeletonList(itemCount: 3, itemHeight: 110)
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'NO ACTIVE OFFERS IN CATALOG',
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 11,
                    fontFamily: AppTheme.monoFont,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMathRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isBold ? AppTheme.black : AppTheme.grey,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: AppTheme.monoFont,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _discountLabel(String type, double value) {
    switch (type) {
      case 'PERCENT':
        return '${value.toInt()}% OFF';
      case 'FIXED':
        return 'PKR ${value.toStringAsFixed(0)} OFF';
      case 'FREE_ITEM':
        return 'FREE ITEM';
      default:
        return 'OFFER';
    }
  }
}
