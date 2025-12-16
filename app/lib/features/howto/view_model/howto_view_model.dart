// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/features/howto/data/howto_catalog.dart';
import 'package:app/features/howto/data/models/howto_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HowtoState {
  const HowtoState({required this.videos, required this.guides, this.lang});

  final List<HowtoVideo> videos;
  final List<Guide> guides;
  final String? lang;
}

final howtoViewModel = HowtoViewModel();

class HowtoViewModel extends AsyncProvider<HowtoState> {
  HowtoViewModel() : super.args(null, autoDispose: true);

  late final refreshMut = mutation<void>(#refresh);
  late final trackVideoOpenedMut = mutation<void>(#trackVideoOpened);
  late final trackVideoStartedMut = mutation<void>(#trackVideoStarted);
  late final trackVideoCompletedMut = mutation<void>(#trackVideoCompleted);

  @override
  Future<HowtoState> build(Ref ref) async {
    final repository = ref.watch(contentRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final lang = gates.prefersEnglish ? 'en' : 'ja';

    final guidePage = await repository.listGuides(
      lang: lang,
      category: GuideCategory.howto,
    );

    return HowtoState(
      videos: howtoVideosCatalog,
      guides: guidePage.items,
      lang: lang,
    );
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    ref.state = AsyncData(
      HowtoState(
        videos: current?.videos ?? howtoVideosCatalog,
        guides: current?.guides ?? const <Guide>[],
        lang: current?.lang,
      ),
    );
    ref.invalidate(this);
  }, concurrency: Concurrency.dropLatest);

  Call<void> trackVideoOpened({
    required HowtoVideo video,
    required int position,
  }) => mutate(trackVideoOpenedMut, (ref) async {
    final analytics = ref.watch(analyticsClientProvider);
    unawaited(
      analytics.track(
        HowtoTutorialOpenedEvent(
          tutorialId: video.id,
          format: 'video',
          topic: video.topic(prefersEnglish: true),
          position: position,
        ),
      ),
    );
  });

  Call<void> trackVideoStarted({required HowtoVideo video}) =>
      mutate(trackVideoStartedMut, (ref) async {
        final analytics = ref.watch(analyticsClientProvider);
        unawaited(
          analytics.track(
            HowtoTutorialProgressEvent(
              tutorialId: video.id,
              format: 'video',
              progress: 'started',
            ),
          ),
        );
      }, concurrency: Concurrency.dropLatest);

  Call<void> trackVideoCompleted({required HowtoVideo video}) =>
      mutate(trackVideoCompletedMut, (ref) async {
        final analytics = ref.watch(analyticsClientProvider);
        unawaited(
          analytics.track(
            HowtoTutorialProgressEvent(
              tutorialId: video.id,
              format: 'video',
              progress: 'completed',
            ),
          ),
        );
      }, concurrency: Concurrency.dropLatest);
}
