import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/points/providers/points_provider.dart';
import '../../features/companion/companion.dart';
import '../theme/app_theme.dart';

class StepsyBrand extends StatelessWidget {
  final double size;
  const StepsyBrand({super.key, this.size = 25});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/icon/Stepsy_Icon1.png',
        width: size + 6,
        height: size + 6,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          'Stepsy',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.titleStyle.copyWith(fontSize: size),
        ),
      ),
    ],
  );
}

class CozyAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showPoints;
  final List<Widget> actions;
  const CozyAppBar({
    super.key,
    this.showPoints = true,
    this.actions = const [],
  });
  @override
  Size get preferredSize => const Size.fromHeight(58);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = showPoints
        ? ref.watch(pointsProvider).balanceData?.balance
        : null;
    return AppBar(
      automaticallyImplyLeading: false,
      title: const StepsyBrand(size: 22),
      actions: [
        ...actions,
        if (showPoints)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.sageWash,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(48, 36),
              ),
              onPressed: () => context.go('/points'),
              child: Text(
                '${balance ?? '—'} pts',
                style: AppTheme.headlineStyle.copyWith(
                  color: AppTheme.accentDeep,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CompanionPortrait extends StatefulWidget {
  final String pose;
  final double size;
  final bool interactive;
  const CompanionPortrait({
    super.key,
    this.pose = 'rest',
    this.size = 180,
    this.interactive = false,
  });
  @override
  State<CompanionPortrait> createState() => _CompanionPortraitState();
}

class _CompanionPortraitState extends State<CompanionPortrait> {
  Timer? _rest;
  String? _reaction;
  int _event = 0;
  @override
  void dispose() {
    _rest?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _reaction != null
        ? Companion(clip: _reaction!, event: _event, size: widget.size)
        : ExcludeSemantics(
            child: Image.asset(
              'assets/companion/portraits/${widget.pose}.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
            ),
          );
    if (!widget.interactive) return content;
    return Semantics(
      button: true,
      label: 'Play with your walking companion',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _rest?.cancel();
          setState(() {
            _reaction = const ['wave', 'love', 'wiggle', 'peek'][_event++ % 4];
          });
          _rest = Timer(const Duration(milliseconds: 1600), () {
            if (mounted) setState(() => _reaction = null);
          });
        },
        child: content,
      ),
    );
  }
}

class CozyScene extends StatelessWidget {
  final double height;
  final String pose;
  final bool portrait;
  final bool sky;
  const CozyScene({
    super.key,
    this.height = 240,
    this.pose = 'walk',
    this.portrait = false,
    this.sky = false,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/illustrations/cozy-park.png',
              fit: BoxFit.cover,
              alignment: portrait || sky
                  ? Alignment.topCenter
                  : const Alignment(0, .25),
              cacheWidth: 900,
            ),
            if (portrait)
              Positioned(
                right: -20,
                bottom: -100,
                child: CompanionPortrait(pose: pose, size: 340),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: -12,
                child: CompanionPortrait(pose: pose, size: height * .95),
              ),
          ],
        ),
      ),
    ),
  );
}

class CozyPageHeading extends StatelessWidget {
  final String title, subtitle, pose;
  const CozyPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.pose = 'wave',
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.largeTitleStyle),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTheme.titleStyle.copyWith(fontSize: 22, height: 1.15),
            ),
          ],
        ),
      ),
      SizedBox(
        width: 142,
        height: 150,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 12,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    color: AppTheme.peachWash,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: -30,
                bottom: -75,
                child: CompanionPortrait(
                  pose: pose,
                  size: 235,
                  interactive: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class CozyWave extends CustomClipper<Path> {
  const CozyWave();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 24)
    ..cubicTo(size.width * .25, -16, size.width * .65, 42, size.width, 20)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(CozyWave oldClipper) => false;
}
