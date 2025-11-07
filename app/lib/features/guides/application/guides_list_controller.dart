import 'dart:async';
import 'dart:ui';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/guides/data/guides_repository.dart';
import 'package:app/features/guides/data/guides_repository_provider.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:app/features/guides/domain/guide_list_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guidesListControllerProvider =
    AsyncNotifierProvider<GuidesListController, GuideListState>(
      GuidesListController.new,
    );

class GuidesListController extends AsyncNotifier<GuideListState> {
  static const List<Locale> _kSupportedGuideLocales = [
    Locale('ja', 'JP'),
    Locale('en', 'US'),
  ];

  GuidesRepository get _repository => ref.read(guidesRepositoryProvider);

  @override
  FutureOr<GuideListState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    final resolvedLocale = _resolveLocale(experience.locale);
    final request = GuideListRequest(
      localeTag: resolvedLocale.toLanguageTag(),
      persona: experience.persona,
    );
    final result = await _repository.fetchGuides(request);
    return _stateFromResult(
      result: result,
      locale: resolvedLocale,
      persona: experience.persona,
      topic: null,
      searchQuery: '',
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current != null) {
      await _reloadWith(
        locale: current.filter.locale,
        persona: current.filter.persona,
        topicOverride: current.filter.topic,
        searchOverride: current.searchQuery,
      );
      return;
    }
    final experience = await ref.read(experienceGateProvider.future);
    final locale = _resolveLocale(experience.locale);
    await _reloadWith(
      locale: locale,
      persona: experience.persona,
      topicOverride: null,
      searchOverride: '',
    );
  }

  Future<void> selectPersona(UserPersona persona) async {
    final current = state.asData?.value;
    if (current != null && current.filter.persona == persona) {
      return;
    }
    await _reloadWith(
      locale: current?.filter.locale ?? _kSupportedGuideLocales.first,
      persona: persona,
      topicOverride: current?.filter.topic,
      searchOverride: current?.searchQuery ?? '',
    );
  }

  Future<void> selectLocale(Locale locale) async {
    final resolved = _resolveLocale(locale);
    final current = state.asData?.value;
    if (current != null && current.filter.locale == resolved) {
      return;
    }
    await _reloadWith(
      locale: resolved,
      persona: current?.filter.persona ?? UserPersona.japanese,
      topicOverride: current?.filter.topic,
      searchOverride: current?.searchQuery ?? '',
    );
  }

  void selectTopic(GuideCategory? topic) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    if (current.filter.topic == topic) {
      return;
    }
    final nextFilter = current.filter.copyWith(topic: topic);
    final filtered = _filterEntries(
      current.allGuides,
      topic: topic,
      searchQuery: current.searchQuery,
    );
    final recommended = _filterEntries(
      current.recommendedSource,
      topic: topic,
      searchQuery: current.searchQuery,
    );
    state = AsyncValue.data(
      current.copyWith(
        filter: nextFilter,
        visibleGuides: filtered,
        recommended: recommended,
      ),
    );
  }

  void updateSearch(String query) {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final normalized = query.trim();
    if (current.searchQuery == normalized) {
      return;
    }
    final filtered = _filterEntries(
      current.allGuides,
      topic: current.filter.topic,
      searchQuery: normalized,
    );
    final recommended = _filterEntries(
      current.recommendedSource,
      topic: current.filter.topic,
      searchQuery: normalized,
    );
    state = AsyncValue.data(
      current.copyWith(
        visibleGuides: filtered,
        recommended: recommended,
        searchQuery: normalized,
      ),
    );
  }

  GuideListState _stateFromResult({
    required GuidesRepositoryResult result,
    required Locale locale,
    required UserPersona persona,
    required GuideCategory? topic,
    required String searchQuery,
  }) {
    final normalizedSearch = searchQuery.trim();
    final filter = GuideListFilter(
      persona: persona,
      locale: locale,
      topic: topic,
    );
    final topics = {for (final entry in result.guides) entry.category}.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final visible = _filterEntries(
      result.guides,
      topic: topic,
      searchQuery: normalizedSearch,
    );
    final recommended = _filterEntries(
      result.recommended,
      topic: topic,
      searchQuery: normalizedSearch,
    );
    return GuideListState(
      allGuides: List.unmodifiable(result.guides),
      visibleGuides: List.unmodifiable(visible),
      recommendedSource: List.unmodifiable(result.recommended),
      recommended: List.unmodifiable(recommended),
      filter: filter,
      searchQuery: normalizedSearch,
      availableTopics: List.unmodifiable(topics),
      availableLocales: List.unmodifiable(_kSupportedGuideLocales),
      isRefreshing: false,
      fromCache: result.fromCache,
      lastUpdated: result.fetchedAt,
    );
  }

  Future<void> _reloadWith({
    required Locale locale,
    required UserPersona persona,
    GuideCategory? topicOverride,
    String? searchOverride,
  }) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    try {
      final request = GuideListRequest(
        localeTag: locale.toLanguageTag(),
        persona: persona,
      );
      final result = await _repository.fetchGuides(request);
      final resolvedTopic = topicOverride ?? current?.filter.topic;
      final resolvedSearch = searchOverride ?? current?.searchQuery ?? '';
      state = AsyncValue.data(
        _stateFromResult(
          result: result,
          locale: locale,
          persona: persona,
          topic: resolvedTopic,
          searchQuery: resolvedSearch,
        ),
      );
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<GuideListEntry> _filterEntries(
    List<GuideListEntry> entries, {
    required GuideCategory? topic,
    required String searchQuery,
  }) {
    return [
      for (final entry in entries)
        if (entry.matchesCategory(topic) && entry.matchesSearch(searchQuery))
          entry,
    ];
  }

  Locale _resolveLocale(Locale desired) {
    for (final option in _kSupportedGuideLocales) {
      if (option.languageCode == desired.languageCode &&
          option.countryCode == desired.countryCode) {
        return option;
      }
    }
    for (final option in _kSupportedGuideLocales) {
      if (option.languageCode == desired.languageCode) {
        return option;
      }
    }
    return _kSupportedGuideLocales.first;
  }
}

class GuideListState {
  const GuideListState({
    required this.allGuides,
    required this.visibleGuides,
    required this.recommendedSource,
    required this.recommended,
    required this.filter,
    required this.searchQuery,
    required this.availableTopics,
    required this.availableLocales,
    this.isRefreshing = false,
    this.fromCache = false,
    this.lastUpdated,
  });

  final List<GuideListEntry> allGuides;
  final List<GuideListEntry> visibleGuides;
  final List<GuideListEntry> recommendedSource;
  final List<GuideListEntry> recommended;
  final GuideListFilter filter;
  final String searchQuery;
  final List<GuideCategory> availableTopics;
  final List<Locale> availableLocales;
  final bool isRefreshing;
  final bool fromCache;
  final DateTime? lastUpdated;

  static const Object _timestampSentinel = Object();

  GuideListState copyWith({
    List<GuideListEntry>? allGuides,
    List<GuideListEntry>? visibleGuides,
    List<GuideListEntry>? recommendedSource,
    List<GuideListEntry>? recommended,
    GuideListFilter? filter,
    String? searchQuery,
    List<GuideCategory>? availableTopics,
    List<Locale>? availableLocales,
    bool? isRefreshing,
    bool? fromCache,
    Object? lastUpdated = _timestampSentinel,
  }) {
    return GuideListState(
      allGuides: allGuides ?? this.allGuides,
      visibleGuides: visibleGuides ?? this.visibleGuides,
      recommendedSource: recommendedSource ?? this.recommendedSource,
      recommended: recommended ?? this.recommended,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      availableTopics: availableTopics ?? this.availableTopics,
      availableLocales: availableLocales ?? this.availableLocales,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
      lastUpdated: identical(lastUpdated, _timestampSentinel)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
    );
  }
}
