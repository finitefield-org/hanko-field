// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class FaqListState {
  const FaqListState({
    required this.items,
    required this.nextPageToken,
    required this.isRefreshing,
    required this.isLoadingMore,
  });

  final List<Guide> items;
  final String? nextPageToken;
  final bool isRefreshing;
  final bool isLoadingMore;

  FaqListState copyWith({
    List<Guide>? items,
    String? nextPageToken,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return FaqListState(
      items: items ?? this.items,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final faqListViewModel = FaqListViewModel();

class FaqListViewModel extends AsyncProvider<FaqListState> {
  FaqListViewModel() : super.args(null, autoDispose: true);

  late final refreshMut = mutation<void>(#refresh);
  late final loadMoreMut = mutation<void>(#loadMore);

  @override
  Future<FaqListState> build(Ref<AsyncValue<FaqListState>> ref) async {
    final repository = ref.watch(contentRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final page = await repository.listGuides(
      lang: gates.prefersEnglish ? 'en' : 'ja',
      category: GuideCategory.faq,
    );

    return FaqListState(
      items: page.items,
      nextPageToken: page.nextPageToken,
      isRefreshing: false,
      isLoadingMore: false,
    );
  }

  Call<void, AsyncValue<FaqListState>> refresh() =>
      mutate(refreshMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current != null) {
          ref.state = AsyncData(current.copyWith(isRefreshing: true));
        }

        final repository = ref.watch(contentRepositoryProvider);
        final gates = ref.watch(appExperienceGatesProvider);
        final page = await repository.listGuides(
          lang: gates.prefersEnglish ? 'en' : 'ja',
          category: GuideCategory.faq,
        );

        ref.state = AsyncData(
          FaqListState(
            items: page.items,
            nextPageToken: page.nextPageToken,
            isRefreshing: false,
            isLoadingMore: false,
          ),
        );
      }, concurrency: Concurrency.dropLatest);

  Call<void, AsyncValue<FaqListState>> loadMore() =>
      mutate(loadMoreMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;
        if (current.isLoadingMore) return;
        final nextToken = current.nextPageToken;
        if (nextToken == null || nextToken.isEmpty) return;

        ref.state = AsyncData(current.copyWith(isLoadingMore: true));

        try {
          final repository = ref.watch(contentRepositoryProvider);
          final gates = ref.watch(appExperienceGatesProvider);
          final page = await repository.listGuides(
            lang: gates.prefersEnglish ? 'en' : 'ja',
            category: GuideCategory.faq,
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
            previous: current.copyWith(isLoadingMore: false),
          );
        }
      }, concurrency: Concurrency.dropLatest);
}
