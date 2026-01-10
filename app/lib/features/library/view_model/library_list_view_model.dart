// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum LibraryLayout { grid, list }

enum LibraryDateFilter { all, last7Days, last30Days, last365Days }

enum LibraryAiFilter { any, score80Plus, score60Plus, score40Plus }

enum LibraryPersonaFilter { all, japanese, foreigner }

extension LibraryDateFilterX on LibraryDateFilter {
  DateTime? start(DateTime now) {
    return switch (this) {
      LibraryDateFilter.all => null,
      LibraryDateFilter.last7Days => now.subtract(const Duration(days: 7)),
      LibraryDateFilter.last30Days => now.subtract(const Duration(days: 30)),
      LibraryDateFilter.last365Days => now.subtract(const Duration(days: 365)),
    };
  }
}

extension LibraryAiFilterX on LibraryAiFilter {
  double? minScore() {
    return switch (this) {
      LibraryAiFilter.any => null,
      LibraryAiFilter.score80Plus => 0.8,
      LibraryAiFilter.score60Plus => 0.6,
      LibraryAiFilter.score40Plus => 0.4,
    };
  }
}

class LibraryListState {
  const LibraryListState({
    required this.items,
    required this.status,
    required this.date,
    required this.ai,
    required this.persona,
    required this.sort,
    required this.layout,
    required this.query,
    required this.nextPageToken,
    required this.isLoadingMore,
    required this.isRefreshing,
  });

  final List<Design> items;
  final DesignStatus? status;
  final LibraryDateFilter date;
  final LibraryAiFilter ai;
  final LibraryPersonaFilter persona;
  final DesignSort sort;
  final LibraryLayout layout;
  final String query;
  final String? nextPageToken;
  final bool isLoadingMore;
  final bool isRefreshing;

  LibraryListState copyWith({
    List<Design>? items,
    DesignStatus? status,
    LibraryDateFilter? date,
    LibraryAiFilter? ai,
    LibraryPersonaFilter? persona,
    DesignSort? sort,
    LibraryLayout? layout,
    String? query,
    String? nextPageToken,
    bool? isLoadingMore,
    bool? isRefreshing,
  }) {
    return LibraryListState(
      items: items ?? this.items,
      status: status ?? this.status,
      date: date ?? this.date,
      ai: ai ?? this.ai,
      persona: persona ?? this.persona,
      sort: sort ?? this.sort,
      layout: layout ?? this.layout,
      query: query ?? this.query,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class LibraryListViewModel extends AsyncProvider<LibraryListState> {
  LibraryListViewModel() : super.args(null, autoDispose: false);

  late final loadMoreMut = mutation<void>(#loadMore);
  late final refreshMut = mutation<void>(#refresh);
  late final setStatusMut = mutation<DesignStatus?>(#setStatus);
  late final setDateMut = mutation<LibraryDateFilter>(#setDate);
  late final setAiMut = mutation<LibraryAiFilter>(#setAi);
  late final setPersonaMut = mutation<LibraryPersonaFilter>(#setPersona);
  late final setSortMut = mutation<DesignSort>(#setSort);
  late final setLayoutMut = mutation<LibraryLayout>(#setLayout);
  late final setQueryMut = mutation<String>(#setQuery);

  @override
  Future<LibraryListState> build(Ref<AsyncValue<LibraryListState>> ref) async {
    final repository = ref.watch(designRepositoryProvider);
    final page = await repository.listDesigns(sort: DesignSort.recent);

    return LibraryListState(
      items: page.items,
      status: null,
      date: LibraryDateFilter.all,
      ai: LibraryAiFilter.any,
      persona: LibraryPersonaFilter.all,
      sort: DesignSort.recent,
      layout: LibraryLayout.grid,
      query: '',
      nextPageToken: page.nextPageToken,
      isLoadingMore: false,
      isRefreshing: false,
    );
  }

  Call<void, AsyncValue<LibraryListState>> loadMore() =>
      mutate(loadMoreMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;
        if (current.isLoadingMore) return;
        final next = current.nextPageToken;
        if (next == null) return;

        ref.state = AsyncData(current.copyWith(isLoadingMore: true));

        try {
          final repository = ref.watch(designRepositoryProvider);
          final cutoff = current.date.start(DateTime.now());
          final page = await repository.listDesigns(
            status: current.status,
            sort: current.sort,
            query: current.query,
            updatedAfter: cutoff,
            minAiScore: current.ai.minScore(),
            pageToken: next,
          );

          final merged = [...current.items, ...page.items];
          ref.state = AsyncData(
            current.copyWith(
              items: _applyPersonaFilter(merged, current.persona),
              nextPageToken: page.nextPageToken,
              isLoadingMore: false,
            ),
          );
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: current.copyWith(isLoadingMore: false),
          );
        }
      }, concurrency: Concurrency.dropLatest);

  Call<void, AsyncValue<LibraryListState>> refresh() =>
      mutate(refreshMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(current.copyWith(isRefreshing: true));
        } else {
          ref.state = const AsyncLoading<LibraryListState>();
        }

        try {
          final repository = ref.watch(designRepositoryProvider);
          final base = current;
          final cutoff = (base?.date ?? LibraryDateFilter.all).start(
            DateTime.now(),
          );
          final page = await repository.listDesigns(
            status: base?.status,
            sort: base?.sort ?? DesignSort.recent,
            query: base?.query,
            updatedAfter: cutoff,
            minAiScore: (base?.ai ?? LibraryAiFilter.any).minScore(),
          );

          final persona = base?.persona ?? LibraryPersonaFilter.all;
          ref.state = AsyncData(
            LibraryListState(
              items: _applyPersonaFilter(page.items, persona),
              status: base?.status,
              date: base?.date ?? LibraryDateFilter.all,
              ai: base?.ai ?? LibraryAiFilter.any,
              persona: persona,
              sort: base?.sort ?? DesignSort.recent,
              layout: base?.layout ?? LibraryLayout.grid,
              query: base?.query ?? '',
              nextPageToken: page.nextPageToken,
              isLoadingMore: false,
              isRefreshing: false,
            ),
          );
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: current?.copyWith(isRefreshing: false),
          );
        }
      }, concurrency: Concurrency.restart);

  Call<DesignStatus?, AsyncValue<LibraryListState>> setStatus(
    DesignStatus? status,
  ) => mutate(setStatusMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(
          status: status,
          isRefreshing: true,
          nextPageToken: null,
          items: const <Design>[],
        ),
      );
    } else {
      ref.state = const AsyncLoading<LibraryListState>();
    }

    await ref.invoke(refresh());
    return status;
  }, concurrency: Concurrency.restart);

  Call<LibraryDateFilter, AsyncValue<LibraryListState>> setDate(
    LibraryDateFilter date,
  ) => mutate(setDateMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(
          date: date,
          isRefreshing: true,
          nextPageToken: null,
          items: const <Design>[],
        ),
      );
    } else {
      ref.state = const AsyncLoading<LibraryListState>();
    }

    await ref.invoke(refresh());
    return date;
  }, concurrency: Concurrency.restart);

  Call<LibraryAiFilter, AsyncValue<LibraryListState>> setAi(
    LibraryAiFilter ai,
  ) => mutate(setAiMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(
          ai: ai,
          isRefreshing: true,
          nextPageToken: null,
          items: const <Design>[],
        ),
      );
    } else {
      ref.state = const AsyncLoading<LibraryListState>();
    }

    await ref.invoke(refresh());
    return ai;
  }, concurrency: Concurrency.restart);

  Call<LibraryPersonaFilter, AsyncValue<LibraryListState>> setPersona(
    LibraryPersonaFilter persona,
  ) => mutate(setPersonaMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return persona;
    ref.state = AsyncData(
      current.copyWith(
        persona: persona,
        items: _applyPersonaFilter(current.items, persona),
      ),
    );
    return persona;
  }, concurrency: Concurrency.dropLatest);

  Call<DesignSort, AsyncValue<LibraryListState>> setSort(DesignSort sort) =>
      mutate(setSortMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              sort: sort,
              isRefreshing: true,
              nextPageToken: null,
              items: const <Design>[],
            ),
          );
        } else {
          ref.state = const AsyncLoading<LibraryListState>();
        }

        await ref.invoke(refresh());
        return sort;
      }, concurrency: Concurrency.restart);

  Call<LibraryLayout, AsyncValue<LibraryListState>> setLayout(
    LibraryLayout layout,
  ) => mutate(setLayoutMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return layout;
    ref.state = AsyncData(current.copyWith(layout: layout));
    return layout;
  }, concurrency: Concurrency.dropLatest);

  Call<String, AsyncValue<LibraryListState>> setQuery(String query) =>
      mutate(setQueryMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              query: query,
              isRefreshing: true,
              nextPageToken: null,
              items: const <Design>[],
            ),
          );
        } else {
          ref.state = const AsyncLoading<LibraryListState>();
        }

        await ref.invoke(refresh());
        return query;
      }, concurrency: Concurrency.restart);

  List<Design> _applyPersonaFilter(
    List<Design> items,
    LibraryPersonaFilter filter,
  ) {
    if (filter == LibraryPersonaFilter.all) return items;
    final wantsKanji = filter == LibraryPersonaFilter.foreigner;
    return items
        .where((design) => wantsKanji == (design.input?.kanji != null))
        .toList();
  }
}

final libraryListViewModel = LibraryListViewModel();
