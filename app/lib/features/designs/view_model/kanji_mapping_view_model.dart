// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/models/kanji_mapping_models.dart';
import 'package:app/features/designs/data/repositories/kanji_mapping_repository.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

class KanjiMapState {
  const KanjiMapState({
    required this.query,
    required this.candidates,
    required this.selectedId,
    required this.compareIds,
    required this.bookmarks,
    required this.filter,
    this.manualEntry = '',
    this.message,
    this.isLoading = false,
    this.fromCache = false,
    this.cachedAt,
  });

  final String query;
  final List<KanjiCandidate> candidates;
  final String? selectedId;
  final Set<String> compareIds;
  final Set<String> bookmarks;
  final KanjiFilter filter;
  final String manualEntry;
  final String? message;
  final bool isLoading;
  final bool fromCache;
  final DateTime? cachedAt;

  KanjiMapState copyWith({
    String? query,
    List<KanjiCandidate>? candidates,
    String? selectedId,
    Set<String>? compareIds,
    Set<String>? bookmarks,
    KanjiFilter? filter,
    String? manualEntry,
    String? message,
    bool? isLoading,
    bool? fromCache,
    DateTime? cachedAt,
  }) {
    return KanjiMapState(
      query: query ?? this.query,
      candidates: candidates ?? this.candidates,
      selectedId: selectedId ?? this.selectedId,
      compareIds: compareIds ?? this.compareIds,
      bookmarks: bookmarks ?? this.bookmarks,
      filter: filter ?? this.filter,
      manualEntry: manualEntry ?? this.manualEntry,
      message: message,
      isLoading: isLoading ?? this.isLoading,
      fromCache: fromCache ?? this.fromCache,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

class KanjiMappingViewModel extends AsyncProvider<KanjiMapState> {
  KanjiMappingViewModel() : super.args(null, autoDispose: true);

  late final searchMut = mutation<KanjiSuggestionResult>(#search);
  late final selectMut = mutation<String?>(#select);
  late final toggleCompareMut = mutation<Set<String>>(#toggleCompare);
  late final bookmarkMut = mutation<Set<String>>(#bookmark);
  late final manualMut = mutation<String>(#manual);
  late final applyMut = mutation<KanjiMapping>(#apply);
  late final filterMut = mutation<KanjiSuggestionResult>(#filter);

  @override
  Future<KanjiMapState> build(Ref<AsyncValue<KanjiMapState>> ref) async {
    final repository = ref.watch(kanjiMappingRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final design = ref.watch(designCreationViewModel).valueOrNull;
    final draft = design?.nameDraft ?? const NameInputDraft();
    final query = _deriveQuery(draft, gates);
    final filter = const KanjiFilter();
    final bookmarks = await repository.loadBookmarks();
    final result = await repository.fetchCandidates(
      query: query,
      filter: filter,
    );
    final selection = _reconcileSelection(
      draft.kanjiMapping?.mappingRef,
      draft.kanjiMapping?.mappingRef != null
          ? {draft.kanjiMapping!.mappingRef!}
          : <String>{},
      result.candidates,
    );

    return KanjiMapState(
      query: query,
      candidates: result.candidates,
      selectedId: selection.selectedId,
      compareIds: selection.compareIds,
      bookmarks: bookmarks,
      filter: filter,
      manualEntry: draft.kanjiMapping?.value ?? '',
      fromCache: result.fromCache,
      cachedAt: result.cachedAt,
    );
  }

  Call<KanjiSuggestionResult, AsyncValue<KanjiMapState>> search(
    String rawQuery,
  ) => mutate(searchMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) {
      throw StateError('Kanji map state not initialized');
    }
    final repository = ref.watch(kanjiMappingRepositoryProvider);
    final query = rawQuery.trim().isEmpty ? current.query : rawQuery.trim();

    ref.state = AsyncData(
      current.copyWith(query: query, isLoading: true, message: null),
    );

    try {
      final result = await repository.fetchCandidates(
        query: query,
        filter: current.filter,
      );
      final selectedId =
          current.selectedId ?? result.candidates.firstOrNull?.id;
      final selection = _reconcileSelection(
        selectedId,
        current.compareIds,
        result.candidates,
      );

      ref.state = AsyncData(
        current.copyWith(
          candidates: result.candidates,
          selectedId: selection.selectedId,
          compareIds: selection.compareIds,
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

  Call<KanjiSuggestionResult, AsyncValue<KanjiMapState>> setFilter(
    KanjiFilter filter,
  ) => mutate(filterMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) {
      throw StateError('Kanji map state not initialized');
    }
    final repository = ref.watch(kanjiMappingRepositoryProvider);
    ref.state = AsyncData(
      current.copyWith(filter: filter, isLoading: true, message: null),
    );
    final result = await repository.fetchCandidates(
      query: current.query,
      filter: filter,
    );
    final selection = _reconcileSelection(
      current.selectedId,
      current.compareIds,
      result.candidates,
    );
    ref.state = AsyncData(
      current.copyWith(
        candidates: result.candidates,
        selectedId: selection.selectedId,
        compareIds: selection.compareIds,
        isLoading: false,
        fromCache: result.fromCache,
        cachedAt: result.cachedAt,
      ),
    );
    return result;
  }, concurrency: Concurrency.restart);

  Call<String?, AsyncValue<KanjiMapState>> selectCandidate(
    String? candidateId,
  ) => mutate(selectMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return candidateId;
    if (candidateId == null) {
      ref.state = AsyncData(current.copyWith(selectedId: null));
      return null;
    }
    final compare = Set<String>.from(current.compareIds)..add(candidateId);
    ref.state = AsyncData(
      current.copyWith(selectedId: candidateId, compareIds: compare),
    );
    return candidateId;
  }, concurrency: Concurrency.dropLatest);

  Call<Set<String>, AsyncValue<KanjiMapState>> toggleCompare(
    String candidateId,
  ) => mutate(toggleCompareMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return <String>{};
    final next = Set<String>.from(current.compareIds);
    if (next.contains(candidateId)) {
      next.remove(candidateId);
    } else {
      next.add(candidateId);
    }
    ref.state = AsyncData(current.copyWith(compareIds: next));
    return next;
  }, concurrency: Concurrency.dropLatest);

  Call<Set<String>, AsyncValue<KanjiMapState>> toggleBookmark(
    String candidateId,
  ) => mutate(bookmarkMut, (ref) async {
    final repository = ref.watch(kanjiMappingRepositoryProvider);
    final current = ref.watch(this).valueOrNull;
    final next = await repository.toggleBookmark(candidateId);
    if (current != null) {
      ref.state = AsyncData(current.copyWith(bookmarks: next));
    }
    return next;
  }, concurrency: Concurrency.dropLatest);

  Call<String, AsyncValue<KanjiMapState>> updateManualEntry(String value) =>
      mutate(manualMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return value;
        ref.state = AsyncData(current.copyWith(manualEntry: value));
        return value;
      }, concurrency: Concurrency.dropLatest);

  Call<KanjiMapping, AsyncValue<KanjiMapState>> applySelection({
    String? manualValue,
  }) => mutate(applyMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) {
      throw StateError('Kanji map state not initialized');
    }

    final manual = manualValue?.trim();
    final isManual = manual?.isNotEmpty == true;
    final candidate = isManual
        ? null
        : current.candidates.firstWhereOrNull(
            (c) => c.id == current.selectedId,
          );
    final value = isManual ? manual! : (candidate?.glyph ?? '');
    if (value.isEmpty && !isManual) {
      throw StateError('No kanji selection to apply');
    }

    final mapping = KanjiMapping(
      value: value,
      mappingRef: isManual ? 'manual' : candidate?.id,
    );

    await ref.invoke(designCreationViewModel.setKanjiMapping(mapping));

    final analytics = ref.watch(analyticsClientProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    unawaited(
      analytics.track(
        KanjiMappingSelectedEvent(
          candidateId: isManual ? 'manual' : (candidate?.id ?? 'manual'),
          glyph: value,
          query: current.query,
          persona: gates.personaKey,
          locale: gates.localeTag,
          bookmarked:
              candidate != null && current.bookmarks.contains(candidate.id),
          fromCache: current.fromCache,
        ),
      ),
    );

    ref.state = AsyncData(
      current.copyWith(
        selectedId: isManual ? current.selectedId : (candidate?.id),
        manualEntry: manual ?? current.manualEntry,
      ),
    );
    return mapping;
  }, concurrency: Concurrency.dropLatest);
}

final kanjiMappingViewModel = KanjiMappingViewModel();

String _deriveQuery(NameInputDraft draft, AppExperienceGates gates) {
  final name = draft.fullName(prefersEnglish: gates.prefersEnglish);
  if (name.isNotEmpty) return name;
  if (gates.prefersEnglish) return 'international name';
  return '外国人';
}

class _SelectionState {
  const _SelectionState({required this.selectedId, required this.compareIds});

  final String? selectedId;
  final Set<String> compareIds;
}

_SelectionState _reconcileSelection(
  String? selectedId,
  Set<String> compareIds,
  List<KanjiCandidate> candidates,
) {
  final candidateIds = candidates.map((c) => c.id).toSet();
  final nextSelected = selectedId != null && candidateIds.contains(selectedId)
      ? selectedId
      : candidates.firstOrNull?.id;
  final nextCompare = compareIds.where(candidateIds.contains).toSet();
  if (nextSelected != null) {
    nextCompare.add(nextSelected);
  }
  return _SelectionState(selectedId: nextSelected, compareIds: nextCompare);
}
