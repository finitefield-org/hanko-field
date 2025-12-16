// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/guides/data/models/guide_presentation.dart';
import 'package:app/features/howto/data/models/howto_models.dart';
import 'package:app/features/howto/view/howto_video_player_page.dart';
import 'package:app/features/howto/view_model/howto_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HowtoPage extends ConsumerWidget {
  const HowtoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final router = GoRouter.of(context);

    final state = ref.watch(howtoViewModel);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        body: RefreshIndicator.adaptive(
          onRefresh: () => ref.invoke(howtoViewModel.refresh()),
          edgeOffset: tokens.spacing.lg,
          displacement: tokens.spacing.xl,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar.large(
                pinned: true,
                backgroundColor: tokens.colors.surface,
                title: Text(prefersEnglish ? 'How-to' : '使い方'),
                leading: IconButton(
                  tooltip: prefersEnglish ? 'Back' : '戻る',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => router.pop(),
                ),
                bottom: TabBar(
                  tabs: [
                    Tab(text: prefersEnglish ? 'Videos' : '動画'),
                    Tab(text: prefersEnglish ? 'Articles' : '記事'),
                  ],
                ),
              ),
            ],
            body: switch (state) {
              AsyncLoading() => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator.adaptive()),
                ],
              ),
              AsyncError(:final error) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(tokens.spacing.lg),
                children: [
                  AppEmptyState(
                    title: prefersEnglish ? 'Unable to load' : '読み込めませんでした',
                    message: error.toString(),
                    icon: Icons.cloud_off_outlined,
                    actionLabel: prefersEnglish ? 'Retry' : '再試行',
                    onAction: () => ref.invalidate(howtoViewModel),
                  ),
                ],
              ),
              AsyncData(:final value) => TabBarView(
                children: [
                  _VideosTab(
                    state: value,
                    prefersEnglish: prefersEnglish,
                    onOpen: (video, position) {
                      ref.invoke(
                        howtoViewModel.trackVideoOpened(
                          video: video,
                          position: position,
                        ),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HowtoVideoPlayerPage(
                            video: video,
                            ccLangPref: prefersEnglish ? 'en' : 'ja',
                          ),
                        ),
                      );
                    },
                  ),
                  _ArticlesTab(
                    state: value,
                    prefersEnglish: prefersEnglish,
                    onOpenGuide: (slug) {
                      final qp = value.lang == null
                          ? ''
                          : '?lang=${value.lang}';
                      router.go('${AppRoutePaths.profile}/guides/$slug$qp');
                    },
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _VideosTab extends StatelessWidget {
  const _VideosTab({
    required this.state,
    required this.prefersEnglish,
    required this.onOpen,
  });

  final HowtoState state;
  final bool prefersEnglish;
  final void Function(HowtoVideo video, int position) onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    final featured = state.videos.where((v) => v.isFeatured).toList();
    final regular = state.videos.where((v) => !v.isFeatured).toList();

    final grouped = <String, List<HowtoVideo>>{};
    for (final video in regular) {
      final key = video.topic(prefersEnglish: prefersEnglish);
      grouped.putIfAbsent(key, () => []).add(video);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        if (featured.isNotEmpty) ...[
          Text(
            prefersEnglish ? 'Featured' : 'おすすめ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          ...featured.asMap().entries.map((entry) {
            final index = entry.key;
            final video = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.md),
              child: _FeaturedVideoCard(
                video: video,
                prefersEnglish: prefersEnglish,
                onTap: () => onOpen(video, index),
              ),
            );
          }),
          SizedBox(height: tokens.spacing.lg),
        ],
        ...grouped.entries.expand((entry) {
          final topic = entry.key;
          final videos = entry.value;
          return [
            Text(topic, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: tokens.spacing.sm),
            ...videos.asMap().entries.map((item) {
              final index = item.key;
              final video = item.value;
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.md),
                child: _VideoCard(
                  video: video,
                  prefersEnglish: prefersEnglish,
                  onTap: () => onOpen(video, index),
                ),
              );
            }),
            SizedBox(height: tokens.spacing.lg),
          ];
        }),
        if (state.videos.isEmpty)
          AppEmptyState(
            title: prefersEnglish ? 'No tutorials yet' : 'まだチュートリアルがありません',
            message: prefersEnglish
                ? 'Content will appear here when available.'
                : '公開され次第ここに表示されます。',
            icon: Icons.ondemand_video_outlined,
          ),
      ],
    );
  }
}

class _ArticlesTab extends StatelessWidget {
  const _ArticlesTab({
    required this.state,
    required this.prefersEnglish,
    required this.onOpenGuide,
  });

  final HowtoState state;
  final bool prefersEnglish;
  final ValueChanged<String> onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    final guides = state.guides.where((g) => g.isPublic).toList();

    if (guides.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(tokens.spacing.lg),
        children: [
          AppEmptyState(
            title: prefersEnglish ? 'No articles yet' : 'まだ記事がありません',
            message: prefersEnglish
                ? 'How-to articles will appear here when published.'
                : 'ハウツー記事が公開され次第ここに表示されます。',
            icon: Icons.article_outlined,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.all(tokens.spacing.lg),
      itemCount: guides.length,
      separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.md),
      itemBuilder: (context, index) {
        final guide = guides[index];
        final translation = guideTranslationForLang(
          guide,
          (state.lang ?? 'ja'),
        );
        return _ArticleCard(
          guide: guide,
          title: translation.title,
          summary: translation.summary,
          prefersEnglish: prefersEnglish,
          onTap: () => onOpenGuide(guide.slug),
        );
      },
    );
  }
}

class _FeaturedVideoCard extends StatelessWidget {
  const _FeaturedVideoCard({
    required this.video,
    required this.prefersEnglish,
    required this.onTap,
  });

  final HowtoVideo video;
  final bool prefersEnglish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final thumb = _youtubeThumbnailUrl(video.youtubeUrl);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumb != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(thumb, fit: BoxFit.cover),
              ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: tokens.spacing.sm,
                    runSpacing: tokens.spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        video.title(prefersEnglish: prefersEnglish),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(video.durationLabel),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    video.summary(prefersEnglish: prefersEnglish),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.prefersEnglish,
    required this.onTap,
  });

  final HowtoVideo video;
  final bool prefersEnglish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final thumb = _youtubeThumbnailUrl(video.youtubeUrl);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (thumb != null)
              SizedBox(
                width: 140,
                height: 88,
                child: Image.network(thumb, fit: BoxFit.cover),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title(prefersEnglish: prefersEnglish),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      video.summary(prefersEnglish: prefersEnglish),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(video.durationLabel),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.guide,
    required this.title,
    required this.summary,
    required this.prefersEnglish,
    required this.onTap,
  });

  final Guide guide;
  final String title;
  final String? summary;
  final bool prefersEnglish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final heroUrl = guide.heroImageUrl?.trim();
    final duration = guideReadingTimeLabel(
      guide,
      prefersEnglish: prefersEnglish,
    );

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heroUrl != null && heroUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(heroUrl, fit: BoxFit.cover),
              ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: tokens.spacing.sm,
                    runSpacing: tokens.spacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(duration),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  if (summary != null && summary!.trim().isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      summary!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _youtubeThumbnailUrl(String url) {
  final id = _extractYoutubeVideoId(url);
  if (id == null) return null;
  return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
}

String? _extractYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (uri.host == 'youtu.be') {
    final id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    return (id == null || id.isEmpty) ? null : id;
  }

  if (uri.host.endsWith('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final segments = uri.pathSegments;
    final embedIndex = segments.indexOf('embed');
    if (embedIndex != -1 && embedIndex + 1 < segments.length) {
      final id = segments[embedIndex + 1];
      return id.isEmpty ? null : id;
    }
  }

  return null;
}
