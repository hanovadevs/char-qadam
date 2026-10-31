import 'dart:math';
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
import '../providers/tracking_controller.dart';
import '../../points/providers/points_provider.dart';
import '../../rewards/providers/rewards_provider.dart';
import '../../rewards/reward_goal.dart';
import '../../companion/experience_provider.dart';
import '../../companion/experience_sheet.dart';
import '../../../core/widgets/cozy_scene.dart';
import 'companion_goal_meter.dart';
import 'weekly_preview.dart';
import 'tracking_controls.dart';
import '../../guided_tour/tour_targets.dart';

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
    if (state == AppLifecycleState.resumed) {
      ref.read(trackingControllerProvider.notifier).refresh();
      _sync();
    }
  }

  Future<void> _sync() async {
    await ref.read(activityProvider.notifier).initAndSync(force: true);
    if (mounted) ref.invalidate(weeklyActivityProvider);
  }

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
    // Observe recovery even when the controls are below the lazy list viewport.
    final tracking = ref.watch(trackingControllerProvider);
    final weekly = ref.watch(weeklyActivityProvider);
    final prefs = ref.watch(experienceProvider);
    final balance = ref.watch(pointsProvider).balanceData?.balance;
    final inventory = ref.watch(rewardsProvider);
    final eligible = inventory.offers.where((o) => eligibleReward(o)).toList();
    final chosen = eligible.where((o) => o.id == prefs.rewardId).firstOrNull;
    final reward = chosen ?? suggestedReward(eligible, balance);
    // Movement is live from the persisted sensor; only points await the API.
    final steps = max(state.todaySteps, state.serverSteps);
    final known =
        state.hasStepSnapshot ||
        state.settledSteps != null ||
        state.lastSyncTime != null;
    final cap = state.dailyCap;
    final number = NumberFormat.decimalPattern();
    final progress = (steps / prefs.goal).clamp(0.0, 1.0);
    final ringSize = MediaQuery.textScalerOf(context).scale(1) > 1.3
        ? 112.0
        : 82.0;
    return Scaffold(
      appBar: CozyAppBar(
        actions: [
          IconButton(
            tooltip: 'Tracking diagnostics',
            onPressed: _diagnostics,
            icon: const Icon(CupertinoIcons.info_circle, size: 19),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: ListView(
          key: tourKey(ref, 'page.0'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            tourBottomPadding(ref, context),
          ),
          children: [
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: AppTheme.captionStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'A little walk.\nA real reward.',
              style: AppTheme.titleStyle.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              key: tourKey(ref, 'steps.total'),
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      known ? number.format(steps) : '—',
                      key: const ValueKey('settled-step-count'),
                      style: AppTheme.heroNumeralStyle.copyWith(
                        fontSize: 60,
                        height: 1.05,
                      ),
                    ),
                    const Text('steps today', style: AppTheme.headlineStyle),
                  ],
                ),
                Semantics(
                  key: tourKey(ref, 'steps.goal'),
                  label: known
                      ? '${(progress * 100).round()} percent of goal. Edit daily goal'
                      : 'Set daily goal',
                  button: true,
                  child: InkWell(
                    onTap: () => showExperienceSettings(context),
                    borderRadius: BorderRadius.circular(48),
                    child: SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: ringSize - 8,
                            height: ringSize - 8,
                            child: CircularProgressIndicator(
                              value: known ? progress : 0,
                              strokeWidth: 7,
                              backgroundColor: AppTheme.sageWash,
                              color: AppTheme.accentBright,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                known ? '${(progress * 100).round()}%' : '—',
                                style: AppTheme.headlineStyle.copyWith(
                                  color: AppTheme.accentDeep,
                                ),
                              ),
                              const Text(
                                'of goal',
                                style: AppTheme.captionStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            CompanionGoalMeter(
              key: tourKey(ref, 'steps.trail'),
              steps: steps,
              goal: prefs.goal,
              day: DateFormat('yyyy-MM-dd').format(DateTime.now()),
              syncing: state.isSyncing,
              denied: !state.hasPermission,
              known: known,
            ),
            const SizedBox(height: 8),
            Semantics(
              key: tourKey(ref, 'steps.sync'),
              liveRegion: true,
              child: TextButton(
                onPressed: state.isSyncing ? null : _sync,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  '${known ? '+${number.format(state.pointsEarnedToday)} pts today' : 'Waiting for activity'} · ${state.isSyncing
                      ? 'Syncing…'
                      : state.errorMessage != null
                      ? 'Sync needs attention'
                      : state.lastSyncTime == null
                      ? 'Not synced yet'
                      : 'Synced ${state.lastSyncTime}'}',
                ),
              ),
            ),
            if (min(state.todaySteps, cap) > state.serverSteps)
              Text(
                '${number.format(min(state.todaySteps, cap) - state.serverSteps)} device steps awaiting sync',
                style: AppTheme.captionStyle,
              ),
            if (state.errorMessage != null)
              StatusNotice(state.errorMessage!, onRetry: _sync),
            if (tracking?.paused == true)
              const Text(
                'Tracking paused. Resume below your reward goal.',
                style: AppTheme.captionStyle,
              ),
            if (!state.hasPermission && !state.isSyncing)
              StatusNotice(
                'Connect activity to count your walks.',
                onRetry: _sync,
              ),
            const SizedBox(height: 12),
            Text(
              state.currentStreakDays > 0
                  ? '${state.currentStreakDays}-day streak · 1,000 steps/day'
                  : 'Every day is a fresh start. Streaks start at 1,000 steps/day.',
              style: AppTheme.captionStyle,
            ),
            if (reward != null)
              Container(
                key: tourKey(ref, 'steps.reward'),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppTheme.peachWash.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 62,
                          height: 74,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: reward.partnerCoverImageUrl == null
                              ? const Icon(
                                  CupertinoIcons.gift,
                                  color: AppTheme.accentSolid,
                                )
                              : Image.network(
                                  reward.partnerCoverImageUrl!,
                                  fit: BoxFit.cover,
                                  cacheWidth: 192,
                                  errorBuilder: (_, _, _) => const Icon(
                                    CupertinoIcons.gift,
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
                                chosen != null
                                    ? 'Your reward goal'
                                    : 'Your next little win',
                                style: AppTheme.captionStyle,
                              ),
                              Text(
                                reward.title,
                                style: AppTheme.headlineStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                reward.partnerName ?? 'Stepsy partner',
                                style: AppTheme.captionStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${number.format(reward.pointsCost)} pts · ${balance == null
                                    ? 'Checking balance'
                                    : balance >= reward.pointsCost
                                    ? 'Within your points'
                                    : '${number.format(reward.pointsCost - balance)} pts to go'}',
                                style: AppTheme.captionStyle.copyWith(
                                  color: AppTheme.accentDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (chosen != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(
                          value: balance == null
                              ? 0
                              : reward.pointsCost == 0
                              ? 1
                              : (balance / reward.pointsCost).clamp(0.0, 1.0),
                          minHeight: 4,
                        ),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => context.go(
                        '/rewards?offer=${reward.id}&view=${DateTime.now().microsecondsSinceEpoch}',
                      ),
                      child: const Text('View reward'),
                    ),
                    if (prefs.rewardId != null && chosen == null)
                      const Text(
                        'Your previous goal is unavailable. Choose another reward.',
                        style: AppTheme.captionStyle,
                      ),
                  ],
                ),
              )
            else if (!inventory.isLoading)
              ListTile(
                key: tourKey(ref, 'steps.reward'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Your next reward'),
                subtitle: const Text(
                  'Explore partner offers when they’re available.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/rewards'),
              ),
            SectionHeading(
              'Your week',
              key: tourKey(ref, 'steps.week'),
              action: 'View trends',
              onAction: () => context.push('/progress'),
            ),
            WeeklyPreview(
              days: weekly.valueOrNull ?? state.history?.days ?? const [],
            ),
            if (weekly.hasError)
              const Text(
                'Weekly history is unavailable. Pull down to try again.',
                style: AppTheme.captionStyle,
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  context,
                  'Est. distance',
                  known ? '${(steps * .0007).toStringAsFixed(2)} km' : '—',
                  CupertinoIcons.location,
                ),
                _metric(
                  context,
                  'Est. energy',
                  known ? '${(steps * .04).round()} kcal' : '—',
                  CupertinoIcons.flame,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '${number.format(state.stepsPerPoint)} eligible steps = 1 point · Earning cap ${number.format(cap)} steps/day${state.serverSteps >= cap ? ' · Cap reached; movement still counts toward your personal goal.' : ''}',
                style: AppTheme.captionStyle,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Community leaderboard'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/leaderboard'),
            ),
            TrackingControls(key: tourKey(ref, 'steps.tracking')),
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
