// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/guides/data/models/guide_presentation.dart';
import 'package:app/features/guides/view_model/guide_detail_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class GuideDetailPage extends ConsumerWidget {
  const GuideDetailPage({super.key, required this.slug, this.lang});

  final String slug;
  final String? lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
    final preferredLang = _normalizeLang(lang, prefersEnglish: prefersEnglish);

    final viewModel = GuideDetailViewModel(slug: slug, lang: preferredLang);
    final state = ref.watch(viewModel);
    final data = state.valueOrNull;
    final bookmarkState = ref.watch(viewModel.toggleBookmarkMut);
    final isBookmarkBusy = bookmarkState is PendingMutationState;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(prefersEnglish ? 'Guide' : 'ガイド'),
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => router.pop(),
        ),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Bookmark' : '保存',
            icon: Icon(
              (data?.isBookmarked ?? false)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
            ),
            onPressed: isBookmarkBusy || data == null
                ? null
                : () async {
                    final next = await ref.invoke(viewModel.toggleBookmark());
                    if (!context.mounted) return;
                    final message = next
                        ? (prefersEnglish
                              ? 'Saved for offline'
                              : 'オフライン用に保存しました')
                        : (prefersEnglish ? 'Removed from saved' : '保存を解除しました');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  },
          ),
          IconButton(
            tooltip: prefersEnglish ? 'Share' : '共有',
            icon: const Icon(Icons.share_outlined),
            onPressed: data == null
                ? null
                : () => Share.share(
                    guideShareUri(data.guide.slug, lang: data.lang).toString(),
                    subject: guideTranslationForLang(
                      data.guide,
                      data.lang,
                    ).title,
                  ),
          ),
          IconButton(
            tooltip: prefersEnglish ? 'Open list' : '一覧へ',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: () => router.go('${AppRoutePaths.profile}/guides'),
          ),
        ],
      ),
      body: switch (state) {
        AsyncLoading() => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppEmptyState(
              title: prefersEnglish ? 'Unable to load' : '読み込めませんでした',
              message: error.toString(),
              icon: Icons.cloud_off_outlined,
              actionLabel: prefersEnglish ? 'Retry' : '再試行',
              onAction: () => ref.invalidate(viewModel),
            ),
          ),
        ),
        AsyncData(:final value) => _GuideBody(
          state: value,
          prefersEnglish: prefersEnglish,
        ),
      },
    );
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.state, required this.prefersEnglish});

  final GuideDetailState state;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final guide = state.guide;
    final translation = guideTranslationForLang(guide, state.lang);

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        _HeroCard(
          guide: guide,
          title: translation.title,
          summary: translation.summary,
          prefersEnglish: prefersEnglish,
        ),
        SizedBox(height: tokens.spacing.lg),
        Material(
          color: tokens.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.lg),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: AppRichContent(
              content: translation.body,
              onTapUrl: (url) => _openExternalUrl(url),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        _Utilities(
          prefersEnglish: prefersEnglish,
          shareUri: guideShareUri(guide.slug, lang: state.lang),
        ),
        if (state.related.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.xl),
          Text(
            prefersEnglish ? 'Related' : '関連コンテンツ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: tokens.spacing.sm),
          ...state.related.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.sm),
              child: _RelatedCard(
                guide: item,
                lang: state.lang,
                prefersEnglish: prefersEnglish,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _normalizeLang(String? lang, {required bool prefersEnglish}) {
  final normalized = lang?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return prefersEnglish ? 'en' : 'ja';
  }
  if (normalized.startsWith('en')) return 'en';
  if (normalized.startsWith('ja')) return 'ja';
  return normalized.split('-').first;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.guide,
    required this.title,
    required this.summary,
    required this.prefersEnglish,
  });

  final Guide guide;
  final String title;
  final String? summary;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final heroUrl = guide.heroImageUrl?.trim();
    final topicLabel = guideTopicLabel(
      guide.category,
      prefersEnglish: prefersEnglish,
    );
    final duration = guideReadingTimeLabel(
      guide,
      prefersEnglish: prefersEnglish,
    );

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heroUrl != null && heroUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                heroUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: tokens.colors.surfaceVariant,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 180,
              width: double.infinity,
              color: tokens.colors.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.xs,
                  children: [
                    Chip(label: Text(topicLabel)),
                    Chip(label: Text(duration)),
                    ...guide.tags.take(3).map((tag) => Chip(label: Text(tag))),
                  ],
                ),
                SizedBox(height: tokens.spacing.md),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (summary != null && summary!.trim().isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.sm),
                  Text(summary!, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Utilities extends StatelessWidget {
  const _Utilities({required this.prefersEnglish, required this.shareUri});

  final bool prefersEnglish;
  final Uri shareUri;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => Share.share(shareUri.toString()),
            icon: const Icon(Icons.share_outlined),
            label: Text(prefersEnglish ? 'Share' : '共有'),
          ),
        ),
        SizedBox(width: tokens.spacing.md),
        TextButton.icon(
          onPressed: () =>
              launchUrl(shareUri, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(prefersEnglish ? 'Open' : 'ブラウザで開く'),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.guide,
    required this.lang,
    required this.prefersEnglish,
  });

  final Guide guide;
  final String lang;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);
    final translation = guideTranslationForLang(guide, lang);
    final topicLabel = guideTopicLabel(
      guide.category,
      prefersEnglish: prefersEnglish,
    );

    return Card(
      elevation: 0,
      color: tokens.colors.surface,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.lg,
          vertical: tokens.spacing.sm,
        ),
        title: Text(
          translation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          topicLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.72),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => router.go(
          '${AppRoutePaths.profile}/guides/${guide.slug}?lang=$lang',
        ),
      ),
    );
  }
}

Future<bool> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
