import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(activityProvider.notifier).initAndSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);

    if (activityState.isSyncing) {
      if (!_syncAnimController.isAnimating) {
        _syncAnimController.repeat();
      }
    } else {
      if (_syncAnimController.isAnimating) {
        _syncAnimController.stop();
        _syncAnimController.reset();
      }
    }

    final displaySteps = activityState.todaySteps > 0
        ? activityState.todaySteps
        : activityState.serverSteps;
    final cap = activityState.dailyCap > 0 ? activityState.dailyCap : 20000;
    final progress = (displaySteps / cap).clamp(0.0, 1.0);
    final remainingSteps = (cap - displaySteps).clamp(0, cap);

    // Metric estimates
    final km = (displaySteps * 0.00076).toStringAsFixed(2);
    final kcal = (displaySteps * 0.04).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: AppTheme.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Steps',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppTheme.inkPrimary,
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.inkSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          RotationTransition(
            turns: _syncAnimController,
            child: IconButton(
              icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: AppTheme.inkPrimary),
              onPressed: activityState.isSyncing
                  ? null
                  : () => ref.read(activityProvider.notifier).initAndSync(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accentSolid,
        backgroundColor: AppTheme.surface,
        onRefresh: () => ref.read(activityProvider.notifier).initAndSync(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Quick Points Earned Link (Clean pill strip)
            InkWell(
              onTap: () => context.go('/points'),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentSolid,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Earned today: +${activityState.pointsEarnedToday} pts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const Icon(CupertinoIcons.chevron_forward, size: 14, color: AppTheme.inkSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Hero Movement Card with Gradient Progress
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
                    'Daily movement',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Large Step Count Display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        NumberFormat('#,###').format(displaySteps),
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
                        'steps',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.inkSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gradient Progress Bar (accentBright to accentDeep)
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 10,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accentBright, AppTheme.accentDeep],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.inkTertiary,
                        ),
                      ),
                      Text(
                        'Goal: ${NumberFormat('#,###').format(cap)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppTheme.hairline, height: 1),
                  const SizedBox(height: 16),

                  // 3-Column Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile('Distance', '$km km'),
                      ),
                      Container(width: 1, height: 28, color: AppTheme.hairline),
                      Expanded(
                        child: _buildMetricTile('Calories', '$kcal kcal'),
                      ),
                      Container(width: 1, height: 28, color: AppTheme.hairline),
                      Expanded(
                        child: _buildMetricTile(
                          'Remaining',
                          NumberFormat('#,###').format(remainingSteps),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Streak & Leaderboard Row (Inset 2-item list)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Streak: ${activityState.currentStreakDays} ${activityState.currentStreakDays == 1 ? 'day' : 'days'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          activityState.currentStreakDays > 0 ? 'Active streak' : '1,000+ steps/day goal',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.hairline),
                  InkWell(
                    onTap: () {
                      HapticsService.light();
                      context.push('/leaderboard');
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusLg)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Leaderboard',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Icon(CupertinoIcons.chevron_forward, size: 14, color: AppTheme.inkSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Step Conversion Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.info_circle, size: 18, color: AppTheme.accentSolid),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '100 steps = 1 pt. Steps convert automatically when your activity syncs.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.inkSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Activity Log Header & Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity log',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppTheme.inkPrimary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.hairline),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRangeTab('today', 'Today', activityState.selectedRange, ref),
                      _buildRangeTab('week', '7D', activityState.selectedRange, ref),
                      _buildRangeTab('month', '30D', activityState.selectedRange, ref),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // History List
            if (activityState.history != null && activityState.history!.days.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activityState.history!.days.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.hairline),
                  itemBuilder: (context, index) {
                    final day = activityState.history!.days[index];
                    final dateFormatted = _formatDate(day.date);
                    final stepsFmt = NumberFormat('#,###').format(day.eligibleSteps);
                    final pts = day.eligibleSteps ~/ 100;
                    final dayProgress = (day.eligibleSteps / cap).clamp(0.0, 1.0);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormatted,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: AppTheme.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  child: LinearProgressIndicator(
                                    value: dayProgress,
                                    minHeight: 4,
                                    backgroundColor: AppTheme.surfaceMuted,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentSolid),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$stepsFmt steps',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBright.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Text(
                              '+$pts pts',
                              style: const TextStyle(
                                color: AppTheme.accentSolid,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
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
                  'No step records for this period',
                  style: TextStyle(
                    color: AppTheme.inkSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Privacy Guarantee
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(CupertinoIcons.lock_shield, color: AppTheme.inkTertiary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Steps are counted locally on device sensors. Location data is never collected or tracked.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkTertiary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.inkSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.inkPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeTab(String value, String label, String currentRange, WidgetRef ref) {
    final isSelected = currentRange == value;
    return GestureDetector(
      onTap: () {
        HapticsService.selection();
        ref.read(activityProvider.notifier).loadHistory(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentSolid : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.surface : AppTheme.inkSecondary,
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final parsed = DateTime.parse(isoDate);
      return DateFormat('EEE, MMM d').format(parsed);
    } catch (_) {
      return isoDate;
    }
  }
}
