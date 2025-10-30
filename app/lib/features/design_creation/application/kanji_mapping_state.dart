import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:flutter/foundation.dart';

@immutable
class KanjiMappingState {
  const KanjiMappingState({
    this.query = '',
    this.results = const <KanjiCandidate>[],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.infoMessage,
    this.strokeFilters = const <KanjiStrokeBucket>{},
    this.radicalFilters = const <KanjiRadicalCategory>{},
    this.compareSelection = const <String>{},
    this.bookmarks = const <String>{},
    this.selectedCandidateId,
    this.manualKanji = '',
    this.manualMeaning = '',
    this.lastUpdated,
    this.usedCachedResults = false,
  });

  final String query;
  final List<KanjiCandidate> results;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? infoMessage;
  final Set<KanjiStrokeBucket> strokeFilters;
  final Set<KanjiRadicalCategory> radicalFilters;
  final Set<String> compareSelection;
  final Set<String> bookmarks;
  final String? selectedCandidateId;
  final String manualKanji;
  final String manualMeaning;
  final DateTime? lastUpdated;
  final bool usedCachedResults;

  bool get hasSelection =>
      selectedCandidateId != null || manualKanji.trim().isNotEmpty;

  bool get hasManualSelection => manualKanji.trim().isNotEmpty;

  KanjiCandidate? get selectedCandidate {
    if (selectedCandidateId == null) {
      return null;
    }
    for (final candidate in results) {
      if (candidate.id == selectedCandidateId) {
        return candidate;
      }
    }
    return null;
  }

  List<KanjiCandidate> get compareCandidates {
    if (compareSelection.isEmpty) {
      return const [];
    }
    return results
        .where((candidate) => compareSelection.contains(candidate.id))
        .toList(growable: false);
  }

  KanjiMappingState copyWith({
    String? query,
    List<KanjiCandidate>? results,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    Set<KanjiStrokeBucket>? strokeFilters,
    Set<KanjiRadicalCategory>? radicalFilters,
    Set<String>? compareSelection,
    Set<String>? bookmarks,
    String? selectedCandidateId,
    bool clearSelectedCandidate = false,
    String? manualKanji,
    String? manualMeaning,
    bool clearManualSelection = false,
    DateTime? lastUpdated,
    bool? usedCachedResults,
  }) {
    return KanjiMappingState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      strokeFilters: strokeFilters ?? this.strokeFilters,
      radicalFilters: radicalFilters ?? this.radicalFilters,
      compareSelection: compareSelection ?? this.compareSelection,
      bookmarks: bookmarks ?? this.bookmarks,
      selectedCandidateId: clearSelectedCandidate
          ? null
          : selectedCandidateId ?? this.selectedCandidateId,
      manualKanji: clearManualSelection ? '' : manualKanji ?? this.manualKanji,
      manualMeaning: clearManualSelection
          ? ''
          : manualMeaning ?? this.manualMeaning,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      usedCachedResults: usedCachedResults ?? this.usedCachedResults,
    );
  }

  KanjiCandidate? candidateById(String id) {
    for (final candidate in results) {
      if (candidate.id == id) {
        return candidate;
      }
    }
    return null;
  }
}
