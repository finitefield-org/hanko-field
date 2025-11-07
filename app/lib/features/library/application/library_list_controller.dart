import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/design_repository.dart';
import 'package:app/features/library/data/design_repository_provider.dart';
import 'package:app/features/library/domain/library_list_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final libraryListFilterProvider = StateProvider<LibraryListFilter>(
  (ref) => LibraryListFilter(),
);

final libraryListSortProvider = StateProvider<LibrarySortOption>(
  (ref) => LibrarySortOption.recent,
);

final libraryListSearchProvider = StateProvider<String>((ref) => '');

final libraryListViewModeProvider = StateProvider<LibraryViewMode>(
  (ref) => LibraryViewMode.grid,
);

final libraryListControllerProvider =
    AsyncNotifierProvider<LibraryListController, LibraryListState>(
      LibraryListController.new,
    );

class LibraryListState {
  const LibraryListState({
    required this.designs,
    required this.filter,
    required this.sort,
    required this.searchQuery,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  final List<Design> designs;
  final LibraryListFilter filter;
  final LibrarySortOption sort;
  final String searchQuery;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  static const _sentinel = Object();

  LibraryListState copyWith({
    List<Design>? designs,
    LibraryListFilter? filter,
    LibrarySortOption? sort,
    String? searchQuery,
    Object? nextCursor = _sentinel,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    DateTime? lastUpdated,
  }) {
    return LibraryListState(
      designs: designs ?? this.designs,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      nextCursor: identical(nextCursor, _sentinel)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class LibraryListController extends AsyncNotifier<LibraryListState> {
  static const int pageSize = 12;

  DesignRepository get _repository => ref.read(designRepositoryProvider);

  @override
  FutureOr<LibraryListState> build() async {
    final filter = ref.watch(libraryListFilterProvider);
    final sort = ref.watch(libraryListSortProvider);
    final search = ref.watch(libraryListSearchProvider);
    return _loadInitial(filter, sort, search);
  }

  Future<LibraryListState> _loadInitial(
    LibraryListFilter filter,
    LibrarySortOption sort,
    String search,
  ) async {
    final normalizedQuery = search.trim();
    final result = await _repository.fetchDesigns(
      pageSize: pageSize + 1,
      filters: filter.toQueryMap(sort: sort, searchQuery: normalizedQuery),
    );
    final items = result.take(pageSize).toList(growable: false);
    final hasMore = result.length > pageSize;
    final nextCursor = hasMore && items.isNotEmpty ? items.last.id : null;
    return LibraryListState(
      designs: List<Design>.unmodifiable(items),
      filter: filter,
      sort: sort,
      searchQuery: normalizedQuery,
      hasMore: hasMore,
      nextCursor: nextCursor,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isRefreshing: true));
    }
    try {
      final filter = ref.read(libraryListFilterProvider);
      final sort = ref.read(libraryListSortProvider);
      final search = ref.read(libraryListSearchProvider);
      final next = await _loadInitial(filter, sort, search);
      state = AsyncValue.data(next);
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    final cursorSnapshot = current.nextCursor;
    if (cursorSnapshot == null) {
      return;
    }
    final filterSnapshot = ref.read(libraryListFilterProvider);
    final sortSnapshot = ref.read(libraryListSortProvider);
    final searchSnapshot = ref.read(libraryListSearchProvider);
    final pending = current.copyWith(isLoadingMore: true);
    state = AsyncValue.data(pending);
    try {
      final result = await _repository.fetchDesigns(
        pageSize: pageSize + 1,
        pageToken: cursorSnapshot,
        filters: filterSnapshot.toQueryMap(
          sort: sortSnapshot,
          searchQuery: searchSnapshot,
        ),
      );
      final latest = state.asData?.value;
      if (latest == null ||
          latest.filter != filterSnapshot ||
          latest.sort != sortSnapshot ||
          latest.searchQuery != searchSnapshot ||
          latest.nextCursor != cursorSnapshot) {
        return;
      }
      if (result.isEmpty) {
        state = AsyncValue.data(
          latest.copyWith(
            hasMore: false,
            nextCursor: null,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }
      final newItems = result.take(pageSize).toList();
      final existingIds = <String>{
        for (final design in latest.designs) design.id,
      };
      final appended = <Design>[];
      for (final design in newItems) {
        if (existingIds.add(design.id)) {
          appended.add(design);
        }
      }
      if (appended.isEmpty) {
        state = AsyncValue.data(
          latest.copyWith(
            hasMore: false,
            nextCursor: null,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }
      final merged = [...latest.designs, ...appended];
      final hasMore = result.length > pageSize;
      final nextCursor = hasMore ? merged.last.id : null;
      state = AsyncValue.data(
        latest.copyWith(
          designs: List<Design>.unmodifiable(merged),
          hasMore: hasMore,
          nextCursor: nextCursor,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      final fallback = state.asData?.value ?? current;
      state = AsyncValue.data(fallback.copyWith(isLoadingMore: false));
      // Swallow pagination errors after resetting state to avoid surfacing
      // uncaught async exceptions when loadMore is triggered via unawaited calls.
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }

  void toggleStatus(DesignStatus status) {
    final notifier = ref.read(libraryListFilterProvider.notifier);
    final next = notifier.state.toggleStatus(status);
    notifier.state = next;
    state = const AsyncValue.loading();
  }

  void clearStatuses() {
    final notifier = ref.read(libraryListFilterProvider.notifier);
    final next = notifier.state.clearStatuses();
    if (next == notifier.state) {
      return;
    }
    notifier.state = next;
    state = const AsyncValue.loading();
  }

  void changeDateRange(LibraryDateRange range) {
    final notifier = ref.read(libraryListFilterProvider.notifier);
    final current = notifier.state;
    if (current.dateRange == range) {
      return;
    }
    notifier.state = current.copyWith(dateRange: range);
    state = const AsyncValue.loading();
  }

  void changeAiScore(LibraryAiScoreFilter filter) {
    final notifier = ref.read(libraryListFilterProvider.notifier);
    final current = notifier.state;
    if (current.aiScore == filter) {
      return;
    }
    notifier.state = current.copyWith(aiScore: filter);
    state = const AsyncValue.loading();
  }

  void changePersona(UserPersona? persona) {
    final notifier = ref.read(libraryListFilterProvider.notifier);
    final current = notifier.state;
    final next = persona == null
        ? current.copyWith(clearPersona: true)
        : current.copyWith(persona: persona);
    if (next == current) {
      return;
    }
    notifier.state = next;
    state = const AsyncValue.loading();
  }

  void changeSort(LibrarySortOption sort) {
    final notifier = ref.read(libraryListSortProvider.notifier);
    if (notifier.state == sort) {
      return;
    }
    notifier.state = sort;
    state = const AsyncValue.loading();
  }

  void setViewMode(LibraryViewMode mode) {
    final notifier = ref.read(libraryListViewModeProvider.notifier);
    if (notifier.state == mode) {
      return;
    }
    notifier.state = mode;
  }

  void updateSearch(String query) {
    final normalized = query.trim();
    final notifier = ref.read(libraryListSearchProvider.notifier);
    if (notifier.state == normalized) {
      return;
    }
    notifier.state = normalized;
    state = const AsyncValue.loading();
  }
}
