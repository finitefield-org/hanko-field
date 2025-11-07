import 'dart:async';
import 'dart:ui';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/guides/data/guide_bookmarks_repository_provider.dart';
import 'package:app/features/guides/data/guides_repository.dart';
import 'package:app/features/guides/data/guides_repository_provider.dart';
import 'package:app/features/guides/domain/guide_detail.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guideDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GuideDetailController, GuideDetailState, String>(
      GuideDetailController.new,
    );

class GuideDetailController extends AsyncNotifier<GuideDetailState> {
  GuideDetailController(this.slug);

  final String slug;

  GuidesRepository get _repository => ref.read(guidesRepositoryProvider);

  @override
  FutureOr<GuideDetailState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    final request = GuideDetailRequest(
      slug: slug,
      localeTag: experience.locale.toLanguageTag(),
      persona: experience.persona,
    );
    final result = await _repository.fetchGuideDetail(request);
    final bookmarksRepo = await ref.watch(
      guideBookmarksRepositoryProvider.future,
    );
    final bookmarked = bookmarksRepo.loadBookmarks().contains(slug);
    return _stateFromResult(result, bookmarked);
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isRefreshing: true));
    } else {
      state = const AsyncLoading();
    }
    try {
      final experience = await ref.read(experienceGateProvider.future);
      final request = GuideDetailRequest(
        slug: slug,
        localeTag: experience.locale.toLanguageTag(),
        persona: experience.persona,
      );
      final result = await _repository.fetchGuideDetail(request);
      final repo = await ref.read(guideBookmarksRepositoryProvider.future);
      final bookmarked = repo.loadBookmarks().contains(slug);
      state = AsyncValue.data(_stateFromResult(result, bookmarked));
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> toggleBookmark() async {
    final current = state.asData?.value;
    if (current == null) {
      return false;
    }
    final repo = await ref.read(guideBookmarksRepositoryProvider.future);
    final bookmarks = repo.loadBookmarks();
    final updated = Set<String>.from(bookmarks);
    final nextValue = !bookmarks.contains(slug);
    if (nextValue) {
      updated.add(slug);
    } else {
      updated.remove(slug);
    }
    await repo.saveBookmarks(updated);
    state = AsyncValue.data(current.copyWith(bookmarked: nextValue));
    return nextValue;
  }

  GuideDetailState _stateFromResult(GuideDetailResult result, bool bookmarked) {
    return GuideDetailState(
      detail: result.detail,
      related: List.unmodifiable(result.related),
      locale: _localeFromTag(result.localeTag),
      persona: result.persona,
      fromCache: result.fromCache,
      lastUpdated: result.fetchedAt,
      bookmarked: bookmarked,
      isRefreshing: false,
    );
  }

  Locale _localeFromTag(String tag) {
    final segments = tag.split(RegExp('[-_]'));
    if (segments.length == 1) {
      return Locale(segments.first);
    }
    return Locale(segments.first, segments[1]);
  }
}

class GuideDetailState {
  const GuideDetailState({
    required this.detail,
    required this.related,
    required this.locale,
    required this.persona,
    required this.fromCache,
    required this.lastUpdated,
    required this.bookmarked,
    this.isRefreshing = false,
  });

  final GuideDetail detail;
  final List<GuideListEntry> related;
  final Locale locale;
  final UserPersona persona;
  final bool fromCache;
  final DateTime lastUpdated;
  final bool bookmarked;
  final bool isRefreshing;

  GuideDetailState copyWith({
    GuideDetail? detail,
    List<GuideListEntry>? related,
    Locale? locale,
    UserPersona? persona,
    bool? fromCache,
    DateTime? lastUpdated,
    bool? bookmarked,
    bool? isRefreshing,
  }) {
    return GuideDetailState(
      detail: detail ?? this.detail,
      related: related ?? this.related,
      locale: locale ?? this.locale,
      persona: persona ?? this.persona,
      fromCache: fromCache ?? this.fromCache,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      bookmarked: bookmarked ?? this.bookmarked,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
