import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/auth/auth_state_provider.dart';
import 'tour_content.dart';

class TourProgress {
  final bool loaded, saveFailed;
  final String status;
  final int index;
  const TourProgress({
    this.loaded = false,
    this.status = 'new',
    this.index = 0,
    this.saveFailed = false,
  });
  bool get active => loaded && status == 'active';
}

final guidedTourProvider = StateNotifierProvider<TourController, TourProgress>((
  ref,
) {
  final auth = ref.watch(
    authStateProvider.select((s) => (s.user?.id, s.user?.isMerchant)),
  );
  return TourController(auth.$2 == true ? null : auth.$1);
});

class TourController extends StateNotifier<TourProgress> {
  final String? userId;
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  TourController(this.userId) : super(const TourProgress()) {
    ready = _load();
  }
  String get storageKey => 'stepsy.guided-tour.v1.$userId';
  Future<void> _load() async {
    var status = userId == null ? 'disabled' : 'new';
    var index = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && userId != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (['active', 'completed', 'skipped'].contains(data['status'])) {
          status = data['status'] as String;
        }
        if (data['index'] is int) {
          index = (data['index'] as int).clamp(0, tourStops.length - 1);
        }
      }
    } catch (_) {
      /* An unreadable checkpoint starts a fresh, skippable tour. */
    }
    if (mounted) {
      state = TourProgress(loaded: true, status: status, index: index);
    }
  }

  Future<void> start() async {
    await ready;
    if (mounted && userId != null) await _save('active', 0);
  }

  Future<void> move(int index) async {
    if (state.active) {
      await _save('active', index.clamp(0, tourStops.length - 1));
    }
  }

  Future<void> finish({bool skipped = false}) =>
      _save(skipped ? 'skipped' : 'completed', state.index);
  Future<void> _save(String status, int index) async {
    if (!mounted || userId == null) return;
    state = TourProgress(loaded: true, status: status, index: index);
    final data = jsonEncode({'status': status, 'index': index});
    _writes = _writes.catchError((_) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(storageKey, data)) {
          throw StateError('Tour save failed');
        }
      } catch (_) {
        if (mounted) {
          state = TourProgress(
            loaded: true,
            status: state.status,
            index: state.index,
            saveFailed: true,
          );
        }
      }
    });
    await _writes;
  }
}
