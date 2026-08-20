import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/activity_provider.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _syncAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activityState = ref.watch(activityProvider);
    final theme = Theme.of(context);

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
    final percentInt = (progress * 100).toInt();

    // Approximate distance & calories
    final km = (displaySteps * 0.00076).toStringAsFixed(1);
    final kcal = (displaySteps * 0.04).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_walk_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Movement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: const TextStyle(
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: RotationTransition(
              turns: _syncAnimController,
              child: IconButton(
                icon: const Icon(Icons.sync_rounded, color: AppTheme.primaryColor),
                onPressed: activityState.isSyncing
                    ? null
                    : () => ref.read(activityProvider.notifier).initAndSync(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.darkCardElevated,
        onRefresh: () => ref.read(activityProvider.notifier).initAndSync(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Hero Step Counter Card
            Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.darkBorderLight.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TODAY\'S TARGET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$percentInt% Completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Animated Radial Progress Ring
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background track
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 16,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E293D),
                              ),
                            ),
                          ),
                          // Active Glow Ring
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 16,
                              strokeCap: StrokeCap.round,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          // Inner Content
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_walk_rounded,
                                size: 28,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(height: 4),
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 0, end: displaySteps),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (context, val, _) {
                                  return Text(
                                    NumberFormat('#,###').format(val),
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 34,
                                      letterSpacing: -1,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                'of ${NumberFormat('#,###').format(cap)} cap',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Mini Stats Row (KM, KCAL)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMetricBadge(Icons.straighten_rounded, '$km km', 'Distance'),
                      const SizedBox(width: 20),
                      Container(width: 1, height: 24, color: AppTheme.darkBorder),
                      const SizedBox(width: 20),
                      _buildMetricBadge(Icons.local_fire_department_rounded, '$kcal kcal', 'Burned'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppTheme.darkBorder, height: 1),
                  const SizedBox(height: 18),

                  // Points stats bottom section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatTile(
                        icon: Icons.stars_rounded,
                        iconColor: AppTheme.accentGold,
                        label: 'Earned Today',
                        value: '+${activityState.pointsEarnedToday} pts',
                      ),
                      Container(width: 1, height: 36, color: AppTheme.darkBorder),
                      _buildStatTile(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: AppTheme.secondaryColor,
                        label: 'Total Balance',
                        value: '${activityState.userBalance} pts',
                      ),
                    ],
                  ),
                  if (activityState.lastSyncTime != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Synced at ${activityState.lastSyncTime}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSubtle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Earning Rule Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rate: 100 steps = 1 Point • Max 20,000 steps counted daily',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // History Section Header & Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('Today')),
                    ButtonSegment(value: 'week', label: Text('7D')),
                    ButtonSegment(value: 'month', label: Text('30D')),
                  ],
                  selected: {activityState.selectedRange},
                  onSelectionChanged: (Set<String> selection) {
                    ref.read(activityProvider.notifier).loadHistory(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // History List
            if (activityState.history != null && activityState.history!.days.isNotEmpty)
              ...activityState.history!.days.map((day) {
                final dateFormatted = _formatDate(day.date);
                final stepsFmt = NumberFormat('#,###').format(day.eligibleSteps);
                final pts = day.eligibleSteps ~/ 100;
                final dayProgress = (day.eligibleSteps / cap).clamp(0.0, 1.0);

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
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateFormatted,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: dayProgress,
                                minHeight: 4,
                                backgroundColor: const Color(0xFF1E293D),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$stepsFmt steps',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.accentGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '+$pts pts',
                          style: const TextStyle(
                            color: AppTheme.accentGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: const Text(
                  'No step records for this period yet.',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 14),
                ),
              ),

            const SizedBox(height: 20),

            // Privacy Guarantee Capsule
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.darkCardElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.textMuted, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Zero GPS Tracking: Steps are converted directly on your device. Location data is never collected or stored.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSubtle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
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
