import 'package:flutter/cupertino.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pointsProvider.notifier).refresh();
      ref.read(rewardsProvider.notifier).fetchOffers();
    });
  }

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
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm redemption',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

              // Points Math Breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Column(
                  children: [
                    _buildMathRow('Current balance', '${NumberFormat('#,###').format(userBalance)} pts', AppTheme.inkPrimary),
                    const SizedBox(height: 10),
                    _buildMathRow('Points cost', '-${NumberFormat('#,###').format(cost)} pts', AppTheme.accentSolid),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppTheme.hairline, height: 1),
                    ),
                    _buildMathRow('Remaining balance', '${NumberFormat('#,###').format(remainingAfter)} pts', AppTheme.inkPrimary, isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
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
                              backgroundColor: AppTheme.destructive,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text('Confirm & redeem'),
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
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Voucher ready',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Voucher added to your wallet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),

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
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        result.shortCode as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                      const Icon(CupertinoIcons.doc_on_doc, size: 18, color: AppTheme.inkSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Spent ${result.pointsSpent} pts  •  Remaining: ${result.balance} pts',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.inkSecondary,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/wallet');
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Text('Open in wallet'),
                ),
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
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Rewards',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.inkPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: rewardsState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Available Balance Strip (Clean Card)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available balance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(userBalance)} pts',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentSolid,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Catalog Header
            const Text(
              'Offers',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: AppTheme.inkPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Offers List
            if (offers.isNotEmpty)
              ...offers.map((offer) {
                final canAfford = userBalance >= offer.pointsCost;
                final inStock = offer.inventory == null || offer.inventory! > 0;
                final isAvailable = canAfford && inStock;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBright.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    _discountLabel(offer.discountType, offer.discountValue),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentSolid,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: inStock ? AppTheme.surfaceMuted : AppTheme.destructive.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    inStock ? 'In stock' : 'Out of stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: inStock ? AppTheme.inkSecondary : AppTheme.destructive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (offer.description != null && offer.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                offer.description!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.inkSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppTheme.hairline),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${NumberFormat('#,###').format(offer.pointsCost)} pts',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: isAvailable
                                    ? () => _showRedeemBottomSheet(context, ref, offer, userBalance)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAvailable ? AppTheme.accentSolid : AppTheme.surfaceMuted,
                                  foregroundColor: isAvailable ? AppTheme.surface : AppTheme.inkTertiary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(
                                  !inStock
                                      ? 'Sold out'
                                      : !canAfford
                                          ? 'Need ${offer.pointsCost - userBalance} pts'
                                          : 'Redeem',
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
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: const Text(
                  'No offers available at the moment',
                  style: TextStyle(
                    color: AppTheme.inkSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 20),
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
            fontSize: 13,
            color: isBold ? AppTheme.inkPrimary : AppTheme.inkSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
            letterSpacing: -0.2,
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
