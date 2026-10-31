import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import '../../activity/providers/activity_provider.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../providers/points_provider.dart';
import '../../guided_tour/tour_targets.dart';

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
    final today = ref.watch(activityProvider).pointsEarnedToday;
    final number = NumberFormat.decimalPattern();
    return Scaffold(
      appBar: const CozyAppBar(),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pointsProvider.notifier).refresh(),
        child: ListView(
          key: tourKey(ref, 'page.1'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            6,
            20,
            tourBottomPadding(ref, context),
          ),
          children: [
            const Text('Points', style: AppTheme.largeTitleStyle),
            const SizedBox(height: 10),
            SurfaceCard(
              key: tourKey(ref, 'points.balance'),
              color: AppTheme.sageWash,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available points',
                              style: AppTheme.bodyStyle,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              balance == null
                                  ? '—'
                                  : number.format(balance.balance),
                              style: AppTheme.heroNumeralStyle.copyWith(
                                color: AppTheme.accentDeep,
                                fontSize: 52,
                              ),
                            ),
                            const Text(
                              'points to enjoy',
                              style: AppTheme.bodyStyle,
                            ),
                          ],
                        ),
                      ),
                      const CompanionPortrait(
                        pose: 'sit',
                        size: 150,
                        interactive: true,
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.go('/rewards'),
                    child: const Text('Explore rewards'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              color: AppTheme.peachWash.withValues(alpha: .5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _stat(
                      CupertinoIcons.leaf_arrow_circlepath,
                      '+$today',
                      'Today',
                    ),
                  ),
                  const SizedBox(height: 40, child: VerticalDivider()),
                  Expanded(
                    child: _stat(
                      CupertinoIcons.cart,
                      balance == null ? '—' : number.format(balance.totalSpent),
                      'Spent',
                    ),
                  ),
                ],
              ),
            ),
            SectionHeading('Your activity', key: tourKey(ref, 'points.ledger')),
            if (state.errorMessage != null)
              StatusNotice(
                state.errorMessage!,
                onRetry: () => ref.read(pointsProvider.notifier).refresh(),
              ),
            if (state.isLoading && state.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.entries.isEmpty && state.errorMessage == null)
              const EmptyState(
                title: 'Your first points are a walk away.',
                message:
                    'Once your steps sync, you’ll see your earned points here.',
                icon: CupertinoIcons.leaf_arrow_circlepath,
              )
            else
              ...state.entries.map(
                (entry) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.hairline),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppTheme.peachWash,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          entry.reason == 'STEP_EARN'
                              ? CupertinoIcons.leaf_arrow_circlepath
                              : entry.delta < 0
                              ? CupertinoIcons.cart
                              : CupertinoIcons.gift,
                          size: 22,
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
                              style: AppTheme.bodyStyle,
                            ),
                            Text(
                              DateFormat(
                                'd MMM yyyy · h:mm a',
                              ).format(entry.createdAt.toLocal()),
                              style: AppTheme.captionStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.delta > 0 ? '+' : ''}${number.format(entry.delta)}',
                        style: AppTheme.headlineStyle.copyWith(
                          color: entry.delta < 0
                              ? AppTheme.destructive
                              : AppTheme.accentDeep,
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(height: 18),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(CupertinoIcons.question_circle),
                title: const Text('How points work'),
                trailing: const Icon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How points work',
                            style: AppTheme.largeTitleStyle,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${ref.read(activityProvider).stepsPerPoint} eligible steps = 1 point. Points are confirmed after syncing. Your daily earning cap is ${number.format(ref.read(activityProvider).dailyCap)} steps.',
                            style: AppTheme.bodyStyle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Walking points earned: ${balance == null ? '—' : number.format(balance.totalEarned)}. This excludes manual adjustments. Your available balance includes all credits and debits.',
                            style: AppTheme.bodyStyle,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 24, color: AppTheme.accentSolid),
      const SizedBox(width: 12),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTheme.titleStyle.copyWith(color: AppTheme.accentDeep),
            ),
            Text(label, style: AppTheme.captionStyle),
          ],
        ),
      ),
    ],
  );
  String _reason(String reason) => switch (reason) {
    'STEP_EARN' => 'Walking points',
    'OFFER_SPEND' => 'Rewards redeemed',
    'ADJUST' => 'Balance adjustment',
    'REFUND' => 'Points returned',
    _ => 'Points activity',
  };
}
