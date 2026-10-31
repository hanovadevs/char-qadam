import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/features/notifications/notification_preferences.dart';
void main() {
  test('Point alerts are optional and reminder hours are bounded', () {
    expect(const NotificationPreferences().points, isFalse);
    expect(NotificationPreferences.fromJson({'hour': 23}).hour, 20);
    expect(NotificationPreferences.fromJson({'hour': 2}).hour, 9);
  });
}
