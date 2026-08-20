import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/points_models.dart';
import '../../../data/points/points_repository.dart';

class PointsState {
  final BalanceModel? balanceData;
  final LedgerPageModel? ledgerPage;
  final bool isLoading;
  final String? errorMessage;

  const PointsState({
    this.balanceData,
    this.ledgerPage,
    this.isLoading = false,
    this.errorMessage,
  });

  PointsState copyWith({
    BalanceModel? balanceData,
    LedgerPageModel? ledgerPage,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PointsState(
      balanceData: balanceData ?? this.balanceData,
      ledgerPage: ledgerPage ?? this.ledgerPage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final pointsProvider =
    StateNotifierProvider<PointsNotifier, PointsState>((ref) {
  final pointsRepository = ref.watch(pointsRepositoryProvider);
  return PointsNotifier(pointsRepository: pointsRepository);
});

class PointsNotifier extends StateNotifier<PointsState> {
  final PointsRepository pointsRepository;

  PointsNotifier({required this.pointsRepository})
      : super(const PointsState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final balance = await pointsRepository.getBalance();
      final history = await pointsRepository.getHistory(limit: 50, offset: 0);
      state = PointsState(
        balanceData: balance,
        ledgerPage: history,
        isLoading: false,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }
}
