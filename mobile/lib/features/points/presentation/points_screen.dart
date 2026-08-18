import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/points_provider.dart';

class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsState = ref.watch(pointsProvider);
    final theme = Theme.of(context);

    final balance = pointsState.balanceData?.balance ?? 0;
    final totalEarned = pointsState.balanceData?.totalEarned ?? 0;
    final totalSpent = pointsState.balanceData?.totalSpent ?? 0;
    final entries = pointsState.ledgerPage?.entries ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stars_rounded,
                color: AppTheme.accentGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Points & Ledger',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Earn with every step',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: pointsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.accentGold),
            onPressed: () => ref.read(pointsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentGold,
        backgroundColor: AppTheme.darkCardElevated,
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Balance Hero Card
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2235),
                    Color(0xFF131826),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.accentGold.withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accentGold),
                            SizedBox(width: 4),
                            Text(
                              'AVAILABLE BALANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppTheme.accentGold,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: balance),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return Text(
                            NumberFormat('#,###').format(val),
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 44,
                              letterSpacing: -1,
                              color: AppTheme.accentGold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PTS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppTheme.darkBorder),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        label: 'Lifetime Earned',
                        value: '+${NumberFormat('#,###').format(totalEarned)}',
                        color: AppTheme.primaryColor,
                        icon: Icons.trending_up_rounded,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.darkBorder,
                      ),
                      _buildStatColumn(
                        label: 'Lifetime Spent',
                        value: '-${NumberFormat('#,###').format(totalSpent)}',
                        color: AppTheme.secondaryColor,
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Ledger Section Title
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Verified Ledger',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ledger List
            if (entries.isNotEmpty)
              ...entries.map((entry) {
                final isEarn = entry.delta > 0;
                final dateStr = DateFormat('MMM d, yyyy • hh:mm a')
                    .format(entry.createdAt.toLocal());
                final deltaStr = isEarn
                    ? '+${NumberFormat('#,###').format(entry.delta)} pts'
                    : '${NumberFormat('#,###').format(entry.delta)} pts';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isEarn
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : AppTheme.secondaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isEarn
                              ? Icons.arrow_downward_rounded
                              : Icons.shopping_bag_rounded,
                          color: isEarn
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _reasonTitle(entry.reason),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isEarn ? AppTheme.primaryColor : AppTheme.accentRose)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          deltaStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isEarn
                                ? AppTheme.primaryColor
                                : AppTheme.accentRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else if (pointsState.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textSubtle),
                    SizedBox(height: 10),
                    Text(
                      'No transactions yet. Start walking to earn points!',
                      style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  String _reasonTitle(String reason) {
    switch (reason) {
      case 'STEP_EARN':
        return 'Daily Steps Converted';
      case 'OFFER_SPEND':
        return 'Voucher Offer Redemption';
      case 'ADJUST':
        return 'Account Adjustment';
      default:
        return reason;
    }
  }
}
