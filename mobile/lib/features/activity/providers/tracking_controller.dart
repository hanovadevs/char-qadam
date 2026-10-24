import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackingStatus {
  final bool paused, running, unrestricted;
  const TrackingStatus({
    required this.paused,
    required this.running,
    required this.unrestricted,
  });
  factory TrackingStatus.parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return TrackingStatus(
      paused: data['paused'] == true,
      running: data['running'] == true,
      unrestricted: data['unrestricted'] == true,
    );
  }
}

final trackingControllerProvider =
    StateNotifierProvider.autoDispose<TrackingController, TrackingStatus?>(
      (ref) => TrackingController(),
    );

class TrackingController extends StateNotifier<TrackingStatus?> {
  static const channel = MethodChannel('stepsy/step_tracking');
  static const events = EventChannel('stepsy/tracking_state');
  StreamSubscription<dynamic>? _subscription;
  TrackingController() : super(null) {
    refresh();
  }
  Future<void> refresh() async {
    try {
      final raw = await channel.invokeMethod<String>('ensureTracking');
      if (!mounted || raw == null) return;
      state = TrackingStatus.parse(raw);
      _subscription ??= events.receiveBroadcastStream().listen((raw) {
        if (mounted) state = TrackingStatus.parse(raw as String);
      }, onError: (Object _) {});
    } on MissingPluginException {
      /* Android-only native controls. */
    } on PlatformException {
      /* Existing activity error/permission UI stays available. */
    }
  }

  Future<bool> resume() async {
    final result =
        await channel.invokeMethod<bool>('start', {'resume': true}) ?? false;
    await refresh();
    return result;
  }

  Future<void> pause() async {
    await channel.invokeMethod<void>('pause');
    await refresh();
  }

  Future<void> batterySettings() =>
      channel.invokeMethod<void>('batterySettings');
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
