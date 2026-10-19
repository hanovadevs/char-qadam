import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../companion/companion.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../providers/points_provider.dart';

class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});
  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
      ref.read(pointsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pointsProvider);
    final balance = state.balanceData;
    final number = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Points'),
        actions: [
          IconButton(
            tooltip: 'Refresh points',
            onPressed: state.isLoading
                ? null
                : () => ref.read(pointsProvider.notifier).refresh(),
            icon: const Icon(CupertinoIcons.arrow_2_circlepath),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SurfaceCard(
              color: AppTheme.mintWash,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available points',
                          style: AppTheme.headlineStyle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Companion(size: 48),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    balance == null ? '—' : number.format(balance.balance),
                    style: AppTheme.heroNumeralStyle.copyWith(
                      color: AppTheme.accentDeep,
                      fontSize: 56,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'points available to spend',
                    style: AppTheme.captionStyle,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/rewards'),
                      icon: const Icon(CupertinoIcons.arrow_up_right, size: 18),
                      label: const Text('Find your next reward'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _total(
                    'Walking points earned',
                    balance == null ? '—' : number.format(balance.totalEarned),
                  ),
                  _total(
                    'Spent on rewards',
                    balance == null ? '—' : number.format(balance.totalSpent),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Walking points earned excludes manual adjustments. Your available balance includes all credits and debits.',
                style: AppTheme.captionStyle,
              ),
            ),
            const SectionHeading('Your transactions'),
            if (state.errorMessage != null)
              StatusNotice(
                state.errorMessage!,
                onRetry: () => ref.read(pointsProvider.notifier).refresh(),
              ),
            if (state.isLoading && state.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.entries.isEmpty && state.errorMessage == null)
              const EmptyState(
                title: 'Your first points are a walk away.',
                message:
                    'Once your steps sync, you’ll see your earned points here.',
                icon: CupertinoIcons.circle_grid_hex,
              )
            else
              SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (final entry in state.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: entry.delta >= 0
                                    ? AppTheme.mintWash
                                    : AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                entry.delta >= 0
                                    ? CupertinoIcons.arrow_down_left
                                    : CupertinoIcons.arrow_up_right,
                                size: 18,
                                color: AppTheme.accentDeep,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reason(entry.reason),
                                    style: AppTheme.bodyStyle.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'd MMM yyyy · h:mm a',
                                    ).format(entry.createdAt.toLocal()),
                                    style: AppTheme.captionStyle,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${entry.delta > 0 ? '+' : ''}${number.format(entry.delta)}',
                              style: AppTheme.headlineStyle.copyWith(
                                color: entry.delta > 0
                                    ? AppTheme.accentDeep
                                    : AppTheme.inkPrimary,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (state.isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.hasMore && state.entries.isNotEmpty)
              TextButton(
                onPressed: () => ref.read(pointsProvider.notifier).loadMore(),
                child: const Text('Load more activity'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _total(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: AppTheme.titleStyle.copyWith(fontFeatures: AppTheme.tabular),
      ),
      const SizedBox(height: 4),
      Text(label, style: AppTheme.captionStyle),
    ],
  );
  String _reason(String reason) => switch (reason) {
    'STEP_EARN' => 'Steps converted',
    'OFFER_SPEND' => 'Reward unlocked',
    'ADJUST' => 'Balance adjustment',
    'REFUND' => 'Points returned',
    _ => 'Points activity',
  };
}
