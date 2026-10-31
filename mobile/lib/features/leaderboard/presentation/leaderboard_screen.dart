import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';
import '../../../core/widgets/section_info.dart';
import '../../../core/widgets/stepsy_ui.dart';
import '../../../data/models/leaderboard_models.dart';
import '../providers/leaderboard_provider.dart';

const _scopes = {
  'today': 'Today',
  'week': '7 days',
  'month': '30 days',
  'all_time': 'All time',
};
const _periods = {
  'today': 'Today',
  'week': 'Last 7 days',
  'month': 'Last 30 days',
  'all_time': 'All time',
};
const _gold = Color(0xFFE8D3A0);
final _number = NumberFormat.decimalPattern();

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);
    // A newly selected period must not display the previous period's rankings.
    final data = state.data?.scope == state.selectedScope ? state.data : null;
    final entries = data?.rankings ?? const <LeaderboardEntryModel>[];
    final winners = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    Future<void> refresh() => ref.read(leaderboardProvider.notifier).refresh();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          const SectionInfo(
            title: 'How rankings work',
            message:
                'Rankings use synced eligible steps for the selected period, with day boundaries in Pakistan time (Asia/Karachi). '
                '7 days and 30 days are rolling windows including today. Points shown are confirmed earnings, not a prize for your place. '
                'Tied step totals can share a rank. Your own place is calculated even when you are outside the displayed top walkers. '
                'Refresh after syncing to update your place. Walk at a comfortable pace; the leaderboard does not change earning limits.',
          ),
          IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: state.isLoading ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AchievementHeader(),
                    const SizedBox(height: 18),
                    _ScopePicker(
                      selected: state.selectedScope,
                      onSelected: (scope) {
                        if (scope != state.selectedScope) {
                          HapticsService.selection();
                          ref
                              .read(leaderboardProvider.notifier)
                              .fetchLeaderboard(scope);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _periods[state.selectedScope]!,
                            style: AppTheme.headlineStyle,
                          ),
                        ),
                        if (data != null)
                          Text(
                            '${_number.format(data.totalParticipants)} walkers',
                            style: AppTheme.captionStyle,
                          ),
                      ],
                    ),
                    if (state.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      StatusNotice(
                        data == null
                            ? 'The leaderboard couldn’t be loaded.'
                            : 'Couldn’t refresh. Showing the last loaded ranking.',
                        onRetry: refresh,
                      ),
                    ],
                    if (data != null) ...[
                      const SizedBox(height: 18),
                      _YourPlace(
                        ranking: data.userRanking,
                        participants: data.totalParticipants,
                        entries: entries,
                      ),
                      if (winners.isNotEmpty) ...[
                        const SectionHeading('The walking podium'),
                        _Podium(entries: winners),
                      ] else if (!state.isLoading) ...[
                        const SizedBox(height: 18),
                        const EmptyState(
                          title: 'The trail is open.',
                          message:
                              'No synced activity in this period yet. Your next walk could start the story.',
                          icon: Icons.emoji_events_outlined,
                        ),
                      ],
                      if (rest.isNotEmpty)
                        const SectionHeading('Walking together'),
                    ],
                  ],
                ),
              ),
            ),
            if (rest.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: rest.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _WalkerRow(entry: rest[index]),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              sliver: SliverToBoxAdapter(
                child: Text(
                  entries.isEmpty && data == null && state.isLoading
                      ? 'Finding your place…'
                      : 'Every walk belongs here. Your pace, your progress.',
                  textAlign: TextAlign.center,
                  style: AppTheme.captionStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _ScopePicker({required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.35) {
        return FilterPills(
          options: _scopes,
          selected: selected,
          onSelected: onSelected,
        );
      }
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.sageWash,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            for (final entry in _scopes.entries)
              Expanded(
                child: Semantics(
                  selected: selected == entry.key,
                  child: TextButton(
                    onPressed: () => onSelected(entry.key),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(48, 48),
                      foregroundColor: selected == entry.key
                          ? AppTheme.onDeep
                          : AppTheme.inkSecondary,
                      backgroundColor: selected == entry.key
                          ? AppTheme.accentSolid
                          : Colors.transparent,
                    ),
                    child: Text(entry.value, textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _AchievementHeader extends StatelessWidget {
  const _AchievementHeader();
  @override
  Widget build(BuildContext context) => SurfaceCard(
    color: AppTheme.sageWash,
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: AppTheme.accentDeep,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Small steps. Big heart.',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.accentDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Every walk\nadds up.',
                style: AppTheme.largeTitleStyle,
              ),
            ],
          ),
        ),
        const CompanionPortrait(pose: 'wave', size: 96, interactive: true),
      ],
    ),
  );
}

class _YourPlace extends StatelessWidget {
  final UserRankingModel? ranking;
  final int participants;
  final List<LeaderboardEntryModel> entries;
  const _YourPlace({
    required this.ranking,
    required this.participants,
    required this.entries,
  });
  @override
  Widget build(BuildContext context) {
    final you = ranking;
    if (you == null || you.rank <= 0) {
      return const SurfaceCard(
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppTheme.accentSolid),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your place is waiting. Sync your next walk to join in.',
                style: AppTheme.bodyStyle,
              ),
            ),
          ],
        ),
      );
    }
    final ahead = entries
        .where((e) => e.rank == you.rank - 1 && e.totalSteps > you.totalSteps)
        .firstOrNull;
    final label = you.rank == 1
        ? 'Leading the way'
        : you.rank <= 3
        ? 'On the podium'
        : you.rank <= 10
        ? 'Among the top ten'
        : 'Your place on the trail';
    return Semantics(
      container: true,
      label: 'Your rank ${you.rank}',
      child: SurfaceCard(
        color: AppTheme.peachWash.withValues(alpha: .60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTheme.captionStyle),
                    Text(
                      '#${_number.format(you.rank)}',
                      style: AppTheme.heroNumeralStyle.copyWith(
                        fontSize: 44,
                        color: AppTheme.accentDeep,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_number.format(you.totalSteps)} steps',
                      style: AppTheme.headlineStyle.copyWith(
                        fontFeatures: AppTheme.tabular,
                      ),
                    ),
                    Text(
                      '${_number.format(you.pointsEarned)} points earned',
                      style: AppTheme.captionStyle,
                    ),
                    if (you.percentile > 0 &&
                        you.percentile <= 100 &&
                        participants > 1)
                      Text(
                        'Top ${NumberFormat('0.#').format(you.percentile)}%',
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.accentDeep,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (ahead != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (you.totalSteps / (ahead.totalSteps + 1)).clamp(0, 1),
                  minHeight: 5,
                  backgroundColor: AppTheme.surface,
                  color: AppTheme.accentSolid,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_number.format(ahead.totalSteps - you.totalSteps + 1)} more synced steps to pass #${ahead.rank}',
                style: AppTheme.captionStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntryModel> entries;
  const _Podium({required this.entries});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
          constraints.maxWidth < 300) {
        return Column(
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WalkerRow(entry: entry, medal: true),
              ),
          ],
        );
      }
      if (entries.length == 1) {
        return Center(
          child: SizedBox(
            width: 180,
            child: _PodiumPlace(entry: entries.first),
          ),
        );
      }
      final ordered = [
        entries[1],
        entries[0],
        if (entries.length > 2) entries[2],
      ];
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in ordered)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _PodiumPlace(entry: entry),
              ),
            ),
        ],
      );
    },
  );
}

class _PodiumPlace extends StatelessWidget {
  final LeaderboardEntryModel entry;
  const _PodiumPlace({required this.entry});
  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    return Tooltip(
      message:
          '${entry.displayName}: ${_number.format(entry.totalSteps)} steps',
      child: Column(
        children: [
          if (first)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 25,
                color: AppTheme.accentAmber,
              ),
            ),
          _Medal(rank: entry.rank, size: first ? 72 : 60),
          const SizedBox(height: 10),
          Text(
            entry.isCurrentUser
                ? '${entry.displayName} · You'
                : entry.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              6,
              first
                  ? 23
                  : entry.rank == 2
                  ? 17
                  : 12,
              6,
              14,
            ),
            decoration: BoxDecoration(
              color: first
                  ? _gold
                  : entry.rank == 2
                  ? AppTheme.sageWash
                  : AppTheme.peachWash,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
                bottom: Radius.circular(7),
              ),
              border: Border.all(
                color: first
                    ? AppTheme.accentAmber.withValues(alpha: .25)
                    : AppTheme.hairline,
              ),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _number.format(entry.totalSteps),
                    style: AppTheme.headlineStyle.copyWith(
                      fontFeatures: AppTheme.tabular,
                      fontSize: 20,
                    ),
                  ),
                ),
                const Text('steps', style: AppTheme.captionStyle),
                const SizedBox(height: 8),
                Text(
                  '${_number.format(entry.pointsEarned)} pts',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.accentDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkerRow extends StatelessWidget {
  final LeaderboardEntryModel entry;
  final bool medal;
  const _WalkerRow({required this.entry, this.medal = false});
  @override
  Widget build(BuildContext context) => SurfaceCard(
    color: entry.isCurrentUser ? AppTheme.sageWash : AppTheme.surface,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        if (medal)
          _Medal(rank: entry.rank, size: 44)
        else
          SizedBox(
            width: 40,
            child: Text(
              '#${entry.rank}',
              style: AppTheme.headlineStyle.copyWith(
                color: AppTheme.accentSolid,
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: entry.displayName,
                child: Text(
                  entry.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.headlineStyle,
                ),
              ),
              if (entry.isCurrentUser)
                Text(
                  'You',
                  style: AppTheme.captionStyle.copyWith(
                    color: AppTheme.accentDeep,
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    '${_number.format(entry.totalSteps)} steps',
                    style: AppTheme.bodyStyle.copyWith(
                      fontFeatures: AppTheme.tabular,
                    ),
                  ),
                  Text(
                    '${_number.format(entry.pointsEarned)} pts',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Medal extends StatelessWidget {
  final int rank;
  final double size;
  const _Medal({required this.rank, required this.size});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rank $rank',
    child: CustomPaint(
      painter: _LaurelPainter(),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: size * .67,
            height: size * .67,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank == 1 ? _gold : AppTheme.surfaceMuted,
              border: Border.all(
                color: rank == 1
                    ? AppTheme.accentAmber.withValues(alpha: .45)
                    : AppTheme.hairline,
              ),
            ),
            child: Text(
              '$rank',
              style: AppTheme.titleStyle.copyWith(
                fontSize: size * .33,
                color: AppTheme.accentDeep,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LaurelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.accentSolid.withValues(alpha: .65);
    for (final side in [-1, 1]) {
      for (var i = 0; i < 5; i++) {
        final t = (.28 + i * .14) * math.pi;
        final center = Offset(
          size.width / 2 + side * math.sin(t) * size.width * .44,
          size.height * .91 - (i + 1) * size.height * .135,
        );
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(side * (.25 + i * .16));
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width * .10,
            height: size.height * .18,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_LaurelPainter oldDelegate) => false;
}
