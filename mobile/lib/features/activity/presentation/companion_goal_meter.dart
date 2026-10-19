import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_theme.dart';
import '../../companion/companion.dart';
import '../../companion/experience_provider.dart';

class CompanionGoalMeter extends ConsumerStatefulWidget {
  final int steps, goal;
  final bool syncing, denied;
  final bool known;
  final String day;
  const CompanionGoalMeter({
    super.key,
    required this.steps,
    required this.goal,
    required this.day,
    this.syncing = false,
    this.denied = false,
    this.known = true,
  });
  @override
  ConsumerState<CompanionGoalMeter> createState() => _CompanionGoalMeterState();
}

class _CompanionGoalMeterState extends ConsumerState<CompanionGoalMeter> {
  String _clip = 'rest';
  int _event = 0;
  bool _tip = false;
  int _taps = 0;
  Timer? _motionTimer;

  void _play(String clip, Duration duration) {
    if (_clip != clip || clip != 'walk') _event++;
    _clip = clip;
    _motionTimer?.cancel();
    _motionTimer = Timer(duration, () {
      if (mounted) setState(() => _clip = 'rest');
    });
  }

  @override
  void dispose() {
    _motionTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompanionGoalMeter old) {
    super.didUpdateWidget(old);
    if (old.known &&
        widget.known &&
        old.day == widget.day &&
        old.goal == widget.goal &&
        widget.steps > old.steps) {
      final event = '${widget.day}:${widget.goal}';
      if (old.steps < widget.goal &&
          widget.steps >= widget.goal &&
          ref.read(experienceProvider).loaded &&
          ref.read(experienceProvider).celebratedEvent != event) {
        _play('cheer', const Duration(milliseconds: 1600));
        final settings = ref.read(experienceProvider.notifier);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            settings.update(celebratedEvent: event).catchError((_) {});
          }
        });
      } else if (_clip != 'cheer') {
        // Keep the same walk cycle while sensor events arrive; never restart
        // the atlas on every step. Rest shortly after movement stops.
        _play('walk', const Duration(seconds: 3));
      }
    } else if (widget.steps < old.steps ||
        old.day != widget.day ||
        old.goal != widget.goal ||
        !widget.known) {
      _motionTimer?.cancel();
      _clip = 'rest';
      _event++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.goal > 0
        ? (widget.steps / widget.goal).clamp(0.0, 1.0)
        : 0.0;
    final n = NumberFormat.decimalPattern();
    final prefs = ref.watch(experienceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tip && prefs.tips)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.syncing
                      ? 'Steps update live. Points update after sync.'
                      : const [
                          'Ready whenever you are.',
                          'A little love for every little step.',
                          'Your pace. I’m right here with you.',
                          'Small steps deserve a happy dance.',
                        ][math.max(0, _taps - 1) % 4],
                  style: AppTheme.captionStyle,
                ),
              ),
              IconButton(
                tooltip: 'Dismiss tip',
                onPressed: () => setState(() => _tip = false),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        SizedBox(
          height: 78,
          child: LayoutBuilder(
            builder: (context, box) {
              const sprite = 76.0;
              final visualProgress =
                  Directionality.of(context) == TextDirection.rtl
                  ? 1 - progress
                  : progress;
              final left = (visualProgress * box.maxWidth - sprite / 2)
                  .clamp(0.0, math.max(0, box.maxWidth - sprite))
                  .toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Semantics(
                      value: widget.known
                          ? '${(progress * 100).round()} percent of daily goal'
                          : 'Waiting for activity',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          key: const ValueKey('daily-goal-fill'),
                          value: progress,
                          minHeight: 12,
                          backgroundColor: AppTheme.hairline,
                          color: AppTheme.accentSolid,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration:
                        MediaQuery.disableAnimationsOf(context) ||
                            !prefs.animations
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    left: left,
                    bottom: 2,
                    width: sprite,
                    height: sprite,
                    child: Semantics(
                      button: true,
                      label: prefs.tips
                          ? 'Walking companion. Show a tip'
                          : 'Walking companion. Wave',
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _play(
                            const ['wave', 'love', 'peek', 'wiggle'][_taps++ %
                                4],
                            const Duration(milliseconds: 1600),
                          );
                          _tip = prefs.tips;
                        }),
                        child: Companion(
                          clip: _clip != 'rest'
                              ? _clip
                              : !widget.known && widget.syncing
                              ? 'wait'
                              : widget.denied
                              ? 'reassure'
                              : _clip,
                          event: _event,
                          repeat: _clip == 'walk',
                          size: sprite,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text('0', style: AppTheme.captionStyle),
            Text(
              !widget.known
                  ? 'Waiting for activity'
                  : widget.steps >= widget.goal
                  ? 'Daily goal reached'
                  : '${n.format(math.max(0, widget.goal - widget.steps))} steps to your goal',
              style: AppTheme.captionStyle,
            ),
            Text('${n.format(widget.goal)} goal', style: AppTheme.captionStyle),
          ],
        ),
      ],
    );
  }
}
