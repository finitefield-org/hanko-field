// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/features/kanji_dictionary/data/repositories/kanji_dictionary_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class KanjiDictionaryState {
  const KanjiDictionaryState({
    required this.query,
    required this.results,
    required this.favorites,
    required this.history,
    required this.filter,
    required this.favoritesOnly,
    this.fromCache = false,
    this.cachedAt,
    this.isLoading = false,
    this.message,
  });

  final String query;
  final List<KanjiCandidate> results;
  final Set<String> favorites;
  final List<String> history;
  final KanjiFilter filter;
  final bool favoritesOnly;
  final bool fromCache;
  final DateTime? cachedAt;
  final bool isLoading;
  final String? message;

  KanjiDictionaryState copyWith({
    String? query,
    List<KanjiCandidate>? results,
    Set<String>? favorites,
    List<String>? history,
    KanjiFilter? filter,
    bool? favoritesOnly,
    bool? fromCache,
    DateTime? cachedAt,
    bool? isLoading,
    String? message,
  }) {
    return KanjiDictionaryState(
      query: query ?? this.query,
      results: results ?? this.results,
      favorites: favorites ?? this.favorites,
      history: history ?? this.history,
      filter: filter ?? this.filter,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
      isLoading: isLoading ?? this.isLoading,
      message: message,
    );
  }
}

class KanjiDictionaryViewModel extends AsyncProvider<KanjiDictionaryState> {
  KanjiDictionaryViewModel({this.initialQuery = ''})
    : super.args((initialQuery,), autoDispose: true);

  final String initialQuery;

  late final searchMut = mutation<KanjiSuggestionResult>(#search);
  late final filterMut = mutation<KanjiSuggestionResult>(#filter);
  late final favoritesOnlyMut = mutation<bool>(#favoritesOnly);
  late final favoriteMut = mutation<Set<String>>(#favorite);
  late final clearHistoryMut = mutation<void>(#clearHistory);

  @override
  Future<KanjiDictionaryState> build(Ref ref) async {
    final repository = ref.watch(kanjiDictionaryRepositoryProvider);
    final filter = const KanjiFilter();
    final favorites = await repository.loadFavorites();
    final query = initialQuery.trim();
    var history = await repository.loadHistory();
    if (query.isNotEmpty) {
      final result = await repository.search(query: query, filter: filter);
      history = await repository.pushHistory(query);
      return KanjiDictionaryState(
        query: query,
        results: result.candidates,
        favorites: favorites,
        history: history,
        filter: filter,
        favoritesOnly: false,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      );
    }

    return KanjiDictionaryState(
      query: query,
      results: const <KanjiCandidate>[],
      favorites: favorites,
      history: history,
      filter: filter,
      favoritesOnly: false,
    );
  }

  Call<KanjiSuggestionResult> search(String rawQuery) =>
      mutate(searchMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) {
          throw StateError('Kanji dictionary state not initialized');
        }
        final repository = ref.watch(kanjiDictionaryRepositoryProvider);
        final query = rawQuery.trim();
        ref.state = AsyncData(
          current.copyWith(query: query, isLoading: true, message: null),
        );
        if (query.isEmpty) {
          ref.state = AsyncData(
            current.copyWith(
              query: '',
              results: const <KanjiCandidate>[],
              isLoading: false,
              fromCache: false,
              cachedAt: null,
              message: null,
            ),
          );
          return const KanjiSuggestionResult(candidates: <KanjiCandidate>[]);
        }
        try {
          final result = await repository.search(
            query: query,
            filter: current.filter,
          );
          final history = query.isEmpty
              ? current.history
              : await repository.pushHistory(query);
          ref.state = AsyncData(
            current.copyWith(
              results: result.candidates,
              history: history,
              isLoading: false,
              fromCache: result.fromCache,
              cachedAt: result.cachedAt,
              message: null,
            ),
          );
          return result;
        } catch (e) {
          ref.state = AsyncData(
            current.copyWith(isLoading: false, message: e.toString()),
          );
          rethrow;
        }
      }, concurrency: Concurrency.restart);

  Call<KanjiSuggestionResult> setFilter(KanjiFilter filter) =>
      mutate(filterMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) {
          throw StateError('Kanji dictionary state not initialized');
        }
        final repository = ref.watch(kanjiDictionaryRepositoryProvider);
        ref.state = AsyncData(
          current.copyWith(filter: filter, isLoading: true, message: null),
        );
        if (current.query.trim().isEmpty) {
          ref.state = AsyncData(
            current.copyWith(
              filter: filter,
              results: const <KanjiCandidate>[],
              isLoading: false,
              fromCache: false,
              cachedAt: null,
            ),
          );
          return const KanjiSuggestionResult(candidates: <KanjiCandidate>[]);
        }
        final result = await repository.search(
          query: current.query,
          filter: filter,
        );
        ref.state = AsyncData(
          current.copyWith(
            results: result.candidates,
            isLoading: false,
            fromCache: result.fromCache,
            cachedAt: result.cachedAt,
          ),
        );
        return result;
      }, concurrency: Concurrency.restart);

  Call<bool> toggleFavoritesOnly() => mutate(favoritesOnlyMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;
    final next = !current.favoritesOnly;
    ref.state = AsyncData(current.copyWith(favoritesOnly: next));
    return next;
  }, concurrency: Concurrency.dropLatest);

  Call<Set<String>> toggleFavorite(String candidateId) =>
      mutate(favoriteMut, (ref) async {
        final repository = ref.watch(kanjiDictionaryRepositoryProvider);
        final current = ref.watch(this).valueOrNull;
        final next = await repository.toggleFavorite(candidateId);
        if (current != null) {
          ref.state = AsyncData(current.copyWith(favorites: next));
        }
        return next;
      }, concurrency: Concurrency.dropLatest);

  Call<void> clearHistory() => mutate(clearHistoryMut, (ref) async {
    final repository = ref.watch(kanjiDictionaryRepositoryProvider);
    final current = ref.watch(this).valueOrNull;
    await repository.clearHistory();
    if (current != null) {
      ref.state = AsyncData(current.copyWith(history: const <String>[]));
    }
  }, concurrency: Concurrency.dropLatest);
}
