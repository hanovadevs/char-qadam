import 'package:flutter/services.dart';

class HapticsService {
  /// Subtle feedback on tap/toggle
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium feedback on button actions (e.g. step sync)
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Strong tactile feedback on confirmations (e.g. redeem)
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection click on navigation tabs and segment switchers
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
