import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/auth_state_provider.dart';

/// Personal UI preferences, isolated by account and stored only on this phone.
/// These never change the earning cap, streak policy or reward economics.
class ExperiencePreferences {
  final int goal;
  final bool animations, tips, loaded;
  final String? rewardId, celebratedEvent;
  const ExperiencePreferences({
    this.goal = 8000,
    this.animations = true,
    this.tips = true,
    this.loaded = false,
    this.rewardId,
    this.celebratedEvent,
  });
}

final experienceProvider =
    StateNotifierProvider<ExperienceNotifier, ExperiencePreferences>((ref) {
      final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
      return ExperienceNotifier(userId);
    });

class ExperienceNotifier extends StateNotifier<ExperiencePreferences> {
  final String? userId;
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  ExperienceNotifier(this.userId) : super(const ExperiencePreferences()) {
    ready = _load();
  }
  String get _key => 'stepsy.experience.v1.$userId';
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = userId == null ? null : prefs.getString(_key);
      final data = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      final goal = data['goal'];
      state = ExperiencePreferences(
        goal: goal is int && goal >= 1000 && goal <= 50000 ? goal : 8000,
        animations: data['animations'] != false,
        tips: data['tips'] != false,
        loaded: true,
        rewardId: data['rewardId'] as String?,
        celebratedEvent: data['celebratedEvent'] as String?,
      );
    } catch (_) {
      if (mounted) state = const ExperiencePreferences(loaded: true);
    }
  }

  Future<void> update({
    int? goal,
    bool? animations,
    bool? tips,
    String? rewardId,
    bool clearReward = false,
    String? celebratedEvent,
  }) async {
    if (!mounted || userId == null) return;
    if (!state.loaded) await ready;
    if (!mounted) return;
    if (goal != null && (goal < 1000 || goal > 50000)) return;
    state = ExperiencePreferences(
      goal: goal ?? state.goal,
      animations: animations ?? state.animations,
      tips: tips ?? state.tips,
      loaded: true,
      rewardId: clearReward ? null : rewardId ?? state.rewardId,
      celebratedEvent: celebratedEvent ?? state.celebratedEvent,
    );
    final snapshot = state;
    final encoded = jsonEncode({
      'goal': snapshot.goal,
      'animations': snapshot.animations,
      'tips': snapshot.tips,
      'rewardId': snapshot.rewardId,
      'celebratedEvent': snapshot.celebratedEvent,
    });
    _writes = _writes.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, encoded)) {
        throw StateError('Preferences could not be saved');
      }
    });
    await _writes;
  }
}
