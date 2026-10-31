import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../routing/app_router.dart';
import '../companion/companion.dart';
import 'tour_content.dart';
import 'tour_provider.dart';
import 'tour_targets.dart';

/// A read-only coach layer over the actual customer pages.
class GuidedTour extends ConsumerStatefulWidget {
  final Widget child;
  final int currentTab;
  final ValueChanged<int> selectTab;
  const GuidedTour({
    super.key,
    required this.child,
    required this.currentTab,
    required this.selectTab,
  });
  @override
  ConsumerState<GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends ConsumerState<GuidedTour>
    with WidgetsBindingObserver {
  final _surface = GlobalKey();
  Rect? _target;
  bool _locating = false;
  int _request = 0;
  int? _shown;
  Timer? _autoStart;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      guidedTourProvider,
      (_, next) => _schedule(next),
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(covariant GuidedTour old) {
    super.didUpdateWidget(old);
    if (old.currentTab != widget.currentTab) {
      final progress = ref.read(guidedTourProvider);
      if (progress.active &&
          !_locating &&
          widget.currentTab != tourStops[progress.index].tab) {
        // A notification or other external navigation takes priority over the tour.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_locating &&
              ref.read(guidedTourProvider).active &&
              widget.currentTab !=
                  tourStops[ref.read(guidedTourProvider).index].tab) {
            unawaited(
              ref.read(guidedTourProvider.notifier).finish(skipped: true),
            );
          }
        });
      } else {
        _schedule(progress);
      }
    }
  }

  @override
  void didChangeMetrics() {
    _shown = null;
    _schedule(ref.read(guidedTourProvider));
  }

  void _schedule(TourProgress state) {
    _autoStart?.cancel();
    if (!state.loaded) return;
    if (!state.active) {
      _request++;
      _shown = null;
      if (mounted && _target != null) setState(() => _target = null);
      if (state.status == 'new') {
        // Let auth, onboarding and notification launch routing settle first.
        _autoStart = Timer(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          final path = GoRouter.of(
            context,
          ).routeInformationProvider.value.uri.path;
          if (path == '/steps' &&
              ref.read(onboardingCompleteProvider).valueOrNull == true &&
              ref.read(guidedTourProvider).status == 'new') {
            unawaited(ref.read(guidedTourProvider.notifier).start());
          }
        });
      }
      return;
    }
    if (_shown == state.index) return;
    _shown = state.index;
    final request = ++_request;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _locate(state.index, request),
    );
  }

  bool _valid(int request) =>
      mounted && request == _request && ref.read(guidedTourProvider).active;
  Future<void> _locate(int index, int request) async {
    try {
      await _positionTarget(index, request);
    } catch (_) {
      // A missing/disposed target must leave the explanation and navigation usable.
      if (_valid(request)) setState(() => _target = null);
    } finally {
      if (_valid(request)) setState(() => _locating = false);
    }
  }

  Future<void> _positionTarget(int index, int request) async {
    if (!_valid(request)) return;
    setState(() {
      _locating = true;
      _target = null;
    });
    final stop = tourStops[index];
    final path = GoRouter.of(context).routeInformationProvider.value.uri.path;
    if (![
      '/steps',
      '/points',
      '/rewards',
      '/wallet',
      '/profile',
    ].contains(path)) {
      _shown = null;
      setState(() => _locating = false);
      return;
    }
    widget.selectTab(stop.tab);
    await WidgetsBinding.instance.endOfFrame;
    if (!_valid(request)) return;
    final targets = ref.read(tourTargetsProvider);
    if (stop.target != null && stop.target != 'navigation') {
      // Lazy lists may not have built the target yet. Search this page only.
      final scroll = targets.scrollable(stop.tab);
      if (scroll != null && scroll.position.hasContentDimensions) {
        scroll.position.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
      }
      for (var attempt = 0; attempt < 18 && _valid(request); attempt++) {
        final target = targets.context(stop.target!);
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            alignment: .03,
            // Page tickers are intentionally muted under the guide. A driven
            // scroll would wait forever for that paused ticker to advance.
            duration: Duration.zero,
          );
          break;
        }
        final page = targets.scrollable(stop.tab);
        if (page == null || !page.position.hasContentDimensions) break;
        final next = math.min(
          page.position.maxScrollExtent,
          page.position.pixels + page.position.viewportDimension * .65,
        );
        if (next == page.position.pixels) break;
        page.position.jumpTo(next);
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!_valid(request)) return;
    final box = stop.target == null
        ? null
        : targets.context(stop.target!)?.findRenderObject();
    final surface = _surface.currentContext?.findRenderObject();
    Rect? rect;
    if (box is RenderBox &&
        box.attached &&
        box.hasSize &&
        surface is RenderBox) {
      rect = surface.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    }
    setState(() {
      _target = rect;
      _locating = false;
    });
  }

  @override
  void dispose() {
    _request++;
    _autoStart?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(guidedTourProvider);
    return PopScope(
      canPop: !progress.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && progress.active) {
          unawaited(
            ref.read(guidedTourProvider.notifier).finish(skipped: true),
          );
        }
      },
      child: Stack(
        key: _surface,
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: progress.active,
            child: ExcludeFocus(
              excluding: progress.active,
              child: TickerMode(enabled: !progress.active, child: widget.child),
            ),
          ),
          if (progress.active)
            Positioned.fill(
              child: TourOverlay(
                progress: progress,
                target: _target,
                locating: _locating,
                onBack: () => ref
                    .read(guidedTourProvider.notifier)
                    .move(progress.index - 1),
                onNext: () {
                  if (progress.index == tourStops.length - 1) {
                    unawaited(ref.read(guidedTourProvider.notifier).finish());
                    widget.selectTab(0);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || ref.read(guidedTourProvider).active) {
                        return;
                      }
                      final page = ref.read(tourTargetsProvider).scrollable(0);
                      if (page != null && page.position.hasContentDimensions) {
                        page.position.jumpTo(0);
                      }
                    });
                  } else {
                    unawaited(
                      ref
                          .read(guidedTourProvider.notifier)
                          .move(progress.index + 1),
                    );
                  }
                },
                onSkip: () =>
                    ref.read(guidedTourProvider.notifier).finish(skipped: true),
              ),
            ),
        ],
      ),
    );
  }
}

class TourOverlay extends StatelessWidget {
  final TourProgress progress;
  final Rect? target;
  final bool locating;
  final VoidCallback onBack, onNext, onSkip;
  const TourOverlay({
    super.key,
    required this.progress,
    this.target,
    this.locating = false,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });
  @override
  Widget build(BuildContext context) {
    final stop = tourStops[progress.index];
    return BlockSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safe = MediaQuery.paddingOf(context);
            final topPanel = stop.target == 'navigation';
            final height = math.min(
              constraints.maxHeight - safe.vertical - 20,
              math.max(330.0, constraints.maxHeight * .50),
            );
            final panelTop = topPanel
                ? safe.top + 12
                : constraints.maxHeight - safe.bottom - height - 10;
            final visibleArea = topPanel
                ? Rect.fromLTRB(
                    8,
                    panelTop + height + 12,
                    constraints.maxWidth - 8,
                    constraints.maxHeight - safe.bottom,
                  )
                : Rect.fromLTRB(
                    8,
                    safe.top + 8,
                    constraints.maxWidth - 8,
                    math.max(safe.top + 8, panelTop - 10),
                  );
            final highlight = target?.inflate(5).intersect(visibleArea);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        highlight != null && !highlight.isEmpty
                            ? highlight
                            : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: panelTop,
                  left: 14,
                  right: 14,
                  height: height,
                  child: FocusScope(
                    autofocus: true,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'YOUR GUIDED WALK · ${progress.index + 1}/${tourStops.length}',
                                style: AppTheme.captionStyle.copyWith(
                                  color: AppTheme.onDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: onSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.onDeep,
                              ),
                              child: const Text('Skip tour'),
                            ),
                          ],
                        ),
                        Expanded(
                          child: CustomPaint(
                            painter: const _ThoughtCloudPainter(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                23,
                                24,
                                23,
                                24,
                              ),
                              child: Scrollbar(
                                child: SingleChildScrollView(
                                  primary: false,
                                  key: ValueKey(progress.index),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stop.chapter,
                                          style: AppTheme.captionStyle.copyWith(
                                            color: AppTheme.accentDeep,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          stop.title,
                                          style: AppTheme.titleStyle,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          stop.message,
                                          style: AppTheme.bodyStyle.copyWith(
                                            height: 1.45,
                                          ),
                                        ),
                                        if (stop.target != null &&
                                            target == null &&
                                            !locating) ...[
                                          const SizedBox(height: 8),
                                          const Text(
                                            'This section will appear when it is available. You can still continue the tour.',
                                            style: AppTheme.captionStyle,
                                          ),
                                        ],
                                        if (progress.saveFailed) ...[
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Tour progress could not be saved. You can still continue.',
                                            style: AppTheme.captionStyle,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 37,
                                      top: -6,
                                      child: _thoughtDot(14),
                                    ),
                                    Positioned(
                                      left: 27,
                                      top: 13,
                                      child: _thoughtDot(8),
                                    ),
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      child: Companion(
                                        size: 96,
                                        clip: stop.clip,
                                        event: progress.index,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (progress.index > 0)
                                IconButton(
                                  onPressed: locating ? null : onBack,
                                  tooltip: 'Previous tour step',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.surface,
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: locating ? null : onNext,
                                  child: Text(
                                    progress.index == 0
                                        ? 'Show me around'
                                        : progress.index == tourStops.length - 1
                                        ? 'Let’s walk'
                                        : 'Next',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _thoughtDot(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.accentBright),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  _SpotlightPainter(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (rect != null) {
      path.addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(18)));
    }
    canvas.drawPath(
      path,
      Paint()..color = AppTheme.inkPrimary.withValues(alpha: .72),
    );
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppTheme.accentBright,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.rect != rect;
}

/// Soft lobes around a cream thought bubble; the separate dots point to our guide.
class _ThoughtCloudPainter extends CustomPainter {
  const _ThoughtCloudPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(24, 10)
      ..cubicTo(w * .12, -3, w * .22, -2, w * .29, 6)
      ..cubicTo(w * .39, -2, w * .48, -2, w * .55, 5)
      ..cubicTo(w * .7, -2, w * .8, -2, w - 25, 10)
      ..cubicTo(w + 2, 12, w + 2, 36, w - 5, 54)
      ..cubicTo(w + 3, h * .45, w + 2, h * .7, w - 7, h - 30)
      ..quadraticBezierTo(w - 6, h - 3, w - 34, h - 5)
      ..cubicTo(w * .65, h + 3, w * .45, h - 3, w * .28, h - 5)
      ..cubicTo(15, h + 4, -2, h - 8, 5, h - 35)
      ..cubicTo(-3, h * .6, -2, h * .34, 6, 45)
      ..quadraticBezierTo(-2, 14, 24, 10)
      ..close();
    canvas.drawShadow(p, Colors.black.withValues(alpha: .18), 8, true);
    canvas.drawPath(p, Paint()..color = AppTheme.surface);
    canvas.drawPath(
      p,
      Paint()
        ..color = AppTheme.accentBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_ThoughtCloudPainter old) => false;
}
