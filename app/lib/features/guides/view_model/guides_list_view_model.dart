// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/app_persona_provider.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum GuidesPersonaFilter { all, japanese, foreigner }

extension GuidesPersonaFilterX on GuidesPersonaFilter {
  String label({required bool prefersEnglish}) {
    return switch (this) {
      GuidesPersonaFilter.all => prefersEnglish ? 'All' : 'すべて',
      GuidesPersonaFilter.japanese => prefersEnglish ? 'Japanese' : '日本人向け',
      GuidesPersonaFilter.foreigner =>
        prefersEnglish ? 'International' : '外国人向け',
    };
  }
}

enum GuidesLocaleFilter { auto, ja, en }

extension GuidesLocaleFilterX on GuidesLocaleFilter {
  String label({required bool prefersEnglish}) {
    return switch (this) {
      GuidesLocaleFilter.auto => prefersEnglish ? 'Auto' : '自動',
      GuidesLocaleFilter.ja => '日本語',
      GuidesLocaleFilter.en => 'English',
    };
  }

  String resolveLang(AppExperienceGates gates) {
    return switch (this) {
      GuidesLocaleFilter.auto => gates.prefersEnglish ? 'en' : 'ja',
      GuidesLocaleFilter.ja => 'ja',
      GuidesLocaleFilter.en => 'en',
    };
  }
}

class GuidesListState {
  const GuidesListState({
    required this.items,
    required this.locale,
    required this.persona,
    required this.topic,
    required this.nextPageToken,
    required this.isRefreshing,
    required this.isLoadingMore,
  });

  final List<Guide> items;
  final GuidesLocaleFilter locale;
  final GuidesPersonaFilter persona;
  final GuideCategory? topic;
  final String? nextPageToken;
  final bool isRefreshing;
  final bool isLoadingMore;

  GuidesListState copyWith({
    List<Guide>? items,
    GuidesLocaleFilter? locale,
    GuidesPersonaFilter? persona,
    GuideCategory? topic,
    String? nextPageToken,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return GuidesListState(
      items: items ?? this.items,
      locale: locale ?? this.locale,
      persona: persona ?? this.persona,
      topic: topic ?? this.topic,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final guidesListViewModel = GuidesListViewModel();

class GuidesListViewModel extends AsyncProvider<GuidesListState> {
  GuidesListViewModel() : super.args(null, autoDispose: true);

  late final setLocaleMut = mutation<GuidesLocaleFilter>(#setLocale);
  late final setPersonaMut = mutation<GuidesPersonaFilter>(#setPersona);
  late final setTopicMut = mutation<GuideCategory?>(#setTopic);
  late final refreshMut = mutation<void>(#refresh);
  late final loadMoreMut = mutation<void>(#loadMore);

  @override
  Future<GuidesListState> build(Ref ref) async {
    final repository = ref.watch(contentRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);

    final locale = GuidesLocaleFilter.auto;
    final topic = null;
    final page = await repository.listGuides(
      lang: locale.resolveLang(gates),
      category: topic,
    );

    return GuidesListState(
      items: page.items,
      locale: locale,
      persona: _defaultPersonaFilter(ref),
      topic: topic,
      nextPageToken: page.nextPageToken,
      isRefreshing: false,
      isLoadingMore: false,
    );
  }

  Call<GuidesLocaleFilter> setLocale(GuidesLocaleFilter locale) =>
      mutate(setLocaleMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final gates = ref.watch(appExperienceGatesProvider);

        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              locale: locale,
              isRefreshing: true,
              items: const <Guide>[],
              nextPageToken: null,
            ),
          );
        } else {
          ref.state = const AsyncLoading<GuidesListState>();
        }

        final repository = ref.watch(contentRepositoryProvider);
        final page = await repository.listGuides(
          lang: locale.resolveLang(gates),
          category: current?.topic,
        );

        final next = GuidesListState(
          items: page.items,
          locale: locale,
          persona: current?.persona ?? _defaultPersonaFilter(ref),
          topic: current?.topic,
          nextPageToken: page.nextPageToken,
          isRefreshing: false,
          isLoadingMore: false,
        );
        ref.state = AsyncData(next);
        return locale;
      }, concurrency: Concurrency.restart);

  Call<GuidesPersonaFilter> setPersona(GuidesPersonaFilter persona) =>
      mutate(setPersonaMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return persona;
        ref.state = AsyncData(current.copyWith(persona: persona));
        return persona;
      });

  Call<GuideCategory?> setTopic(GuideCategory? topic) =>
      mutate(setTopicMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final gates = ref.watch(appExperienceGatesProvider);

        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              topic: topic,
              isRefreshing: true,
              items: const <Guide>[],
              nextPageToken: null,
            ),
          );
        } else {
          ref.state = const AsyncLoading<GuidesListState>();
        }

        final repository = ref.watch(contentRepositoryProvider);
        final page = await repository.listGuides(
          lang: (current?.locale ?? GuidesLocaleFilter.auto).resolveLang(gates),
          category: topic,
        );

        final next = GuidesListState(
          items: page.items,
          locale: current?.locale ?? GuidesLocaleFilter.auto,
          persona: current?.persona ?? _defaultPersonaFilter(ref),
          topic: topic,
          nextPageToken: page.nextPageToken,
          isRefreshing: false,
          isLoadingMore: false,
        );

        ref.state = AsyncData(next);
        return topic;
      }, concurrency: Concurrency.restart);

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final gates = ref.watch(appExperienceGatesProvider);
    final locale = current?.locale ?? GuidesLocaleFilter.auto;
    final topic = current?.topic;

    if (current != null) {
      ref.state = AsyncData(current.copyWith(isRefreshing: true));
    }

    final repository = ref.watch(contentRepositoryProvider);
    final page = await repository.listGuides(
      lang: locale.resolveLang(gates),
      category: topic,
    );

    final next = GuidesListState(
      items: page.items,
      locale: locale,
      persona: current?.persona ?? _defaultPersonaFilter(ref),
      topic: topic,
      nextPageToken: page.nextPageToken,
      isRefreshing: false,
      isLoadingMore: false,
    );
    ref.state = AsyncData(next);
  }, concurrency: Concurrency.dropLatest);

  Call<void> loadMore() => mutate(loadMoreMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore) return;
    final nextToken = current.nextPageToken;
    if (nextToken == null || nextToken.isEmpty) return;

    ref.state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final gates = ref.watch(appExperienceGatesProvider);
      final repository = ref.watch(contentRepositoryProvider);
      final page = await repository.listGuides(
        lang: current.locale.resolveLang(gates),
        category: current.topic,
        pageToken: nextToken,
      );

      ref.state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextPageToken: page.nextPageToken,
          isLoadingMore: false,
        ),
      );
    } catch (e, stack) {
      ref.state = AsyncError(
        e,
        stack,
        previous: AsyncData(current.copyWith(isLoadingMore: false)),
      );
    }
  }, concurrency: Concurrency.dropLatest);
}

GuidesPersonaFilter _defaultPersonaFilter(Ref ref) {
  final persona = ref.watch(appPersonaProvider);
  return switch (persona) {
    UserPersona.japanese => GuidesPersonaFilter.japanese,
    UserPersona.foreigner => GuidesPersonaFilter.foreigner,
  };
}
