import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cozy_scene.dart';

class CozyAuthFrame extends StatelessWidget {
  final String title, subtitle, pose;
  final Widget child;
  final bool welcome;
  final bool showBack;
  const CozyAuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.pose = 'peek',
    this.welcome = false,
    this.showBack = true,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: welcome ? Alignment.topCenter : Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    CozyScene(
                      height: welcome ? 310 : 235,
                      pose: pose,
                      portrait: !welcome,
                      sky: true,
                      arrival: welcome,
                    ),
                    Positioned(
                      top: 14,
                      left: welcome || !showBack ? 24 : 4,
                      right: 20,
                      child: Row(
                        children: [
                          if (!welcome && showBack)
                            IconButton(
                              tooltip: 'Back',
                              onPressed: () => context.go('/welcome'),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          const StepsyBrand(),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -1,
                      child: ClipPath(
                        clipper: const CozyWave(),
                        child: Container(
                          height: 38,
                          color: AppTheme.surfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: AppTheme.largeTitleStyle.copyWith(
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: AppTheme.bodyStyle.copyWith(
                          fontSize: 17,
                          color: AppTheme.inkSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthLabel extends StatelessWidget {
  final String label;
  const AuthLabel(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(label, style: AppTheme.bodyStyle),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTheme.captionStyle),
        ),
        Expanded(child: Divider()),
      ],
    ),
  );
}

class GoogleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const GoogleAuthButton({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const SizedBox(
      width: 23,
      height: 23,
      child: CustomPaint(painter: _GoogleMark()),
    ),
    label: const Text('Continue with Google'),
  );
}

class _GoogleMark extends CustomPainter {
  const _GoogleMark();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width * .38);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .18;
    for (final segment in [
      (-40.0, 85.0, const Color(0xFF4285F4)),
      (45.0, 90.0, const Color(0xFF34A853)),
      (135.0, 60.0, const Color(0xFFFBBC05)),
      (195.0, 125.0, const Color(0xFFEA4335)),
    ]) {
      paint.color = segment.$3;
      canvas.drawArc(
        rect,
        segment.$1 * math.pi / 180,
        segment.$2 * math.pi / 180,
        false,
        paint,
      );
    }
    paint.color = const Color(0xFF4285F4);
    canvas.drawLine(center, Offset(size.width * .94, center.dy), paint);
  }

  @override
  bool shouldRepaint(_GoogleMark oldDelegate) => false;
}

void showDeviceAccountInfo(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Accounts on this phone'),
    content: const Text(
      'One customer account and one merchant account can use this phone. '
      'Each account keeps its own data. A second account of the same type is blocked until the original is deleted.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);
