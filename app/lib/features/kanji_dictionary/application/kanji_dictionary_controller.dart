import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:app/features/kanji_dictionary/application/kanji_dictionary_repository_provider.dart';
import 'package:app/features/kanji_dictionary/application/kanji_dictionary_state.dart';
import 'package:app/features/kanji_dictionary/data/kanji_dictionary_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kanjiDictionaryControllerProvider =
    NotifierProvider<KanjiDictionaryController, KanjiDictionaryState>(
      KanjiDictionaryController.new,
      name: 'kanjiDictionaryControllerProvider',
    );

class KanjiDictionaryController extends Notifier<KanjiDictionaryState> {
  late final KanjiDictionaryRepository _repository;
  bool _bootstrapped = false;
  int _activeSearchToken = 0;

  @override
  KanjiDictionaryState build() {
    _repository = ref.read(kanjiDictionaryRepositoryProvider);
    ref.listen<DesignCreationState>(
      designCreationControllerProvider,
      (_, next) => _syncDesignDraftPresence(next),
    );
    if (!_bootstrapped) {
      _bootstrapped = true;
      Future.microtask(_bootstrap);
    }
    return const KanjiDictionaryState();
  }

  Future<void> _bootstrap() async {
    final favorites = await _repository.loadBookmarks();
    final history = await _repository.loadSearchHistory();
    final viewedIds = await _repository.loadViewedEntries();
    final hasDraft =
        ref.read(designCreationControllerProvider).nameDraft != null;

    state = state.copyWith(
      favoriteIds: favorites,
      favoriteEntries: _repository.candidatesByIds(favorites),
      searchHistory: history,
      recentlyViewed: _repository.candidatesByIds(viewedIds),
      featuredEntries: _repository.featuredCandidates(limit: 6),
      hasDesignDraft: hasDraft,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );

    await search(refresh: true, allowEmptyQuery: true);
  }

  void updateQuery(String value) {
    state = state.copyWith(
      query: value,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
  }

  Future<void> search({
    bool refresh = false,
    bool allowEmptyQuery = false,
  }) async {
    final requestToken = ++_activeSearchToken;
    final normalized = state.query.trim();
    if (normalized.isEmpty && !allowEmptyQuery && !state.showFavoritesOnly) {
      state = state.copyWith(
        errorMessage: 'Enter a keyword to search kanji.',
        results: const [],
        clearInfoMessage: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearInfoMessage: refresh,
    );

    try {
      final result = await _repository.searchCandidates(
        query: normalized,
        strokeFilters: state.strokeFilters,
        radicalFilters: state.radicalFilters,
      );
      if (requestToken != _activeSearchToken) {
        return;
      }
      var filtered = result.response.candidates;
      if (state.gradeFilters.isNotEmpty) {
        filtered = filtered
            .where(
              (candidate) => state.gradeFilters.contains(candidate.gradeLevel),
            )
            .toList(growable: false);
      }
      state = state.copyWith(
        isLoading: false,
        results: filtered,
        lastUpdated: result.response.generatedAt,
        usedCachedResults: result.fromCache,
        infoMessage: result.fromCache
            ? 'Showing cached kanji entries.'
            : state.infoMessage,
        clearErrorMessage: true,
      );
      if (normalized.isNotEmpty) {
        final history = await _repository.upsertSearchHistory(normalized);
        if (requestToken == _activeSearchToken) {
          state = state.copyWith(searchHistory: history);
        }
      }
    } catch (_) {
      if (requestToken != _activeSearchToken) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load the kanji dictionary. Please retry.',
      );
    }
  }

  void applyHistoryQuery(String query) {
    if (query.isEmpty) {
      return;
    }
    updateQuery(query);
    unawaited(search(refresh: true));
  }

  void toggleStrokeFilter(KanjiStrokeBucket bucket) {
    final updated = Set<KanjiStrokeBucket>.from(state.strokeFilters);
    if (!updated.add(bucket)) {
      updated.remove(bucket);
    }
    state = state.copyWith(strokeFilters: updated);
    unawaited(search(refresh: true, allowEmptyQuery: true));
  }

  void toggleRadicalFilter(KanjiRadicalCategory category) {
    final updated = Set<KanjiRadicalCategory>.from(state.radicalFilters);
    if (!updated.add(category)) {
      updated.remove(category);
    }
    state = state.copyWith(radicalFilters: updated);
    unawaited(search(refresh: true, allowEmptyQuery: true));
  }

  void toggleGradeFilter(KanjiGradeLevel level) {
    final updated = Set<KanjiGradeLevel>.from(state.gradeFilters);
    if (!updated.add(level)) {
      updated.remove(level);
    }
    state = state.copyWith(gradeFilters: updated);
    unawaited(search(refresh: true, allowEmptyQuery: true));
  }

  void toggleFavoritesView() {
    state = state.copyWith(showFavoritesOnly: !state.showFavoritesOnly);
  }

  Future<void> toggleBookmark(String candidateId) async {
    final previous = state.favoriteIds;
    final updated = Set<String>.from(state.favoriteIds);
    if (!updated.add(candidateId)) {
      updated.remove(candidateId);
    }
    state = state.copyWith(
      favoriteIds: updated,
      favoriteEntries: _repository.candidatesByIds(updated),
      clearErrorMessage: true,
    );
    try {
      await _repository.saveBookmarks(updated);
    } catch (_) {
      state = state.copyWith(
        favoriteIds: previous,
        favoriteEntries: _repository.candidatesByIds(previous),
        errorMessage: 'Unable to update favorites. Please try again.',
      );
    }
  }

  Future<void> recordViewed(KanjiCandidate candidate) async {
    final updatedIds = await _repository.registerViewedEntry(candidate.id);
    state = state.copyWith(
      recentlyViewed: _repository.candidatesByIds(updatedIds),
    );
  }

  Future<bool> attachToDesign(KanjiCandidate candidate) async {
    final creationState = ref.read(designCreationControllerProvider);
    if (creationState.nameDraft == null) {
      state = state.copyWith(
        infoMessage: 'Start a design draft to insert kanji selections.',
        clearErrorMessage: true,
      );
      return false;
    }
    state = state.copyWith(
      isAttachingToDesign: true,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
    try {
      ref
          .read(designCreationControllerProvider.notifier)
          .updateKanjiMapping(
            DesignKanjiMapping(
              value: candidate.character,
              mappingRef: candidate.id,
            ),
          );
      state = state.copyWith(
        infoMessage:
            'Inserted ${candidate.character}. Return to the input step to confirm.',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Failed to attach kanji to the design draft.',
      );
      return false;
    } finally {
      state = state.copyWith(isAttachingToDesign: false);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearErrorMessage: true, clearInfoMessage: true);
  }

  void _syncDesignDraftPresence(DesignCreationState next) {
    final hasDraft = next.nameDraft != null;
    if (hasDraft == state.hasDesignDraft) {
      return;
    }
    state = state.copyWith(hasDesignDraft: hasDraft);
  }
}
