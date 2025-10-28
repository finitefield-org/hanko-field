import 'package:app/features/search/domain/search_category.dart';

/// Search result representation shared across categories.
class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.badge,
    this.tags = const [],
    this.metadata,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String description;
  final SearchCategory category;
  final String? badge;
  final List<String> tags;
  final String? metadata;
  final String? thumbnailUrl;
}

/// Page container returned by the repository.
class SearchResultPage {
  const SearchResultPage({
    required this.items,
    required this.hasMore,
    required this.totalAvailable,
  });

  final List<SearchResult> items;
  final bool hasMore;
  final int totalAvailable;
}
