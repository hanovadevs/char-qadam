import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/stepsy_ui.dart';

/// An original 2D walking buddy. Its place on the path follows real progress;
/// its walk cycle is decorative and never creates or predicts sensor steps.
class WalkingProgress extends StatefulWidget {
  final int steps;
  final int goal;
  final bool enabled;
  const WalkingProgress({
    super.key,
    required this.steps,
    required this.goal,
    this.enabled = true,
  });
  @override
  State<WalkingProgress> createState() => _WalkingProgressState();
}

class _WalkingProgressState extends State<WalkingProgress>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _walk;
  bool _foreground = true;
  bool _moving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotion();
  }

  @override
  void didUpdateWidget(covariant WalkingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _applyMotion();
  }

  void _applyMotion() {
    _moving =
        widget.enabled &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_moving) {
      if (!_walk.isAnimating) _walk.repeat();
    } else {
      _walk.stop();
      _walk.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat('#,###');
    final progress = widget.goal > 0
        ? (widget.steps / widget.goal).clamp(0.0, 1.0)
        : 0.0;
    return Semantics(
      label:
          '${number.format(widget.steps)} steps today. Milestone ${number.format(widget.goal)} steps.',
      child: ExcludeSemantics(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'A little walk. A little win.',
              style: AppTheme.captionStyle.copyWith(color: AppTheme.onDeep),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  number.format(widget.steps),
                  style: AppTheme.heroNumeralStyle.copyWith(
                    color: AppTheme.surface,
                    fontSize: 64,
                  ),
                ),
              ),
            ),
            Text(
              'steps today',
              style: AppTheme.captionStyle.copyWith(color: AppTheme.onDeep),
            ),
            const SizedBox(height: 8),
            RepaintBoundary(
              child: SizedBox(
                height: 152,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: motionDuration(context),
                  curve: AppTheme.easeOut,
                  builder: (context, value, child) => CustomPaint(
                    key: const ValueKey('walking-journey-canvas'),
                    painter: _JourneyPainter(
                      progress: value,
                      phase: _walk,
                      moving: _moving,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Start',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.onDeep,
                    ),
                  ),
                ),
                Text(
                  '${number.format(widget.goal)} steps',
                  style: AppTheme.captionStyle.copyWith(color: AppTheme.onDeep),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyPainter extends CustomPainter {
  final double progress;
  final Animation<double> phase;
  final bool moving;
  _JourneyPainter({
    required this.progress,
    required this.phase,
    required this.moving,
  }) : super(repaint: phase);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(24, 112)
      ..cubicTo(w * .28, 137, w * .35, 72, w * .57, 99)
      ..cubicTo(w * .76, 123, w * .83, 114, w - 24, 108);
    final metric = path.computeMetrics().first;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.onDeep.withValues(alpha: .15);
    canvas.drawPath(path, stroke);
    stroke
      ..strokeWidth = 2
      ..color = AppTheme.onDeep.withValues(alpha: .45);
    for (double offset = 0; offset < metric.length; offset += 14) {
      canvas.drawPath(
        metric.extractPath(offset, math.min(offset + 2, metric.length)),
        stroke,
      );
    }
    if (progress > 0) {
      stroke
        ..strokeWidth = 8
        ..color = AppTheme.accentBright;
      canvas.drawPath(metric.extractPath(0, metric.length * progress), stroke);
    }
    for (final fraction in [0.0, .5, 1.0]) {
      final point = metric
          .getTangentForOffset(metric.length * fraction)!
          .position;
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = fraction <= progress
              ? AppTheme.accentBright
              : AppTheme.accentDeep,
      );
      canvas.drawCircle(point, 3, Paint()..color = AppTheme.onDeep);
    }
    final finish = metric.getTangentForOffset(metric.length)!.position;
    final flagPaint = Paint()
      ..color = AppTheme.onDeep
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      finish + const Offset(0, -7),
      finish + const Offset(0, -31),
      flagPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(finish.dx, finish.dy - 32)
        ..lineTo(finish.dx + 14, finish.dy - 27)
        ..lineTo(finish.dx, finish.dy - 21)
        ..close(),
      Paint()..color = AppTheme.accentBright,
    );
    final point = metric
        .getTangentForOffset(metric.length * progress)!
        .position;
    canvas.drawOval(
      Rect.fromCenter(center: point + const Offset(0, 4), width: 34, height: 7),
      Paint()..color = AppTheme.inkPrimary.withValues(alpha: .25),
    );
    canvas.save();
    canvas.translate(point.dx, point.dy - 2);
    _walker(canvas, moving ? phase.value * math.pi * 2 : 0, moving);
    canvas.restore();
  }

  void _walker(Canvas canvas, double cycle, bool animated) {
    final swing = animated ? math.sin(cycle) : 0.0;
    final bob = animated ? -1.5 * math.sin(cycle * 2).abs() : 0.0;
    final outline = Paint()
      ..color = AppTheme.inkPrimary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void capsule(Offset from, Offset to, Color color, double width) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = AppTheme.inkPrimary
          ..strokeWidth = width + 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    void leg(double amount, bool far) {
      final hip = Offset(far ? -4 : 4, -25 + bob);
      final thigh = amount * .6;
      final shin = thigh - math.max(0.0, -amount) * .85;
      final knee = hip + Offset(math.sin(thigh), math.cos(thigh)) * 12;
      final foot = knee + Offset(math.sin(shin), math.cos(shin)) * 12;
      capsule(hip, knee, far ? AppTheme.mintWash : AppTheme.onDeep, 8);
      capsule(knee, foot, far ? AppTheme.mintWash : AppTheme.onDeep, 7);
      final shoe = RRect.fromRectAndRadius(
        Rect.fromLTWH(foot.dx - 4, foot.dy - 3, 14, 7),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        shoe,
        Paint()..color = far ? AppTheme.mintWash : AppTheme.surface,
      );
      canvas.drawRRect(shoe, outline);
      canvas.drawLine(
        Offset(foot.dx - 2, foot.dy + 3),
        Offset(foot.dx + 9, foot.dy + 3),
        outline,
      );
    }

    void arm(double amount, bool far) {
      final shoulder = Offset(far ? -7 : 6, -47 + bob);
      final elbow =
          shoulder +
          Offset(math.sin(amount * .55), math.cos(amount * .55)) * 11;
      final hand =
          elbow +
          Offset(math.sin(amount * .4 + .35), math.cos(amount * .4 + .35)) * 10;
      capsule(
        shoulder,
        elbow,
        far ? AppTheme.accentSolid : AppTheme.accentBright,
        7,
      );
      capsule(elbow, hand, AppTheme.walkerSkin, 6);
    }

    leg(-swing, true);
    arm(swing, true);
    final body = Path()
      ..moveTo(-8, -51 + bob)
      ..quadraticBezierTo(0, -55 + bob, 8, -49 + bob)
      ..lineTo(11, -28 + bob)
      ..quadraticBezierTo(0, -22 + bob, -11, -27 + bob)
      ..close();
    canvas.drawPath(body, Paint()..color = AppTheme.accentBright);
    canvas.drawPath(body, outline);
    canvas.drawLine(
      Offset(-5, -49 + bob),
      Offset(7, -29 + bob),
      Paint()
        ..color = AppTheme.accentDeep
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, -37 + bob, 13, 9),
        const Radius.circular(3),
      ),
      Paint()..color = AppTheme.accentDeep,
    );
    leg(swing, false);
    arm(-swing, false);
    capsule(Offset(0, -55 + bob), Offset(0, -49 + bob), AppTheme.walkerSkin, 7);
    final face = Rect.fromCenter(
      center: Offset(1, -65 + bob),
      width: 25,
      height: 27,
    );
    canvas.drawOval(face, Paint()..color = AppTheme.walkerSkin);
    canvas.drawOval(face, outline);
    canvas.drawCircle(
      Offset(-10, -64 + bob),
      4,
      Paint()..color = AppTheme.walkerSkin,
    );
    canvas.drawArc(
      face.deflate(1),
      math.pi * .78,
      math.pi * .75,
      false,
      Paint()
        ..color = AppTheme.inkPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final cap = Path()
      ..moveTo(-12, -70 + bob)
      ..quadraticBezierTo(-11, -83 + bob, 2, -80 + bob)
      ..quadraticBezierTo(11, -79 + bob, 12, -70 + bob)
      ..close();
    canvas.drawPath(cap, Paint()..color = AppTheme.mintWash);
    canvas.drawPath(cap, outline);
    capsule(
      Offset(3, -70 + bob),
      Offset(16, -70 + bob),
      AppTheme.accentBright,
      4,
    );
    canvas.drawCircle(
      Offset(5, -65 + bob),
      1.4,
      Paint()..color = AppTheme.inkPrimary,
    );
    canvas.drawCircle(
      Offset(11, -65 + bob),
      1.4,
      Paint()..color = AppTheme.inkPrimary,
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, -59 + bob)
        ..quadraticBezierTo(10, -56 + bob, 12, -60 + bob),
      outline..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _JourneyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.moving != moving ||
      oldDelegate.phase != phase;
}
