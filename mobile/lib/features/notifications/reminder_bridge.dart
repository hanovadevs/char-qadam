import 'package:flutter/services.dart';

class ReminderBridge {
  static const channel = MethodChannel('stepsy/reminders');
  static Future<void> configure({
    required String? userId,
    required bool customer,
    required Map<String, dynamic> settings,
    required int goal,
  }) async {
    try {
      await channel.invokeMethod<void>('configure', {
        'userId': userId,
        'customer': customer,
        'settings': settings,
        'goal': goal,
      });
    } on MissingPluginException {
      /* Android reminders; other targets retain event notifications. */
    }
  }

  static Future<bool> preview() async =>
      await channel.invokeMethod<bool>('preview') ?? false;
}
