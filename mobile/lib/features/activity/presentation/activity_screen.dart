import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/activity/health_service.dart';
import '../providers/activity_provider.dart';
import 'movement_ring.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() =>
      ref.read(activityProvider.notifier).initAndSync(force: true);
  Future<void> _diagnostics() async {
    final data = await ref.read(healthServiceProvider).diagnostics();
    if (!mounted) return;
    data['Server eligible steps'] = '${ref.read(activityProvider).serverSteps}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tracking diagnostics', style: AppTheme.titleStyle),
              const SizedBox(height: 16),
              for (final entry in data.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SelectableText('${entry.key}: ${entry.value}'),
                ),
              const SizedBox(height: 16),
              const Text(
                'Compare a manually counted walk with the phone sensor and synced steps.',
                style: AppTheme.captionStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityProvider);
    final steps = math.max(state.todaySteps, state.serverSteps);
    final cap = state.dailyCap > 0 ? state.dailyCap : 20000;
    final milestones = <int>{
      1000,
      5000,
      10000,
      cap,
    }.where((v) => v <= cap).toList()..sort();
    final milestone = milestones.where((v) => v > steps).firstOrNull ?? cap;
    final perPoint = math.max(1, state.stepsPerPoint);
    final nextPoint = perPoint - (steps % perPoint);
    final number = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Tracking diagnostics',
            onPressed: _diagnostics,
            icon: const Icon(CupertinoIcons.info_circle, size: 21),
          ),
          IconButton(
            tooltip: 'Sync steps',
            onPressed: state.isSyncing ? null : _sync,
            icon: state.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.arrow_2_circlepath, size: 21),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Small steps.\nLovely possibilities.',
              style: AppTheme.largeTitleStyle,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentDeep,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your daily movement',
                          style: AppTheme.bodyStyle.copyWith(
                            color: AppTheme.surface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.isSyncing
                            ? 'Syncing'
                            : state.hasPermission
                            ? 'Motion allowed'
                            : 'Motion off',
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.onDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: MovementRing(steps: steps, goal: milestone),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps >= cap
                        ? 'Daily earning limit reached. Keep moving for you.'
                        : '${number.format(milestone - steps)} to your ${number.format(milestone)}-step milestone',
                    textAlign: TextAlign.center,
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.onDeep,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: AppTheme.onDeep.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/points'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.surface,
                    ),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          '+${number.format(state.pointsEarnedToday)} pts earned today',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                        const Icon(CupertinoIcons.arrow_up_right, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (state.errorMessage != null)
              StatusNotice(state.errorMessage!, onRetry: _sync),
            if (!state.hasPermission && !state.isSyncing)
              StatusNotice(
                'Allow motion access to count your walks.',
                onRetry: _sync,
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  context,
                  'Est. distance',
                  '${(steps * 0.0007).toStringAsFixed(2)} km',
                  CupertinoIcons.location,
                ),
                _metric(
                  context,
                  'Est. energy',
                  '${(steps * 0.04).round()} kcal',
                  CupertinoIcons.flame,
                ),
              ],
            ),
            const SectionHeading('Make a little more of today'),
            SurfaceCard(
              color: AppTheme.mintWash,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.currentStreakDays > 0
                        ? '${state.currentStreakDays}-day walking streak'
                        : 'Start a feel-good streak.',
                    style: AppTheme.titleStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Walk 1,000 steps a day to build your streak. Every day is a fresh chance.',
                    style: AppTheme.captionStyle.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    steps >= cap
                        ? 'Today’s reward-eligible steps are complete.'
                        : '$nextPoint steps to the next point boundary.',
                    style: AppTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${number.format(perPoint)} steps = 1 pt · Daily earning cap ${number.format(cap)} steps',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where will your steps take you?',
                    style: AppTheme.titleStyle,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find a little something worth walking for.',
                    style: AppTheme.captionStyle,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/rewards'),
                      icon: const Icon(CupertinoIcons.ticket, size: 18),
                      label: const Text('Explore rewards'),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeading('Your walking story'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: const Text(
                      'Progress & trends',
                      style: AppTheme.headlineStyle,
                    ),
                    subtitle: const Text(
                      'See your weeks and months',
                      style: AppTheme.captionStyle,
                    ),
                    trailing: const Icon(
                      CupertinoIcons.arrow_up_right,
                      size: 18,
                    ),
                    onTap: () => context.push('/progress'),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: const Text(
                      'Community leaderboard',
                      style: AppTheme.headlineStyle,
                    ),
                    subtitle: const Text(
                      'A little friendly motivation',
                      style: AppTheme.captionStyle,
                    ),
                    trailing: const Icon(
                      CupertinoIcons.arrow_up_right,
                      size: 18,
                    ),
                    onTap: () => context.push('/leaderboard'),
                  ),
                ],
              ),
            ),
            const SectionHeading('Synced activity'),
            FilterPills(
              options: const {
                'today': 'Today',
                'week': '7 days',
                'month': '30 days',
              },
              selected: state.selectedRange,
              onSelected: (value) {
                HapticsService.selection();
                ref.read(activityProvider.notifier).loadHistory(value);
              },
            ),
            const SizedBox(height: 12),
            if (state.history?.days.isNotEmpty == true)
              SurfaceCard(
                child: Column(
                  children: [
                    for (final day in state.history!.days)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'EEE, d MMM',
                                ).format(DateTime.parse(day.date)),
                                style: AppTheme.captionStyle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${number.format(day.eligibleSteps)} steps',
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: AppTheme.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            else if (state.isSyncing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              const EmptyState(
                title: 'Your story starts with a step.',
                message:
                    'Synced activity will appear here after your next walk.',
                icon: CupertinoIcons.chart_bar,
              ),
            const SizedBox(height: 20),
            Text(
              state.lastSyncTime == null
                  ? 'Pull down to sync your steps.'
                  : 'Last synced ${state.lastSyncTime}',
              textAlign: TextAlign.center,
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Distance and energy are estimates. Stepsy counts movement without tracking your GPS location.',
              textAlign: TextAlign.center,
              style: AppTheme.captionStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentSolid, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.headlineStyle.copyWith(
              fontFeatures: AppTheme.tabular,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.captionStyle),
        ],
      ),
    ),
  );
}
