import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final bool enabled;
  final bool reminders;
  final bool milestones;
  final bool voucherExpiry;
  final bool playful;
  final bool showProgress;
  final int dailyGoal;
  const NotificationPreferences({this.enabled = false, this.reminders = false,
    this.milestones = true, this.voucherExpiry = true, this.playful = true,
    this.showProgress = false, this.dailyGoal = 6000});
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static String? _userId;
  static void Function(String)? onTap;
  static String? pendingRoute;
  static Future<void> _queue = Future.value();
  static const _allowedRoutes = {'/steps', '/points', '/wallet'};

  static void _handleTap(String? payload) {
    if (!_allowedRoutes.contains(payload)) return;
    if (onTap != null) { onTap!(payload!); } else { pendingRoute = payload; }
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;
    await (_initialization ??= _initialize());
  }
  static Future<void> _initialize() async {
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ), onDidReceiveNotificationResponse: (response) => _handleTap(response.payload));
      await _plugin.cancel(9999); // Remove the old permanent tracking notification.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) _handleTap(launch?.notificationResponse?.payload);
    } catch (error) { debugPrint('Notifications unavailable: $error'); }
  }

  static Future<void> setUser(String? userId, {bool clearExisting = true}) async {
    if (_userId != userId) {
      _userId = userId;
      pendingRoute = null;
      if (clearExisting) await cancelAll();
    }
  }

  static Future<NotificationPreferences> preferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notifications_${_userId ?? 'signed_out'}_';
    return NotificationPreferences(
      enabled: prefs.getBool('${key}enabled') ?? false,
      reminders: prefs.getBool('${key}reminders') ?? false,
      milestones: prefs.getBool('${key}milestones') ?? true,
      voucherExpiry: prefs.getBool('${key}expiry') ?? true,
      playful: prefs.getBool('${key}playful') ?? true,
      showProgress: prefs.getBool('${key}progress') ?? false,
      dailyGoal: prefs.getInt('${key}goal') ?? 6000,
    );
  }
  static Future<void> savePreferences(NotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notifications_${_userId ?? 'signed_out'}_';
    await Future.wait([
      prefs.setBool('${key}enabled', value.enabled), prefs.setBool('${key}reminders', value.reminders),
      prefs.setBool('${key}milestones', value.milestones), prefs.setBool('${key}expiry', value.voucherExpiry),
      prefs.setBool('${key}playful', value.playful), prefs.setBool('${key}progress', value.showProgress),
      prefs.setInt('${key}goal', value.dailyGoal),
    ]);
    if (!value.enabled) await cancelAll();
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  static bool isQuietHour(int hour) => hour >= 22 || hour < 9;
  static int stableId(String text) => text.codeUnits.fold(17, (value, character) => (value * 31 + character) & 0x7fffffff);

  static Future<void> _notify({required String event, required String title, required String body, required String route}) {
    // Serializing checks prevents two simultaneous events exceeding the daily cap.
    final next = _queue.then((_) async {
      final user = _userId;
      if (kIsWeb || user == null) return;
      final settings = await preferences();
      final now = DateTime.now();
      if (!settings.enabled || isQuietHour(now.hour)) return;
      final prefs = await SharedPreferences.getInstance();
      final day = '${now.year}-${now.month}-${now.day}';
      final prefix = 'notification_${user}_$day';
      if (prefs.getBool('${prefix}_$event') == true) return;
      final count = prefs.getInt('${prefix}_count') ?? 0;
      final last = prefs.getInt('notification_${user}_last') ?? 0;
      if (count >= 2 || now.millisecondsSinceEpoch - last < const Duration(hours: 3).inMilliseconds) return;
      await initialize();
      if (_userId != user) return;
      await _plugin.show(stableId(event), title, body, const NotificationDetails(
        android: AndroidNotificationDetails('stepsy_updates_v2', 'Stepsy updates',
          channelDescription: 'Optional milestones and reward reminders', importance: Importance.defaultImportance,
          priority: Priority.defaultPriority, visibility: NotificationVisibility.private,
          icon: '@mipmap/launcher_icon'),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: false),
      ), payload: route);
      await prefs.setBool('${prefix}_$event', true);
      await prefs.setInt('${prefix}_count', count + 1);
      await prefs.setInt('notification_${user}_last', now.millisecondsSinceEpoch);
    }).catchError((Object error) { debugPrint('Notification skipped: $error'); });
    _queue = next;
    return next;
  }

  static Future<void> checkProgress({required int stepsToday}) async {
    final settings = await preferences();
    if (!settings.enabled) return;
    if (settings.milestones && stepsToday >= settings.dailyGoal) {
      await _notify(event: 'goal', title: settings.playful ? 'Main character walk complete ✨' : 'Daily walking goal reached',
        body: settings.showProgress ? '$stepsToday steps today. Your ${settings.dailyGoal}-step goal is complete.' : 'Your walking goal is complete. Nicely done.', route: '/steps');
    } else if (settings.milestones && stepsToday >= settings.dailyGoal ~/ 2) {
      await _notify(event: 'halfway', title: settings.playful ? 'A little walk. A solid flex. 👟' : 'You are halfway to your walking goal',
        body: settings.showProgress ? '$stepsToday steps today. Halfway to your goal.' : 'You are making progress toward your walking goal.', route: '/steps');
    } else if (settings.reminders && DateTime.now().hour >= 18 && DateTime.now().hour < 21 && stepsToday > 0) {
      await _notify(event: 'checkin', title: settings.playful ? 'Tiny walk, fresh energy?' : 'Your optional walking check-in',
        body: settings.showProgress ? '${settings.dailyGoal - stepsToday} steps to your goal, if a walk fits your evening.' : 'If it suits your evening, a short walk is an option. No pressure.', route: '/steps');
    }
  }

  static Future<void> showPointsEarned({required int pointsAwarded, required int totalBalance}) async {
    final settings = await preferences();
    if (!settings.enabled || !settings.milestones || pointsAwarded <= 0) return;
    await _notify(event: 'points', title: settings.playful ? 'Your steps understood the assignment ✨' : 'New points earned',
      body: settings.showProgress ? '+$pointsAwarded points confirmed. Balance: $totalBalance.' : 'New points were confirmed. See your balance in the app.', route: '/points');
  }

  static Future<void> showVoucherMinted({required String offerTitle, required String shortCode}) async {
    final settings = await preferences();
    if (!settings.enabled) return;
    await _notify(event: 'voucher_ready', title: settings.playful ? 'Reward secured 🎟️' : 'Your voucher is ready',
      body: 'Open Wallet to see your voucher and its terms.', route: '/wallet');
  }

  static Future<void> showVoucherExpiring({required String offerTitle, required String shortCode, required int daysLeft}) async {
    final settings = await preferences();
    if (!settings.enabled || !settings.voucherExpiry || daysLeft < 0 || daysLeft > 3) return;
    await _notify(event: 'voucher_expiry', title: settings.playful ? 'A heads-up for future you 🎟️' : 'A voucher expires soon',
      body: 'A voucher in Wallet expires ${daysLeft == 0 ? 'today' : 'in $daysLeft days'}. Check its terms before visiting the store.', route: '/wallet');
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try { await _plugin.cancelAll(); } catch (_) {}
  }
}
