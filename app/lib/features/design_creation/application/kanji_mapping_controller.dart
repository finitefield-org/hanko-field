import 'dart:async';

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/kanji_mapping_repository_provider.dart';
import 'package:app/features/design_creation/application/kanji_mapping_state.dart';
import 'package:app/features/design_creation/data/kanji_mapping_repository.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final kanjiMappingControllerProvider =
    NotifierProvider<KanjiMappingController, KanjiMappingState>(
      KanjiMappingController.new,
      name: 'kanjiMappingControllerProvider',
    );

class KanjiMappingController extends Notifier<KanjiMappingState> {
  late final KanjiMappingRepository _repository;
  DesignNameDraft? _draft;

  @override
  KanjiMappingState build() {
    _repository = ref.read(kanjiMappingRepositoryProvider);
    _draft = ref.read(designCreationControllerProvider).nameDraft;
    Future.microtask(_bootstrap);
    return const KanjiMappingState();
  }

  Future<void> _bootstrap() async {
    final draft = _draft;
    final initialQuery = _deriveInitialQuery(draft);
    var nextState = state.copyWith(
      query: initialQuery,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
    final initialMapping = draft?.kanjiMapping;
    if (initialMapping != null) {
      if (initialMapping.mappingRef != null) {
        nextState = nextState.copyWith(
          selectedCandidateId: initialMapping.mappingRef,
          clearManualSelection: true,
        );
      } else {
        nextState = nextState.copyWith(
          manualKanji: initialMapping.value,
          manualMeaning: '',
          clearSelectedCandidate: true,
        );
      }
    }
    state = nextState;

    final bookmarks = await _repository.loadBookmarks();
    state = state.copyWith(bookmarks: bookmarks);

    await search(refresh: true, allowEmptyQuery: true);

    final mappingRef = initialMapping?.mappingRef;
    if (mappingRef != null && state.selectedCandidateId == mappingRef) {
      // Already set before; ensure candidate exists after fetch.
      final exists = state.results.any(
        (candidate) => candidate.id == mappingRef,
      );
      if (!exists) {
        state = state.copyWith(clearSelectedCandidate: true);
      }
    }
  }

  Future<void> search({
    bool refresh = false,
    bool allowEmptyQuery = false,
  }) async {
    final currentQuery = state.query.trim();
    if (!allowEmptyQuery && currentQuery.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter a name or meaning to search.',
        clearInfoMessage: true,
        results: const [],
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearInfoMessage: refresh,
    );

    try {
      final result = await _repository.fetchCandidates(
        query: currentQuery,
        strokeFilters: state.strokeFilters,
        radicalFilters: state.radicalFilters,
      );
      state = state.copyWith(
        isLoading: false,
        results: result.response.candidates,
        lastUpdated: result.response.generatedAt,
        usedCachedResults: result.fromCache,
        infoMessage: result.fromCache ? 'Showing cached suggestions.' : null,
        clearErrorMessage: true,
      );
      if (state.selectedCandidateId != null) {
        final stillExists = state.results.any(
          (candidate) => candidate.id == state.selectedCandidateId,
        );
        if (!stillExists) {
          state = state.copyWith(clearSelectedCandidate: true);
        }
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load suggestions. Please try again.',
      );
    }
  }

  void updateQuery(String value) {
    state = state.copyWith(
      query: value,
      clearErrorMessage: true,
      clearInfoMessage: true,
    );
  }

  void toggleStrokeFilter(KanjiStrokeBucket bucket) {
    final current = Set<KanjiStrokeBucket>.from(state.strokeFilters);
    if (current.contains(bucket)) {
      current.remove(bucket);
    } else {
      current.add(bucket);
    }
    state = state.copyWith(strokeFilters: current);
    unawaited(search(refresh: true, allowEmptyQuery: true));
  }

  void toggleRadicalFilter(KanjiRadicalCategory category) {
    final current = Set<KanjiRadicalCategory>.from(state.radicalFilters);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    state = state.copyWith(radicalFilters: current);
    unawaited(search(refresh: true, allowEmptyQuery: true));
  }

  void toggleCompare(String candidateId) {
    final current = Set<String>.from(state.compareSelection);
    if (current.contains(candidateId)) {
      current.remove(candidateId);
    } else {
      if (current.length >= 3) {
        current.remove(current.first);
      }
      current.add(candidateId);
    }
    state = state.copyWith(compareSelection: current);
  }

  Future<void> toggleBookmark(String candidateId) async {
    final current = Set<String>.from(state.bookmarks);
    if (current.contains(candidateId)) {
      current.remove(candidateId);
    } else {
      current.add(candidateId);
    }
    state = state.copyWith(bookmarks: current);
    try {
      await _repository.saveBookmarks(current);
    } catch (_) {
      // Ignore cache persistence errors.
    }
  }

  void selectCandidate(String candidateId) {
    state = state.copyWith(
      selectedCandidateId: candidateId,
      clearManualSelection: true,
      clearErrorMessage: true,
    );
  }

  void updateManualKanji(String value) {
    state = state.copyWith(
      manualKanji: value,
      clearSelectedCandidate: true,
      clearErrorMessage: true,
    );
  }

  void updateManualMeaning(String value) {
    state = state.copyWith(manualMeaning: value, clearErrorMessage: true);
  }

  void clearTransientMessages() {
    state = state.copyWith(clearErrorMessage: true, clearInfoMessage: true);
  }

  Future<bool> confirmSelection() async {
    if (!state.hasSelection) {
      state = state.copyWith(
        errorMessage: 'Select a candidate or provide a custom kanji.',
      );
      return false;
    }
    state = state.copyWith(isSaving: true, clearErrorMessage: true);

    try {
      DesignKanjiMapping? mapping;
      KanjiCandidate? candidate;
      if (state.selectedCandidateId != null) {
        candidate = state.candidateById(state.selectedCandidateId!);
        if (candidate == null) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: 'The selected candidate is no longer available.',
          );
          return false;
        }
        mapping = DesignKanjiMapping(
          value: candidate.character,
          mappingRef: candidate.id,
        );
      } else {
        final value = state.manualKanji.trim();
        if (value.isEmpty) {
          state = state.copyWith(
            isSaving: false,
            errorMessage: 'Enter kanji characters for manual selection.',
          );
          return false;
        }
        mapping = DesignKanjiMapping(value: value);
      }

      ref
          .read(designCreationControllerProvider.notifier)
          .updateKanjiMapping(mapping);

      final analytics = ref.read(analyticsControllerProvider.notifier);
      await analytics.logEvent(
        KanjiMappingSelectedEvent(
          method: state.selectedCandidateId != null ? 'suggested' : 'manual',
          candidateId: state.selectedCandidateId,
          query: state.query.trim(),
          strokeFilters: state.strokeFilters.map(
            (filter) => filter.analyticsId,
          ),
          radicalFilters: state.radicalFilters
              .map((filter) => filter.analyticsId)
              .toList(growable: false),
          bookmarkCount: state.bookmarks.length,
        ),
      );

      ref.read(appStateProvider.notifier).pop();
      return true;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  String _deriveInitialQuery(DesignNameDraft? draft) {
    if (draft == null) {
      return '';
    }
    final given = draft.givenName.trim();
    if (given.isNotEmpty) {
      return given;
    }
    final surname = draft.surname.trim();
    if (surname.isNotEmpty) {
      return surname;
    }
    return draft.combined;
  }
}
