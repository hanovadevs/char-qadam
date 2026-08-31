import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'stepsy_channel';
  static const String _channelName = 'Stepsy Movement & Rewards';
  static const String _channelDesc = 'Daily step tracking reminders and voucher expiry notices';

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  /// Request runtime permissions on Android 13+ and iOS
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }

  /// Display an ongoing 24/7 background step tracking notification (keeps pedometer active)
  static Future<void> updateOngoingStepNotification({
    required int stepsToday,
    required int dailyGoal,
  }) async {
    if (kIsWeb) return;
    try {
      await initialize();
      const androidOngoingDetails = AndroidNotificationDetails(
        'stepsy_tracking_channel',
        'Stepsy 24/7 Step Tracking',
        channelDescription: 'Ongoing background pedometer tracking service',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidOngoingDetails);
      await _plugin.show(
        9999,
        'STEPSY • TRACKING STEPS',
        '$stepsToday / $dailyGoal steps today • Earning rewards',
        details,
        payload: '/steps',
      );
    } catch (e) {
      debugPrint('Error updating ongoing tracking notification: $e');
    }
  }

  /// Display an instant notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      await initialize();
      await _plugin.show(id, title, body, _notificationDetails, payload: payload);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Daily step reminder (fired when user is under daily goal in evening)
  static Future<void> showStepReminder({
    required int currentSteps,
    required int goalSteps,
  }) async {
    final remaining = (goalSteps - currentSteps).clamp(0, goalSteps);
    await showNotification(
      id: 1001,
      title: 'STEPSY • EVENING STEP CHECK-IN',
      body: remaining > 0
          ? 'You have $remaining steps left to hit your daily $goalSteps goal! Take a quick walk.'
          : 'You hit your daily goal of $goalSteps steps! Points minted to your balance.',
      payload: '/steps',
    );
  }

  /// Expiring voucher warning
  static Future<void> showVoucherExpiring({
    required String offerTitle,
    required String shortCode,
    required int daysLeft,
  }) async {
    await showNotification(
      id: 2000 + shortCode.hashCode.abs() % 1000,
      title: 'STEPSY • VOUCHER EXPIRING SOON',
      body: 'Your pass for $offerTitle ($shortCode) expires in $daysLeft ${daysLeft == 1 ? "day" : "days"}! Redeem at store.',
      payload: '/wallet',
    );
  }

  /// Instant voucher minted celebration notification
  static Future<void> showVoucherMinted({
    required String offerTitle,
    required String shortCode,
  }) async {
    await showNotification(
      id: 3000 + shortCode.hashCode.abs() % 1000,
      title: 'STEPSY • VOUCHER READY IN WALLET',
      body: '$offerTitle ($shortCode) pass is ready to present at store checkout.',
      payload: '/wallet',
    );
  }

  /// Step conversion milestone notification
  static Future<void> showPointsEarned({
    required int pointsAwarded,
    required int totalBalance,
  }) async {
    if (pointsAwarded <= 0) return;
    await showNotification(
      id: 4001,
      title: 'STEPSY • POINTS MINTED',
      body: '+$pointsAwarded PTS earned from today\'s movement! Balance: $totalBalance PTS.',
      payload: '/points',
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
