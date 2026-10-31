import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_service.dart';
import '../../data/auth/auth_state_provider.dart';
import '../../routing/app_router.dart';
import '../companion/experience_provider.dart';
import 'notification_preferences.dart';
import 'reminder_bridge.dart';

/// Auth gates every notification destination; reminders never sign in or resume tracking.
class NotificationCoordinator extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationCoordinator({super.key, required this.child});
  @override
  ConsumerState<NotificationCoordinator> createState() =>
      _NotificationCoordinatorState();
}

class _NotificationCoordinatorState
    extends ConsumerState<NotificationCoordinator> {
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    NotificationService.destination.addListener(_open);
    ReminderBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'open') {
        try {
          await ReminderBridge.channel.invokeMethod<String>('consumeLaunch');
        } on PlatformException {
          // The delivered route can still be handled if native cleanup fails.
        }
        if (mounted && call.arguments is String) {
          NotificationService.queueDestination(call.arguments as String);
        }
      }
    });
    ref.listenManual(
      authStateProvider.select((s) => (s.status, s.user?.id, s.user?.role)),
      (_, _) => _schedule(),
      fireImmediately: true,
    );
    ref.listenManual(notificationPreferencesProvider, (_, _) => _schedule());
    ref.listenManual(
      experienceProvider.select((s) => (s.goal, s.loaded)),
      (_, _) => _schedule(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.initialize();
      try {
        NotificationService.queueDestination(
          await ReminderBridge.channel.invokeMethod<String>('consumeLaunch'),
        );
      } on MissingPluginException {
        /* Android-only launch extras. */
      } on PlatformException {
        /* Existing routes stay usable if native notification setup fails. */
      }
      if (mounted) _open();
    });
  }

  void _schedule() {
    final generation = ++_generation;
    Future<void>(() async {
      if (!mounted || generation != _generation) return;
      final auth = ref.read(authStateProvider);
      // Do not overwrite persisted state during startup credential resolution.
      if (auth.status == AuthStatus.initial) return;
      final notifier = ref.read(notificationPreferencesProvider.notifier);
      await notifier.ready;
      if (!mounted || generation != _generation) return;
      final latest = ref.read(authStateProvider);
      try {
        await ReminderBridge.configure(
          userId: latest.user?.id,
          customer:
              latest.status == AuthStatus.authenticated &&
              latest.user != null &&
              !latest.user!.isMerchant,
          settings: ref.read(notificationPreferencesProvider).toJson(),
          goal: ref.read(experienceProvider).goal,
        );
      } on PlatformException {
        /* Preference screen provides retry; never block authentication. */
      }
      if (mounted) _open();
    });
  }

  void _open() {
    if (!mounted) return;
    final route = NotificationService.destination.value;
    if (route == null) return;
    final auth = ref.read(authStateProvider);
    if (auth.status != AuthStatus.authenticated) return;
    NotificationService.destination.value = null;
    if (auth.user?.isMerchant == true) return;
    ref.read(routerProvider).go(route);
  }

  @override
  void dispose() {
    _generation++;
    NotificationService.destination.removeListener(_open);
    ReminderBridge.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
