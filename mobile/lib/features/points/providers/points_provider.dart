import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/points_models.dart';
import '../../../data/points/points_repository.dart';

class PointsState {
  final BalanceModel? balanceData;
  final List<LedgerEntryModel> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final int offset;
  final String? errorMessage;

  static const int pageSize = 20;

  const PointsState({
    this.balanceData,
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.total = 0,
    this.offset = 0,
    this.errorMessage,
  });

  PointsState copyWith({
    BalanceModel? balanceData,
    List<LedgerEntryModel>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    int? offset,
    String? errorMessage,
  }) {
    return PointsState(
      balanceData: balanceData ?? this.balanceData,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      offset: offset ?? this.offset,
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
    if (state.isLoading || state.isLoadingMore) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final (balance, history) = await (
        pointsRepository.getBalance(),
        pointsRepository.getHistory(limit: PointsState.pageSize, offset: 0),
      ).wait;
      if (!mounted) return;
      state = PointsState(
        balanceData: balance,
        entries: history.entries,
        isLoading: false,
        total: history.total,
        offset: history.entries.length,
        hasMore: history.entries.length < history.total,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final history = await pointsRepository.getHistory(
        limit: PointsState.pageSize,
        offset: state.offset,
      );
      if (!mounted) return;
      final allEntries = [...state.entries, ...history.entries];
      state = state.copyWith(
        entries: allEntries,
        isLoadingMore: false,
        offset: allEntries.length,
        hasMore: allEntries.length < history.total,
        total: history.total,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
