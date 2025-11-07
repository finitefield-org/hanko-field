import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:flutter/foundation.dart';

@immutable
class KanjiDictionaryState {
  const KanjiDictionaryState({
    this.query = '',
    this.results = const <KanjiCandidate>[],
    this.featuredEntries = const <KanjiCandidate>[],
    this.favoriteEntries = const <KanjiCandidate>[],
    this.recentlyViewed = const <KanjiCandidate>[],
    this.searchHistory = const <String>[],
    this.favoriteIds = const <String>{},
    this.strokeFilters = const <KanjiStrokeBucket>{},
    this.radicalFilters = const <KanjiRadicalCategory>{},
    this.gradeFilters = const <KanjiGradeLevel>{},
    this.isLoading = false,
    this.isAttachingToDesign = false,
    this.showFavoritesOnly = false,
    this.errorMessage,
    this.infoMessage,
    this.lastUpdated,
    this.usedCachedResults = false,
    this.hasDesignDraft = false,
  });

  final String query;
  final List<KanjiCandidate> results;
  final List<KanjiCandidate> featuredEntries;
  final List<KanjiCandidate> favoriteEntries;
  final List<KanjiCandidate> recentlyViewed;
  final List<String> searchHistory;
  final Set<String> favoriteIds;
  final Set<KanjiStrokeBucket> strokeFilters;
  final Set<KanjiRadicalCategory> radicalFilters;
  final Set<KanjiGradeLevel> gradeFilters;
  final bool isLoading;
  final bool isAttachingToDesign;
  final bool showFavoritesOnly;
  final String? errorMessage;
  final String? infoMessage;
  final DateTime? lastUpdated;
  final bool usedCachedResults;
  final bool hasDesignDraft;

  List<KanjiCandidate> get visibleResults =>
      showFavoritesOnly ? favoriteEntries : results;

  bool get hasHistory => searchHistory.isNotEmpty;

  bool get hasRecentlyViewed => recentlyViewed.isNotEmpty;

  KanjiDictionaryState copyWith({
    String? query,
    List<KanjiCandidate>? results,
    List<KanjiCandidate>? featuredEntries,
    List<KanjiCandidate>? favoriteEntries,
    List<KanjiCandidate>? recentlyViewed,
    List<String>? searchHistory,
    Set<String>? favoriteIds,
    Set<KanjiStrokeBucket>? strokeFilters,
    Set<KanjiRadicalCategory>? radicalFilters,
    Set<KanjiGradeLevel>? gradeFilters,
    bool? isLoading,
    bool? isAttachingToDesign,
    bool? showFavoritesOnly,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    DateTime? lastUpdated,
    bool? usedCachedResults,
    bool? hasDesignDraft,
  }) {
    return KanjiDictionaryState(
      query: query ?? this.query,
      results: results ?? this.results,
      featuredEntries: featuredEntries ?? this.featuredEntries,
      favoriteEntries: favoriteEntries ?? this.favoriteEntries,
      recentlyViewed: recentlyViewed ?? this.recentlyViewed,
      searchHistory: searchHistory ?? this.searchHistory,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      strokeFilters: strokeFilters ?? this.strokeFilters,
      radicalFilters: radicalFilters ?? this.radicalFilters,
      gradeFilters: gradeFilters ?? this.gradeFilters,
      isLoading: isLoading ?? this.isLoading,
      isAttachingToDesign: isAttachingToDesign ?? this.isAttachingToDesign,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      usedCachedResults: usedCachedResults ?? this.usedCachedResults,
      hasDesignDraft: hasDesignDraft ?? this.hasDesignDraft,
    );
  }
}
