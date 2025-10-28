import 'package:app/features/search/application/search_repository_provider.dart';
import 'package:app/features/search/domain/search_category.dart';
import 'package:app/features/search/domain/search_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class CategorySearchState {
  const CategorySearchState({
    required this.category,
    required this.query,
    required this.results,
    required this.page,
    required this.hasMore,
    required this.totalCount,
    this.isLoadingMore = false,
  });

  final SearchCategory category;
  final String query;
  final List<SearchResult> results;
  final int page;
  final bool hasMore;
  final int totalCount;
  final bool isLoadingMore;

  CategorySearchState copyWith({
    List<SearchResult>? results,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    int? totalCount,
    String? query,
  }) {
    return CategorySearchState(
      category: category,
      query: query ?? this.query,
      results: results ?? this.results,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SearchCategoryRequest {
  const SearchCategoryRequest({required this.category, required this.query});

  final SearchCategory category;
  final String query;

  @override
  bool operator ==(Object other) {
    return other is SearchCategoryRequest &&
        other.category == category &&
        other.query == query;
  }

  @override
  int get hashCode => Object.hash(category, query);

  @override
  String toString() => 'SearchCategoryRequest($category, "$query")';
}

class CategorySearchNotifier
    extends StateNotifier<AsyncValue<CategorySearchState>> {
  CategorySearchNotifier(this._ref, this._request)
    : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  final Ref _ref;
  final SearchCategoryRequest _request;

  Future<void> _loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(searchRepositoryProvider);
      final page = await repository.search(
        category: _request.category,
        query: _request.query,
        page: 0,
      );
      state = AsyncValue.data(
        CategorySearchState(
          category: _request.category,
          query: _request.query,
          results: page.items,
          page: 0,
          hasMore: page.hasMore,
          totalCount: page.totalAvailable,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final repository = _ref.read(searchRepositoryProvider);
      final nextPage = current.page + 1;
      final page = await repository.search(
        category: current.category,
        query: current.query,
        page: nextPage,
      );
      final updated = current.copyWith(
        results: [...current.results, ...page.items],
        page: nextPage,
        hasMore: page.hasMore,
        totalCount: page.totalAvailable,
        isLoadingMore: false,
      );
      state = AsyncValue.data(updated);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
