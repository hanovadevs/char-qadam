import 'package:flutter_test/flutter_test.dart';
import 'package:qadam/core/services/notification_service.dart';
void main() {
  test('Notifications default to opt-in and hide personal progress', () {
    const settings = NotificationPreferences();
    expect(settings.enabled, isFalse);
    expect(settings.reminders, isFalse);
    expect(settings.showProgress, isFalse);
  });
  test('Quiet hours span midnight and stable notification IDs repeat', () {
    expect(NotificationService.isQuietHour(22), isTrue);
    expect(NotificationService.isQuietHour(8), isTrue);
    expect(NotificationService.isQuietHour(9), isFalse);
    expect(NotificationService.isQuietHour(21), isFalse);
    expect(NotificationService.stableId('goal'), NotificationService.stableId('goal'));
  });
}
