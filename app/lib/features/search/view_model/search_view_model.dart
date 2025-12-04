// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/search/data/search_index.dart';
import 'package:app/features/search/data/search_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SearchUiState {
  const SearchUiState({
    required this.query,
    required this.activeQuery,
    required this.history,
    required this.selectedSegment,
  });

  final String query;
  final String activeQuery;
  final List<String> history;
  final SearchSegment selectedSegment;

  bool get hasActiveQuery => activeQuery.isNotEmpty;

  SearchUiState copyWith({
    String? query,
    String? activeQuery,
    List<String>? history,
    SearchSegment? selectedSegment,
  }) {
    return SearchUiState(
      query: query ?? this.query,
      activeQuery: activeQuery ?? this.activeQuery,
      history: history ?? this.history,
      selectedSegment: selectedSegment ?? this.selectedSegment,
    );
  }
}

final searchIndexProvider = Provider<SearchIndex>((ref) {
  final gates = ref.watch(appExperienceGatesProvider);
  return SearchIndex(gates: gates);
});

class SearchViewModel extends AsyncProvider<SearchUiState> {
  SearchViewModel() : super.args(null, autoDispose: true);

  late final updateQueryMut = mutation<String>(#updateQuery);
  late final submitMut = mutation<String>(#submit);
  late final selectSegmentMut = mutation<SearchSegment>(#selectSegment);
  late final clearHistoryMut = mutation<String?>(#clearHistory);

  @override
  Future<SearchUiState> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    return SearchUiState(
      query: '',
      activeQuery: '',
      history: index.seedHistory(),
      selectedSegment: SearchSegment.templates,
    );
  }

  Call<String> updateQuery(String query) => mutate(updateQueryMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return query;
    ref.state = AsyncData(current.copyWith(query: query));
    return query;
  }, concurrency: Concurrency.dropLatest);

  Call<String> submit(String rawQuery) => mutate(submitMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final query = rawQuery.trim();
    if (current == null) return query;

    final history = <String>[
      if (query.isNotEmpty) query,
      ...current.history.where((item) => item != query),
    ].take(8).toList();

    ref.state = AsyncData(
      current.copyWith(query: query, activeQuery: query, history: history),
    );
    return query;
  }, concurrency: Concurrency.restart);

  Call<SearchSegment> selectSegment(SearchSegment segment) =>
      mutate(selectSegmentMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return segment;
        ref.state = AsyncData(current.copyWith(selectedSegment: segment));
        return segment;
      }, concurrency: Concurrency.dropLatest);

  Call<void> clearHistory([String? entry]) =>
      mutate(clearHistoryMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;
        final cleared = entry == null
            ? <String>[]
            : current.history.where((item) => item != entry).toList();
        ref.state = AsyncData(current.copyWith(history: cleared));
      }, concurrency: Concurrency.dropLatest);
}

final searchViewModel = SearchViewModel();

class SearchSuggestionsProvider extends AsyncProvider<List<SearchSuggestion>> {
  SearchSuggestionsProvider({required this.query})
    : super.args((query,), autoDispose: true);

  final String query;

  @override
  Future<List<SearchSuggestion>> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return index.suggestionsFor(query);
  }
}

class TemplateResultsProvider extends AsyncProvider<Page<TemplateSearchHit>> {
  TemplateResultsProvider({required this.query, this.pageToken})
    : super.args((query, pageToken), autoDispose: true);

  final String query;
  final String? pageToken;

  @override
  Future<Page<TemplateSearchHit>> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return index.searchTemplates(query, pageToken: pageToken);
  }
}

class MaterialResultsProvider extends AsyncProvider<Page<MaterialSearchHit>> {
  MaterialResultsProvider({required this.query, this.pageToken})
    : super.args((query, pageToken), autoDispose: true);

  final String query;
  final String? pageToken;

  @override
  Future<Page<MaterialSearchHit>> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return index.searchMaterials(query, pageToken: pageToken);
  }
}

class ArticleResultsProvider extends AsyncProvider<Page<ArticleSearchHit>> {
  ArticleResultsProvider({required this.query, this.pageToken})
    : super.args((query, pageToken), autoDispose: true);

  final String query;
  final String? pageToken;

  @override
  Future<Page<ArticleSearchHit>> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return index.searchArticles(query, pageToken: pageToken);
  }
}

class FaqResultsProvider extends AsyncProvider<Page<FaqSearchHit>> {
  FaqResultsProvider({required this.query, this.pageToken})
    : super.args((query, pageToken), autoDispose: true);

  final String query;
  final String? pageToken;

  @override
  Future<Page<FaqSearchHit>> build(Ref ref) async {
    final index = ref.watch(searchIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return index.searchFaq(query, pageToken: pageToken);
  }
}
