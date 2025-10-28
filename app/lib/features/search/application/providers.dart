import 'package:app/features/search/application/category_search_notifier.dart';
import 'package:app/features/search/application/search_history_notifier.dart';
import 'package:app/features/search/application/search_repository_provider.dart';
import 'package:app/features/search/domain/search_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final searchSelectedCategoryProvider = StateProvider<SearchCategory>(
  (ref) => SearchCategory.templates,
);

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );

final searchSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) async {
      final repository = ref.read(searchRepositoryProvider);
      return repository.suggestions(query);
    });

final categorySearchProvider = StateNotifierProvider.autoDispose
    .family<
      CategorySearchNotifier,
      AsyncValue<CategorySearchState>,
      SearchCategoryRequest
    >(CategorySearchNotifier.new);
