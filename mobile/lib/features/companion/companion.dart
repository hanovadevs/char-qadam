import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'experience_provider.dart';

/// One lazily decoded clip per playing widget: 768x512 RGBA = 1.5 MiB.
/// Static slots share Flutter's small image cache; no perpetual ticker.
class Companion extends ConsumerStatefulWidget {
  final String clip;
  final double size;
  final int event;

  /// Used only while the parent has a recent movement event and a rest timer.
  final bool repeat;
  const Companion({
    super.key,
    this.clip = 'rest',
    this.size = 72,
    this.event = 0,
    this.repeat = false,
  });
  @override
  ConsumerState<Companion> createState() => _CompanionState();
}

class _CompanionState extends ConsumerState<Companion>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishMetrics();
      });
  final List<FrameTiming> _timings = [];
  bool _recording = false;
  int _decodeMs = 0;
  String _metricsClip = '';
  void _record(List<FrameTiming> timings) {
    if (_recording) {
      _timings.addAll(timings);
      if (_timings.length >= 120) _finishMetrics();
    }
  }

  void _finishMetrics() {
    if (!_recording) return;
    _recording = false;
    SchedulerBinding.instance.removeTimingsCallback(_record);
    if (_timings.isEmpty) return;
    final build = _timings.map((f) => f.buildDuration.inMicroseconds).toList()
      ..sort();
    final raster = _timings.map((f) => f.rasterDuration.inMicroseconds).toList()
      ..sort();
    final index = ((build.length - 1) * .95).round();
    debugPrint(
      'StepsyCompanion clip=$_metricsClip frames=${build.length} decode_ms=$_decodeMs build_p95_us=${build[index]} raster_p95_us=${raster[index]} decoded_bytes=${(_image?.width ?? 0) * (_image?.height ?? 0) * 4}',
    );
  }

  ui.Image? _image;
  int _request = 0;
  bool _animate = false;
  String? _played;
  String? _imageClip;
  String? _loading;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant Companion old) {
    super.didUpdateWidget(old);
    if (old.clip != widget.clip ||
        old.event != widget.event ||
        old.repeat != widget.repeat) {
      _load();
    }
  }

  Future<void> _load() async {
    final signature = '${widget.clip}:${widget.event}';
    final canAnimate =
        widget.clip != 'rest' &&
        !MediaQuery.disableAnimationsOf(context) &&
        ref.read(experienceProvider).animations &&
        TickerMode.valuesOf(context).enabled;
    if (!canAnimate) {
      _request++;
      _loading = null;
      _finishMetrics();
      _controller.stop();
      _animate = false;
      _image?.dispose();
      _image = null;
      _imageClip = null;
      return;
    }
    // Dependency rebuilds and background sync must not cut a playing clip short.
    if (_loading == signature ||
        (_played == signature && (_image != null || !widget.repeat))) {
      return;
    }
    _finishMetrics();
    final request = ++_request;
    _loading = signature;
    _controller.stop();
    _animate = false;
    try {
      final decoding = Stopwatch()..start();
      if (_image == null || _imageClip != widget.clip) {
        final clip = widget.clip;
        final data = await rootBundle.load(
          'assets/companion/animations/$clip.png',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        codec.dispose();
        if (!mounted || request != _request) {
          frame.image.dispose();
          return;
        }
        _image?.dispose();
        _image = frame.image;
        _imageClip = clip;
      }
      setState(() {
        _animate = true;
        _played = signature;
        _loading = null;
      });
      if (kProfileMode) {
        _metricsClip = widget.clip;
        _decodeMs = decoding.elapsedMilliseconds;
        _timings.clear();
        _recording = true;
        SchedulerBinding.instance.addTimingsCallback(_record);
      }
      if (widget.repeat) {
        _controller.repeat(period: const Duration(seconds: 1));
      } else {
        _controller.forward(from: 0);
      }
    } catch (_) {
      if (request == _request) _loading = null;
      /* A missing clip leaves the static fallback usable. */
    }
  }

  @override
  void dispose() {
    _finishMetrics();
    _request++;
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      experienceProvider.select((s) => s.animations),
      (_, _) => _load(),
    );
    final enabled = ref.watch(experienceProvider.select((s) => s.animations));
    final reduced = MediaQuery.disableAnimationsOf(context) || !enabled;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: !reduced && _animate && _image != null
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => _controller.isCompleted
                      ? Image.asset(
                          'assets/companion/static/rest.png',
                          gaplessPlayback: true,
                        )
                      : CustomPaint(
                          painter: _SpritePainter(
                            _image!,
                            (_controller.value * 24).floor().clamp(0, 23),
                          ),
                        ),
                )
              : Image.asset(
                  'assets/companion/static/rest.png',
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image atlas;
  final int frame;
  _SpritePainter(this.atlas, this.frame);
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    atlas,
    Rect.fromLTWH((frame % 6) * 128, (frame ~/ 6) * 128, 128, 128),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.atlas != atlas || old.frame != frame;
}
