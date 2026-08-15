import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthService {
  final Health _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
  ];

  /// Request authorization to read step count data.
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final hasPermission = await _health.hasPermissions(_types);
      if (hasPermission == true) return true;
      
      final requested = await _health.requestAuthorization(_types);
      return requested;
    } catch (e) {
      debugPrint('Health permission error: $e');
      return false;
    }
  }

  /// Fetch total step count for today (local midnight to now).
  /// Returns 0 if permissions are not granted or health data is unavailable.
  Future<int> fetchTodaySteps() async {
    if (kIsWeb) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint('Error fetching today steps: $e');
      return 0;
    }
  }
}
