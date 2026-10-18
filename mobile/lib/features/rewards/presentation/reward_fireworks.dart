import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A short, silent celebration above the destination page, never a modal wait.
void showRewardFireworks(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RewardFireworks(
            onFinished: () {
              entry.remove();
              entry.dispose();
            },
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class RewardFireworks extends StatefulWidget {
  final VoidCallback onFinished;
  const RewardFireworks({super.key, required this.onFinished});

  @override
  State<RewardFireworks> createState() => _RewardFireworksState();
}

class _RewardFireworksState extends State<RewardFireworks>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _FireworksPainter(_controller)),
  );
}

class _FireworksPainter extends CustomPainter {
  final Animation<double> progress;
  _FireworksPainter(this.progress) : super(repaint: progress);

  static const _colors = [
    AppTheme.accentBright,
    AppTheme.accentSolid,
    AppTheme.accentBright,
    AppTheme.onDeep,
    AppTheme.accentAmber,
  ];
  static const _origins = [
    Offset(.23, .30),
    Offset(.77, .25),
    Offset(.50, .17),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final radius = (size.width * .34).clamp(95.0, 165.0);
    for (var burst = 0; burst < _origins.length; burst++) {
      final phase = (progress.value - burst * .16) / .60;
      if (phase <= 0 || phase >= 1) continue;
      final origin = Offset(
        size.width * _origins[burst].dx,
        size.height * _origins[burst].dy,
      );
      final fade =
          math.pow(1 - phase, 1.25).toDouble() * (phase / .08).clamp(0.0, 1.0);
      final travel = 1 - math.exp(-3.8 * phase);
      final previous = 1 - math.exp(-3.8 * math.max(0, phase - .035));
      for (var spark = 0; spark < 36; spark++) {
        final angle = spark * math.pi * 2 / 36 + burst * .47;
        final reach =
            radius * (.70 + .30 * math.sin(spark * 2.4 + burst).abs());
        final direction = Offset(math.cos(angle), math.sin(angle));
        final head =
            origin +
            direction * (reach * travel) +
            Offset(0, phase * phase * 46);
        final tail =
            origin +
            direction * (reach * previous) +
            Offset(0, math.pow(math.max(0, phase - .035), 2) * 46);
        paint
          ..color = _colors[(spark + burst) % _colors.length].withValues(
            alpha: fade,
          )
          ..strokeWidth = spark.isEven ? 2.2 : 1.4
          ..style = PaintingStyle.stroke;
        canvas.drawLine(tail, head, paint);
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(head, spark % 4 == 0 ? 2.2 : 1.3, paint);
        if (spark % 9 == 0) {
          final glint = 4.0 * fade;
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          canvas.drawLine(
            head - Offset(glint, 0),
            head + Offset(glint, 0),
            paint,
          );
          canvas.drawLine(
            head - Offset(0, glint),
            head + Offset(0, glint),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
