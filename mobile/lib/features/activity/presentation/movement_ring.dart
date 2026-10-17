import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';

class MovementRing extends StatelessWidget {
  final int steps;
  final int goal;
  const MovementRing({super.key, required this.steps, required this.goal});
  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label:
          '${NumberFormat('#,###').format(steps)} steps. Milestone ${NumberFormat('#,###').format(goal)} steps.',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: ratio),
                  duration: motionDuration(context),
                  curve: AppTheme.easeOut,
                  builder: (context, value, child) =>
                      CustomPaint(painter: _RingPainter(value)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 28,
                      color: AppTheme.accentBright,
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        NumberFormat('#,###').format(steps),
                        style: AppTheme.heroNumeralStyle.copyWith(
                          color: AppTheme.surface,
                          fontSize: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'steps today',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.onDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  const _RingPainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.onDeep.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, paint);
    paint.color = AppTheme.accentBright;
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
    }
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 14);
      canvas.drawCircle(
        point,
        2,
        Paint()..color = AppTheme.onDeep.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value;
}
