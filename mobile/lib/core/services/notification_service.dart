import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initializing;
  static final destination = ValueNotifier<String?>(null);
  static const _native = MethodChannel('stepsy/reminders');
  static const _routes = {'/steps', '/wallet', '/points', '/tracking-help'};
  static void queueDestination(String? route) {
    if (route != null && _routes.contains(route)) destination.value = route;
  }

  static Future<bool> _allowed(String category) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      return category != 'points';
    }
    try {
      return await _native.invokeMethod<bool>('eventAllowed', {
            'category': category,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static const String _channelId = 'stepsy_reward_updates';
  static const String _channelName = 'Reward updates';
  static const String _channelDesc =
      'Optional reward confirmations and points updates';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        icon: 'ic_step_tracking',
        visibility: NotificationVisibility.private,
      );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);
  static Future<void> _initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('ic_step_tracking');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          queueDestination(response.payload);
        },
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        queueDestination(launch?.notificationResponse?.payload);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  /// Request runtime permissions on Android 13+ and iOS
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      await initialize();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImpl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
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

  /// Display an instant notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !await _allowed(id == 4001 ? 'points' : 'rewards')) return;
    try {
      await initialize();
      await _plugin.show(
        id,
        title,
        body,
        _notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Expiring voucher warning
  static Future<void> showVoucherExpiring({
    required String offerTitle,
    required String shortCode,
    required int daysLeft,
  }) async {
    await showNotification(
      id: 2000 + shortCode.hashCode.abs() % 1000,
      title: 'A little reminder about your reward',
      body:
          'Your reward for $offerTitle expires in $daysLeft ${daysLeft == 1 ? "day" : "days"}! Redeem at store.',
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
      title: 'Your little win is in Wallet',
      body: '$offerTitle is ready. Open Wallet to show your voucher in store.',
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
      title: 'Your walking points are in',
      body:
          '+$pointsAwarded points confirmed from your movement. Balance: $totalBalance points.',
      payload: '/points',
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    destination.value = null;
    try {
      await _native.invokeMethod<void>('deactivate');
    } on MissingPluginException {
      // Other targets have no Android reminder worker.
    } on PlatformException {
      // Clearing the session must still complete if notification cleanup fails.
    }
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
