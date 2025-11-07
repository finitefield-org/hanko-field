import 'dart:async';

import 'package:app/core/domain/entities/content.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/guides/application/guide_detail_controller.dart';
import 'package:app/features/guides/domain/guide_detail.dart';
import 'package:app/features/guides/domain/guide_list_entry.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class GuideDetailScreen extends ConsumerStatefulWidget {
  const GuideDetailScreen({required this.slug, this.categoryHint, super.key});

  final String slug;
  final String? categoryHint;

  @override
  ConsumerState<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends ConsumerState<GuideDetailScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(guideDetailControllerProvider(widget.slug));
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: asyncState.when(
        data: (state) => _buildBody(context, state, l10n),
        loading: () => const _GuideDetailLoading(),
        error: (error, _) => _GuideDetailError(
          title: l10n.guideDetailErrorTitle,
          message: l10n.guideDetailErrorMessage,
          onRetry: () => ref
              .read(guideDetailControllerProvider(widget.slug).notifier)
              .refresh(),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    GuideDetailState state,
    AppLocalizations l10n,
  ) {
    final notifier = ref.read(
      guideDetailControllerProvider(widget.slug).notifier,
    );
    final refreshIndicator = RefreshIndicator(
      onRefresh: notifier.refresh,
      displacement: 80,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            title: Text(state.detail.title),
            actions: [
              IconButton(
                tooltip: state.bookmarked
                    ? l10n.guideDetailBookmarkTooltipRemove
                    : l10n.guideDetailBookmarkTooltipSave,
                icon: Icon(
                  state.bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
                onPressed: () =>
                    _handleBookmarkToggle(context, notifier, state, l10n),
              ),
            ],
            bottom: state.isRefreshing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceM,
              ),
              child: _GuideDetailHeader(
                state: state,
                l10n: l10n,
                onShare: () => _handleShare(context, state, l10n),
                onOpenInBrowser: () => _handleOpenInBrowser(state),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceS,
              ),
              child: _GuideBodySection(detail: state.detail),
            ),
          ),
          if (state.related.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceXL,
                  AppTokens.spaceL,
                  AppTokens.spaceXL,
                ),
                child: _GuideRelatedSection(
                  related: state.related,
                  l10n: l10n,
                  onTap: _openGuide,
                ),
              ),
            ),
        ],
      ),
    );
    return refreshIndicator;
  }

  Future<void> _handleBookmarkToggle(
    BuildContext context,
    GuideDetailController notifier,
    GuideDetailState state,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await notifier.toggleBookmark();
    if (!mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result
              ? l10n.guideDetailBookmarkSavedMessage
              : l10n.guideDetailBookmarkRemovedMessage,
        ),
      ),
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    GuideDetailState state,
    AppLocalizations l10n,
  ) async {
    final url =
        state.detail.shareUrl ??
        'https://app.hanko-field.com/guides/${state.detail.slug}';
    final message = l10n.guideDetailShareMessage(state.detail.title, url);
    await Share.share(message);
  }

  Future<void> _handleOpenInBrowser(GuideDetailState state) async {
    final url =
        state.detail.shareUrl ??
        'https://app.hanko-field.com/guides/${state.detail.slug}';
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openGuide(GuideListEntry entry) {
    ref
        .read(appStateProvider.notifier)
        .push(GuidesRoute(sectionSegments: [entry.slug]));
  }
}

class _GuideDetailHeader extends StatelessWidget {
  const _GuideDetailHeader({
    required this.state,
    required this.l10n,
    required this.onShare,
    required this.onOpenInBrowser,
  });

  final GuideDetailState state;
  final AppLocalizations l10n;
  final VoidCallback onShare;
  final VoidCallback onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail;
    final theme = Theme.of(context);
    final dateLocale = state.locale.toLanguageTag();
    final dateFormat = DateFormat.yMMMMd(dateLocale);
    final updatedLabel = l10n.guideDetailUpdatedLabel(
      dateFormat.format(detail.updatedAt ?? state.lastUpdated),
    );
    final durationLabel = detail.readingTimeMinutes == null
        ? null
        : l10n.guidesReadingTimeLabel(detail.readingTimeMinutes!);
    final personaLabel = switch (state.persona) {
      UserPersona.japanese => l10n.guidesPersonaJapaneseLabel,
      UserPersona.foreigner => l10n.guidesPersonaInternationalLabel,
    };
    final displayTags = detail.tags
        .where((tag) => !tag.startsWith('persona:'))
        .where((tag) => tag != 'recommended')
        .toList();
    final sources = detail.sources;
    final cachedBanner = state.fromCache
        ? l10n.guideDetailCachedBanner(
            DateFormat.yMMMd(dateLocale).add_Hm().format(state.lastUpdated),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GuideHeroImage(imageUrl: detail.heroImageUrl),
              Padding(
                padding: const EdgeInsets.all(AppTokens.spaceL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppTokens.spaceS,
                      runSpacing: AppTokens.spaceS,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.category_outlined, size: 16),
                          label: Text(_topicLabel(detail.category, l10n)),
                        ),
                        if (detail.featured)
                          Chip(
                            avatar: const Icon(Icons.star, size: 16),
                            label: Text(l10n.guidesRecommendedChip),
                          ),
                        Chip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text(personaLabel),
                        ),
                        if (durationLabel != null)
                          Chip(
                            avatar: const Icon(Icons.schedule, size: 16),
                            label: Text(durationLabel),
                          ),
                      ],
                    ),
                    if (cachedBanner != null)
                      Container(
                        margin: const EdgeInsets.only(top: AppTokens.spaceM),
                        padding: const EdgeInsets.all(AppTokens.spaceM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.offline_pin_outlined, size: 20),
                            const SizedBox(width: AppTokens.spaceS),
                            Expanded(
                              child: Text(
                                cachedBanner,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppTokens.spaceM),
                    Text(
                      detail.summary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceL),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: onShare,
                          child: Text(l10n.guideDetailShareButtonLabel),
                        ),
                        const SizedBox(width: AppTokens.spaceM),
                        TextButton.icon(
                          onPressed: onOpenInBrowser,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(l10n.guideDetailOpenInBrowser),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.spaceL),
                    Text(
                      updatedLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (displayTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceM),
            child: Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                for (final tag in displayTags.take(8))
                  Chip(label: Text('#$tag')),
              ],
            ),
          ),
        if (sources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.guideDetailSourcesLabel,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                for (final source in sources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceXS),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16),
                        const SizedBox(width: AppTokens.spaceS),
                        Expanded(child: Text(source)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GuideBodySection extends StatelessWidget {
  const _GuideBodySection({required this.detail});

  final GuideDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: GuideBodyRenderer(
        detail: detail,
        textStyle: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class GuideBodyRenderer extends StatelessWidget {
  const GuideBodyRenderer({required this.detail, this.textStyle, super.key});

  static final Uri _defaultGuideOrigin = Uri.parse(
    'https://app.hanko-field.com/',
  );

  final GuideDetail detail;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    if (detail.bodyFormat == GuideBodyFormat.html) {
      return HtmlWidget(
        detail.body,
        textStyle: textStyle,
        onTapUrl: (url) => _handleLinkTap(context, url),
      );
    }
    return MarkdownBody(
      data: detail.body,
      selectable: false,
      onTapLink: (_, href, __) {
        unawaited(_handleLinkTap(context, href));
      },
      styleSheet: MarkdownStyleSheet.fromTheme(
        Theme.of(context),
      ).copyWith(p: textStyle),
    );
  }

  Future<bool> _handleLinkTap(BuildContext context, String? link) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (link == null || link.isEmpty) {
      _showLinkError(messenger, l10n);
      return false;
    }
    final target = _resolveLinkUri(link);
    if (target == null) {
      _showLinkError(messenger, l10n);
      return false;
    }
    final launched = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      _showLinkError(messenger, l10n);
    }
    return launched;
  }

  Uri? _resolveLinkUri(String link) {
    final parsed = Uri.tryParse(link.trim());
    if (parsed == null) {
      return null;
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    final base = _originForDetail();
    return base.resolveUri(parsed);
  }

  Uri _originForDetail() {
    final share = detail.shareUrl;
    if (share == null) {
      return _defaultGuideOrigin;
    }
    final uri = Uri.tryParse(share);
    if (uri == null || uri.scheme.isEmpty) {
      return _defaultGuideOrigin;
    }
    return uri.replace(path: '/', query: null, fragment: null);
  }

  void _showLinkError(ScaffoldMessengerState messenger, AppLocalizations l10n) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.guideDetailLinkOpenError)));
  }
}

class _GuideRelatedSection extends StatelessWidget {
  const _GuideRelatedSection({
    required this.related,
    required this.l10n,
    required this.onTap,
  });

  final List<GuideListEntry> related;
  final AppLocalizations l10n;
  final void Function(GuideListEntry entry) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.guideDetailRelatedTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppTokens.spaceM),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final entry = related[index];
            final durationLabel = entry.readingTimeMinutes == null
                ? null
                : l10n.guidesReadingTimeLabel(entry.readingTimeMinutes!);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceS,
                vertical: AppTokens.spaceXS,
              ),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.menu_book_outlined),
              ),
              title: Text(entry.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (durationLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                      child: Text(
                        durationLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(entry),
            );
          },
          separatorBuilder: (_, __) => const Divider(),
          itemCount: related.length,
        ),
      ],
    );
  }
}

class _GuideDetailLoading extends StatelessWidget {
  const _GuideDetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      children: const [
        AppSkeletonBlock(height: 28, width: 220),
        SizedBox(height: AppTokens.spaceL),
        AppSkeletonBlock(height: 180),
        SizedBox(height: AppTokens.spaceL),
        AppListSkeleton(items: 3),
      ],
    );
  }
}

class _GuideDetailError extends StatelessWidget {
  const _GuideDetailError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: AppEmptyState(
        title: title,
        message: message,
        icon: const Icon(Icons.wifi_off_outlined),
        primaryAction: AppButton(
          label: AppLocalizations.of(context).guidesRetryButtonLabel,
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class _GuideHeroImage extends StatelessWidget {
  const _GuideHeroImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: const Center(child: Icon(Icons.landscape_outlined, size: 48)),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            );
          },
        ),
      ),
    );
  }
}

String _topicLabel(GuideCategory category, AppLocalizations l10n) {
  switch (category) {
    case GuideCategory.culture:
      return l10n.guidesCategoryCulture;
    case GuideCategory.howto:
      return l10n.guidesCategoryHowTo;
    case GuideCategory.policy:
      return l10n.guidesCategoryPolicy;
    case GuideCategory.faq:
      return l10n.guidesCategoryFaq;
    case GuideCategory.news:
      return l10n.guidesCategoryNews;
    case GuideCategory.other:
      return l10n.guidesCategoryOther;
  }
}
