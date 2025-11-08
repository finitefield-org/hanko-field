import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/features/guides/data/guides_repository.dart';
import 'package:app/features/guides/data/guides_repository_provider.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:app/features/howto/data/howto_progress_repository.dart';
import 'package:app/features/howto/data/howto_progress_repository_provider.dart';
import 'package:app/features/howto/data/howto_repository.dart';
import 'package:app/features/howto/data/howto_repository_provider.dart';
import 'package:app/features/howto/domain/howto_tutorial.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final howToControllerProvider =
    AsyncNotifierProvider<HowToController, HowToState>(HowToController.new);

enum HowToSegment { videos, guides }

class HowToController extends AsyncNotifier<HowToState> {
  HowToRepository get _repository => ref.read(howToRepositoryProvider);
  GuidesRepository get _guidesRepository => ref.read(guidesRepositoryProvider);
  HowToProgressRepository get _progressRepository =>
      ref.read(howToProgressRepositoryProvider);
  AnalyticsController get _analytics =>
      ref.read(analyticsControllerProvider.notifier);

  @override
  FutureOr<HowToState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    return _loadState(experience);
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
      final nextState = await _loadState(experience, reuseSegment: true);
      state = AsyncValue.data(nextState);
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void selectSegment(HowToSegment segment) {
    final current = state.asData?.value;
    if (current == null || current.selectedSegment == segment) {
      return;
    }
    state = AsyncValue.data(current.copyWith(selectedSegment: segment));
  }

  Future<void> toggleCompletion(String tutorialId) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final nextValue = !current.completedTutorialIds.contains(tutorialId);
    await _setCompletion(tutorialId, nextValue);
  }

  Future<void> markCompleted(String tutorialId) {
    return _setCompletion(tutorialId, true);
  }

  Future<void> _setCompletion(String tutorialId, bool completed) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final alreadyCompleted = current.completedTutorialIds.contains(tutorialId);
    if (alreadyCompleted == completed) {
      return;
    }
    final nextCompleted = completed
        ? (<String>{...current.completedTutorialIds}..add(tutorialId))
        : (<String>{...current.completedTutorialIds}..remove(tutorialId));
    final nextState = current.copyWith(completedTutorialIds: nextCompleted);
    state = AsyncValue.data(nextState);
    try {
      await _progressRepository.saveCompletedTutorialIds(nextCompleted);
      if (completed) {
        await _logCompletionEvent(tutorialId);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _logCompletionEvent(String tutorialId) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    for (final group in current.groups) {
      for (final tutorial in group.tutorials) {
        if (tutorial.id == tutorialId) {
          await _analytics.logEvent(
            HowToTutorialCompletedEvent(
              tutorialId: tutorial.id,
              topic: tutorial.topic.analyticsId,
              durationSeconds: tutorial.duration.inSeconds,
            ),
          );
          return;
        }
      }
    }
  }

  Future<HowToState> _loadState(
    ExperienceGate experience, {
    bool reuseSegment = true,
  }) async {
    final request = HowToContentRequest(
      localeTag: experience.locale.toLanguageTag(),
      persona: experience.persona,
    );
    final result = await _repository.fetchContent(request);
    final progress = await _progressRepository.loadCompletedTutorialIds();
    final guidesResult = await _guidesRepository.fetchGuides(
      GuideListRequest(
        localeTag: experience.locale.toLanguageTag(),
        persona: experience.persona,
      ),
    );
    final howToGuides =
        guidesResult.guides
            .where((guide) => guide.category == GuideCategory.howto)
            .toList()
          ..sort((a, b) {
            if (a.featured == b.featured) {
              return a.title.compareTo(b.title);
            }
            return a.featured ? -1 : 1;
          });

    final currentSegment = reuseSegment
        ? state.asData?.value.selectedSegment ?? HowToSegment.videos
        : HowToSegment.videos;

    return HowToState(
      groups: result.groups,
      guides: howToGuides,
      completedTutorialIds: progress,
      selectedSegment: currentSegment,
      lastUpdated: result.fetchedAt,
      fromCache: result.fromCache,
      isRefreshing: false,
    );
  }
}

class HowToState {
  HowToState({
    required List<HowToTopicGroup> groups,
    required List<GuideListEntry> guides,
    required Set<String> completedTutorialIds,
    required this.selectedSegment,
    this.lastUpdated,
    this.isRefreshing = false,
    this.fromCache = false,
  }) : groups = List.unmodifiable(groups),
       guides = List.unmodifiable(guides),
       completedTutorialIds = Set.unmodifiable(completedTutorialIds);

  final List<HowToTopicGroup> groups;
  final List<GuideListEntry> guides;
  final Set<String> completedTutorialIds;
  final HowToSegment selectedSegment;
  final DateTime? lastUpdated;
  final bool isRefreshing;
  final bool fromCache;

  HowToTutorial? get featuredTutorial {
    for (final group in groups) {
      for (final tutorial in group.tutorials) {
        if (tutorial.featured) {
          return tutorial;
        }
      }
    }
    if (groups.isEmpty || groups.first.tutorials.isEmpty) {
      return null;
    }
    return groups.first.tutorials.first;
  }

  int get tutorialCount {
    return groups.fold(0, (count, group) => count + group.tutorials.length);
  }

  double get completionRatio {
    if (tutorialCount == 0) {
      return 0;
    }
    return completedTutorialIds.length / tutorialCount;
  }

  HowToState copyWith({
    List<HowToTopicGroup>? groups,
    List<GuideListEntry>? guides,
    Set<String>? completedTutorialIds,
    HowToSegment? selectedSegment,
    DateTime? lastUpdated,
    bool? isRefreshing,
    bool? fromCache,
  }) {
    return HowToState(
      groups: groups ?? this.groups,
      guides: guides ?? this.guides,
      completedTutorialIds: completedTutorialIds ?? this.completedTutorialIds,
      selectedSegment: selectedSegment ?? this.selectedSegment,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HowToState &&
            listEquals(other.groups, groups) &&
            listEquals(other.guides, guides) &&
            setEquals(other.completedTutorialIds, completedTutorialIds) &&
            other.selectedSegment == selectedSegment &&
            other.lastUpdated == lastUpdated &&
            other.isRefreshing == isRefreshing &&
            other.fromCache == fromCache);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      Object.hashAll(groups),
      Object.hashAll(guides),
      Object.hashAll(completedTutorialIds),
      selectedSegment,
      lastUpdated,
      isRefreshing,
      fromCache,
    ]);
  }
}
