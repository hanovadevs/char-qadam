import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/leaderboard/leaderboard_repository.dart';
import '../../../data/models/leaderboard_models.dart';

class LeaderboardState {
  final bool isLoading;
  final String selectedScope;
  final LeaderboardResponseModel? data;
  final String? errorMessage;

  const LeaderboardState({
    this.isLoading = false,
    this.selectedScope = 'week',
    this.data,
    this.errorMessage,
  });

  LeaderboardState copyWith({
    bool? isLoading,
    String? selectedScope,
    LeaderboardResponseModel? data,
    String? errorMessage,
  }) {
    return LeaderboardState(
      isLoading: isLoading ?? this.isLoading,
      selectedScope: selectedScope ?? this.selectedScope,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }
}

final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  final repository = ref.watch(leaderboardRepositoryProvider);
  return LeaderboardNotifier(repository: repository);
});

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final LeaderboardRepository repository;

  LeaderboardNotifier({required this.repository})
      : super(const LeaderboardState()) {
    fetchLeaderboard(state.selectedScope);
  }

  Future<void> fetchLeaderboard(String scope) async {
    state = state.copyWith(isLoading: true, selectedScope: scope, errorMessage: null);
    try {
      final data = await repository.getLeaderboard(scope: scope);
      state = state.copyWith(
        isLoading: false,
        selectedScope: scope,
        data: data,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> refresh() async {
    await fetchLeaderboard(state.selectedScope);
  }
}
