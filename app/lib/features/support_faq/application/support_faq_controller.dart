import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/support_faq/data/support_faq_repository.dart';
import 'package:app/features/support_faq/data/support_faq_repository_provider.dart';
import 'package:app/features/support_faq/domain/support_faq.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportFaqState {
  SupportFaqState({
    required List<FaqCategory> categories,
    required List<FaqEntry> entries,
    required List<FaqEntry> filteredEntries,
    required List<String> suggestions,
    required this.searchTerm,
    this.selectedCategoryId,
    this.lastUpdated,
    this.isRefreshing = false,
    this.fromCache = false,
    Map<String, FaqFeedbackChoice>? feedback,
    Set<String>? pendingFeedbackEntryIds,
  }) : categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries),
       filteredEntries = List.unmodifiable(filteredEntries),
       suggestions = List.unmodifiable(suggestions),
       feedback = Map.unmodifiable(feedback ?? const {}),
       pendingFeedbackEntryIds = Set.unmodifiable(
         pendingFeedbackEntryIds ?? const {},
       );

  final List<FaqCategory> categories;
  final List<FaqEntry> entries;
  final List<FaqEntry> filteredEntries;
  final List<String> suggestions;
  final String searchTerm;
  final String? selectedCategoryId;
  final DateTime? lastUpdated;
  final bool isRefreshing;
  final bool fromCache;
  final Map<String, FaqFeedbackChoice> feedback;
  final Set<String> pendingFeedbackEntryIds;

  bool get hasResults => filteredEntries.isNotEmpty;

  SupportFaqState copyWith({
    List<FaqCategory>? categories,
    List<FaqEntry>? entries,
    List<FaqEntry>? filteredEntries,
    List<String>? suggestions,
    String? searchTerm,
    Object? selectedCategoryId = _sentinel,
    DateTime? lastUpdated,
    bool? isRefreshing,
    bool? fromCache,
    Map<String, FaqFeedbackChoice>? feedback,
    Set<String>? pendingFeedbackEntryIds,
  }) {
    return SupportFaqState(
      categories: categories ?? this.categories,
      entries: entries ?? this.entries,
      filteredEntries: filteredEntries ?? this.filteredEntries,
      suggestions: suggestions ?? this.suggestions,
      searchTerm: searchTerm ?? this.searchTerm,
      selectedCategoryId: identical(selectedCategoryId, _sentinel)
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
      feedback: feedback ?? this.feedback,
      pendingFeedbackEntryIds:
          pendingFeedbackEntryIds ?? this.pendingFeedbackEntryIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SupportFaqState &&
            listEquals(other.categories, categories) &&
            listEquals(other.entries, entries) &&
            listEquals(other.filteredEntries, filteredEntries) &&
            listEquals(other.suggestions, suggestions) &&
            mapEquals(other.feedback, feedback) &&
            setEquals(other.pendingFeedbackEntryIds, pendingFeedbackEntryIds) &&
            other.searchTerm == searchTerm &&
            other.selectedCategoryId == selectedCategoryId &&
            other.lastUpdated == lastUpdated &&
            other.isRefreshing == isRefreshing &&
            other.fromCache == fromCache);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      Object.hashAll(categories),
      Object.hashAll(entries),
      Object.hashAll(filteredEntries),
      Object.hashAll(suggestions),
      searchTerm,
      selectedCategoryId,
      lastUpdated,
      isRefreshing,
      fromCache,
      Object.hashAll(feedback.entries),
      Object.hashAll(pendingFeedbackEntryIds),
    ]);
  }
}

class SupportFaqController extends AsyncNotifier<SupportFaqState> {
  SupportFaqRepository get _repository =>
      ref.read(supportFaqRepositoryProvider);
  ExperienceGate? _lastExperience;
  String? _lastLocaleTag;

  @override
  FutureOr<SupportFaqState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    _lastExperience = experience;
    _lastLocaleTag = experience.locale.toLanguageTag();
    return _loadState(experience, reuseFilters: false);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    final ExperienceGate experience =
        _lastExperience ?? await ref.read(experienceGateProvider.future);
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    try {
      final nextState = await _loadState(experience, reuseFilters: true);
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(nextState);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      if (current != null) {
        state = AsyncData(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void updateSearch(String value) {
    final current = state.asData?.value;
    if (current == null || current.searchTerm == value) {
      return;
    }
    final filtered = _applyFilters(
      entries: current.entries,
      searchTerm: value,
      categoryId: current.selectedCategoryId,
    );
    state = AsyncData(
      current.copyWith(searchTerm: value, filteredEntries: filtered),
    );
  }

  void clearSearch() {
    updateSearch('');
  }

  void selectCategory(String? categoryId) {
    final current = state.asData?.value;
    if (current == null || current.selectedCategoryId == categoryId) {
      return;
    }
    final filtered = _applyFilters(
      entries: current.entries,
      searchTerm: current.searchTerm,
      categoryId: categoryId,
    );
    state = AsyncData(
      current.copyWith(
        selectedCategoryId: categoryId,
        filteredEntries: filtered,
      ),
    );
  }

  void applySuggestion(String suggestion) {
    updateSearch(suggestion);
  }

  Future<void> sendFeedback(String entryId, FaqFeedbackChoice choice) async {
    final previous = state.asData?.value ?? await future;
    if (previous.pendingFeedbackEntryIds.contains(entryId)) {
      return;
    }
    final pending = {...previous.pendingFeedbackEntryIds}..add(entryId);
    state = AsyncData(previous.copyWith(pendingFeedbackEntryIds: pending));
    try {
      final locale = await _ensureLocaleTag();
      final updatedEntry = await _repository.submitFeedback(
        FaqFeedbackRequest(entryId: entryId, localeTag: locale, choice: choice),
      );
      if (!ref.mounted) {
        return;
      }
      final latest = state.asData?.value ?? previous;
      final updatedEntries = [
        for (final entry in latest.entries)
          if (entry.id == entryId) updatedEntry else entry,
      ];
      final filtered = _applyFilters(
        entries: updatedEntries,
        searchTerm: latest.searchTerm,
        categoryId: latest.selectedCategoryId,
      );
      final updatedFeedback = Map<String, FaqFeedbackChoice>.from(
        latest.feedback,
      )..[entryId] = choice;
      final pendingNext = {...latest.pendingFeedbackEntryIds}..remove(entryId);
      state = AsyncData(
        latest.copyWith(
          entries: updatedEntries,
          filteredEntries: filtered,
          feedback: updatedFeedback,
          pendingFeedbackEntryIds: pendingNext,
        ),
      );
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final latest = state.asData?.value ?? previous;
        final pendingNext = {...latest.pendingFeedbackEntryIds}
          ..remove(entryId);
        state = AsyncData(
          latest.copyWith(pendingFeedbackEntryIds: pendingNext),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<SupportFaqState> _loadState(
    ExperienceGate experience, {
    required bool reuseFilters,
  }) async {
    final request = FaqContentRequest(
      localeTag: experience.locale.toLanguageTag(),
      persona: experience.persona,
    );
    final result = await _repository.fetchFaqs(request);
    final previous = reuseFilters ? state.asData?.value : null;
    final searchTerm = previous?.searchTerm ?? '';
    final selectedCategoryId = previous?.selectedCategoryId;
    final filtered = _applyFilters(
      entries: result.entries,
      searchTerm: searchTerm,
      categoryId: selectedCategoryId,
    );
    return SupportFaqState(
      categories: result.categories,
      entries: result.entries,
      filteredEntries: filtered,
      suggestions: result.suggestions,
      searchTerm: searchTerm,
      selectedCategoryId: selectedCategoryId,
      lastUpdated: result.fetchedAt,
      fromCache: result.fromCache,
      isRefreshing: false,
      feedback: previous?.feedback,
      pendingFeedbackEntryIds: previous?.pendingFeedbackEntryIds,
    );
  }

  List<FaqEntry> _applyFilters({
    required List<FaqEntry> entries,
    required String searchTerm,
    required String? categoryId,
  }) {
    final query = searchTerm.trim().toLowerCase();
    return [
      for (final entry in entries)
        if ((categoryId == null || entry.categoryId == categoryId) &&
            (query.isEmpty || _matches(entry, query)))
          entry,
    ];
  }

  bool _matches(FaqEntry entry, String query) {
    final buffer = StringBuffer()
      ..write(entry.question.toLowerCase())
      ..write(' ')
      ..write(entry.answer.toLowerCase());
    for (final tag in entry.tags) {
      buffer
        ..write(' ')
        ..write(tag.toLowerCase());
    }
    return buffer.toString().contains(query);
  }

  Future<String> _ensureLocaleTag() async {
    final cached = _lastLocaleTag;
    if (cached != null) {
      return cached;
    }
    final experience = await ref.read(experienceGateProvider.future);
    _lastExperience = experience;
    final locale = experience.locale.toLanguageTag();
    _lastLocaleTag = locale;
    return locale;
  }
}

final supportFaqControllerProvider =
    AsyncNotifierProvider<SupportFaqController, SupportFaqState>(
      SupportFaqController.new,
    );

const _sentinel = Object();
