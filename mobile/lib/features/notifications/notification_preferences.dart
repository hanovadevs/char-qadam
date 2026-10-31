import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/auth_state_provider.dart';

class NotificationPreferences {
  final bool enabled, walking, tracking, returning, rewards, points, loaded;
  final int hour, minute;
  const NotificationPreferences({
    this.enabled = true,
    this.walking = true,
    this.tracking = true,
    this.returning = true,
    this.rewards = true,
    this.points = false,
    this.hour = 18,
    this.minute = 0,
    this.loaded = false,
  });
  factory NotificationPreferences.fromJson(Map<String, dynamic> data) =>
      NotificationPreferences(
        enabled: data['enabled'] != false,
        walking: data['walking'] != false,
        tracking: data['tracking'] != false,
        returning: data['returning'] != false,
        rewards: data['rewards'] != false,
        points: data['points'] == true,
        hour: data['hour'] is int ? (data['hour'] as int).clamp(9, 20) : 18,
        minute: data['minute'] is int
            ? (data['minute'] as int).clamp(0, 59)
            : 0,
        loaded: true,
      );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'walking': walking,
    'tracking': tracking,
    'returning': returning,
    'rewards': rewards,
    'points': points,
    'hour': hour,
    'minute': minute,
  };
}

final notificationPreferencesProvider =
    StateNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >((ref) {
      final id = ref.watch(authStateProvider.select((s) => s.user?.id));
      return NotificationPreferencesNotifier(id);
    });

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  final String? userId;
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  NotificationPreferencesNotifier(this.userId)
    : super(const NotificationPreferences()) {
    ready = _load();
  }
  String get _key => 'stepsy.notifications.v1.$userId';
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = userId == null ? null : prefs.getString(_key);
      final data = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) state = NotificationPreferences.fromJson(data);
    } catch (_) {
      if (mounted) state = const NotificationPreferences(loaded: true);
    }
  }

  Future<void> update(Map<String, dynamic> changes) async {
    if (userId == null) return;
    await ready;
    if (!mounted) return;
    final patch = Map<String, dynamic>.from(changes);
    // Persist first: a failed write must not pretend the preference was saved.
    _writes = _writes.catchError((_) {}).then((_) async {
      if (!mounted) return;
      final next = NotificationPreferences.fromJson({
        ...state.toJson(),
        ...patch,
      });
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, jsonEncode(next.toJson()))) {
        throw StateError('Could not save notification preferences');
      }
      if (mounted) state = next;
    });
    await _writes;
  }
}
