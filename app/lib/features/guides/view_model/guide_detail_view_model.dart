// ignore_for_file: public_member_api_docs

import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/features/content/data/repositories/content_repository.dart';
import 'package:app/features/guides/data/repositories/guide_bookmarks_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class GuideDetailState {
  const GuideDetailState({
    required this.guide,
    required this.lang,
    required this.isBookmarked,
    required this.related,
  });

  final Guide guide;
  final String lang;
  final bool isBookmarked;
  final List<Guide> related;

  GuideDetailState copyWith({
    Guide? guide,
    String? lang,
    bool? isBookmarked,
    List<Guide>? related,
  }) {
    return GuideDetailState(
      guide: guide ?? this.guide,
      lang: lang ?? this.lang,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      related: related ?? this.related,
    );
  }
}

class GuideDetailViewModel extends AsyncProvider<GuideDetailState> {
  GuideDetailViewModel({required this.slug, required this.lang})
    : super.args((slug, lang), autoDispose: true);

  final String slug;
  final String lang;

  late final toggleBookmarkMut = mutation<bool>(#toggleBookmark);

  @override
  Future<GuideDetailState> build(Ref ref) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) throw ArgumentError.value(slug, 'slug');

    final repository = ref.watch(contentRepositoryProvider);
    final bookmarksRepo = ref.watch(guideBookmarksRepositoryProvider);

    final guide = await repository.getGuide(normalizedSlug, lang: lang);
    final bookmarks = await bookmarksRepo.loadBookmarks();
    final isBookmarked = bookmarks.contains(guide.slug);

    final related = await _loadRelated(
      repository: repository,
      lang: lang,
      category: guide.category,
      slug: guide.slug,
    );

    return GuideDetailState(
      guide: guide,
      lang: lang,
      isBookmarked: isBookmarked,
      related: related,
    );
  }

  Call<bool> toggleBookmark() => mutate(toggleBookmarkMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;

    final optimistic = !current.isBookmarked;
    ref.state = AsyncData(current.copyWith(isBookmarked: optimistic));

    final bookmarksRepo = ref.watch(guideBookmarksRepositoryProvider);
    final next = await bookmarksRepo.toggleBookmark(current.guide.slug);

    final isBookmarked = next.contains(current.guide.slug);
    ref.state = AsyncData(current.copyWith(isBookmarked: isBookmarked));

    if (isBookmarked) {
      final repository = ref.watch(contentRepositoryProvider);
      try {
        await repository.getGuide(current.guide.slug, lang: current.lang);
      } catch (_) {}
    }

    return isBookmarked;
  }, concurrency: Concurrency.dropLatest);
}

Future<List<Guide>> _loadRelated({
  required ContentRepository repository,
  required String lang,
  required GuideCategory category,
  required String slug,
}) async {
  try {
    final page = await repository.listGuides(lang: lang, category: category);
    final others = page.items.where((g) => g.slug != slug).toList();
    return others.take(5).toList();
  } catch (_) {
    return const <Guide>[];
  }
}

Uri guideShareUri(String slug, {required String lang}) {
  final normalizedSlug = slug.trim();
  final qp = lang.trim().isEmpty ? null : <String, String>{'lang': lang.trim()};
  return Uri.https('hanko.app', '/guides/$normalizedSlug', qp);
}
