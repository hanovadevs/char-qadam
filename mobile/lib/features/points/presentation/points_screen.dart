import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/swiss_skeleton.dart';
import '../providers/points_provider.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsState = ref.watch(pointsProvider);

    final balance = pointsState.balanceData?.balance ?? 0;
    final totalEarned = pointsState.balanceData?.totalEarned ?? 0;
    final totalSpent = pointsState.balanceData?.totalSpent ?? 0;
    final entries = pointsState.ledgerPage?.entries ?? [];

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POINTS & LEDGER',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppTheme.black,
              ),
            ),
            Text(
              'APPEND-ONLY TRANSACTION BALANCE',
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
            icon: pointsState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  )
                : const Icon(Icons.refresh, size: 20, color: AppTheme.black),
            onPressed: () {
              HapticsService.light();
              ref.read(pointsProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // Balance Hero Block (Swiss Warm Beige Surface #F5F1E8)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.beige,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderDark, width: 1),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT AVAILABLE BALANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,###').format(balance),
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PTS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.taupe,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderDark, height: 1),
                  const SizedBox(height: 14),

                  // Split Lifetime Metrics
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LIFETIME EARNED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${NumberFormat('#,###').format(totalEarned)} PTS',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: AppTheme.monoFont,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: AppTheme.borderDark),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LIFETIME REDEEMED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${NumberFormat('#,###').format(totalSpent)} PTS',
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: AppTheme.monoFont,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ledger Section Title
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TRANSACTION HISTORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppTheme.black,
                  ),
                ),
                Text(
                  'IMMUTABLE LEDGER',
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

            // Ledger List
            if (entries.isNotEmpty)
              ...entries.map((entry) {
                final isEarn = entry.delta > 0;
                final dateStr = DateFormat('MMM d, yyyy  •  HH:mm')
                    .format(entry.createdAt.toLocal());
                final deltaStr = isEarn
                    ? '+${NumberFormat('#,###').format(entry.delta)} PTS'
                    : '${NumberFormat('#,###').format(entry.delta)} PTS';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Icon(
                          isEarn ? Icons.add : Icons.remove,
                          color: isEarn ? AppTheme.black : AppTheme.taupe,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _reasonTitle(entry.reason).toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5,
                                color: AppTheme.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: AppTheme.monoFont,
                                color: AppTheme.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.offWhite,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(
                          deltaStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: AppTheme.monoFont,
                            fontWeight: FontWeight.w700,
                            color: isEarn ? AppTheme.black : AppTheme.taupe,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else if (pointsState.isLoading)
              const SwissSkeletonList(itemCount: 4, itemHeight: 54)
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'NO LEDGER ENTRIES RECORDED YET',
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

  String _reasonTitle(String reason) {
    switch (reason) {
      case 'STEP_EARN':
        return 'Steps Converted';
      case 'OFFER_SPEND':
        return 'Offer Redemption';
      case 'ADJUST':
        return 'Manual Adjustment';
      default:
        return reason;
    }
  }
}
