import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/swiss_skeleton.dart';
import '../providers/points_provider.dart';

class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(pointsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointsState = ref.watch(pointsProvider);

    final balance = pointsState.balanceData?.balance ?? 0;
    final totalEarned = pointsState.balanceData?.totalEarned ?? 0;
    final totalSpent = pointsState.balanceData?.totalSpent ?? 0;
    final entries = pointsState.entries;

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Points',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppTheme.inkPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: pointsState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
            onPressed: () {
              HapticsService.light();
              ref.read(pointsProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Balance Hero Card (Apple Squircle Card)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available balance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,###').format(balance),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkPrimary,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'pts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentSolid,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 16),

                  // Split Lifetime Metrics
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lifetime earned',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${NumberFormat('#,###').format(totalEarned)} pts',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentSolid,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: AppTheme.hairline),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lifetime redeemed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${NumberFormat('#,###').format(totalSpent)} pts',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSecondary,
                                letterSpacing: -0.2,
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
            const SizedBox(height: 20),

            // Ledger Section Header
            const Text(
              'Transaction history',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: AppTheme.inkPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Inset Grouped Ledger List
            if (entries.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.hairline),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isEarn = entry.delta > 0;
                    final dateStr = DateFormat('MMM d, yyyy  •  HH:mm')
                        .format(entry.createdAt.toLocal());
                    final deltaStr = isEarn
                        ? '+${NumberFormat('#,###').format(entry.delta)} pts'
                        : '${NumberFormat('#,###').format(entry.delta)} pts';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isEarn
                                  ? AppTheme.accentBright.withValues(alpha: 0.15)
                                  : AppTheme.surfaceMuted,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEarn ? CupertinoIcons.plus : CupertinoIcons.minus,
                              color: isEarn ? AppTheme.accentSolid : AppTheme.inkSecondary,
                              size: 16,
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
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: AppTheme.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            deltaStr,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: isEarn ? AppTheme.accentSolid : AppTheme.inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else if (pointsState.isLoading)
              const SwissSkeletonList(itemCount: 4, itemHeight: 54)
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
                  'No transactions recorded yet',
                  style: TextStyle(
                    color: AppTheme.inkSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

            // Load More Indicator
            if (pointsState.isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _reasonTitle(String reason) {
    switch (reason) {
      case 'STEP_EARN':
        return 'Steps converted';
      case 'OFFER_SPEND':
        return 'Reward redemption';
      case 'ADJUST':
        return 'Balance adjustment';
      default:
        return reason;
    }
  }
}
