// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/home/view_model/home_providers.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final PageController _featuredController;
  int _featuredIndex = 0;

  @override
  void initState() {
    super.initState();
    _featuredController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _featuredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final navigation = context.navigation;
    final featured = ref.watch(homeFeaturedProvider);
    final recents = ref.watch(homeRecentDesignsProvider);
    final recommended = ref.watch(homeRecommendedTemplatesProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _HomeAppBar(unread: unread, title: l10n.homeTitle),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        edgeOffset: tokens.spacing.lg,
        displacement: tokens.spacing.xl,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.lg,
                  tokens.spacing.lg,
                  tokens.spacing.sm,
                ),
                child: _buildHero(context, featured, colorScheme),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
                child: _buildRecents(
                  context,
                  recents,
                  colorScheme,
                  onSeeAll: () => navigation.go(AppRoutePaths.library),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.lg,
                  tokens.spacing.lg,
                  tokens.spacing.xl,
                ),
                child: _buildRecommendations(context, recommended, colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    AsyncValue<List<HomeFeaturedItem>> featured,
    ColorScheme colorScheme,
  ) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeFeaturedTitle,
          subtitle: l10n.homeFeaturedSubtitle,
          padding: EdgeInsets.only(bottom: tokens.spacing.md),
        ),
        SizedBox(
          height: 240,
          child: switch (featured) {
            AsyncLoading() => const _FeaturedSkeleton(),
            AsyncError(:final error) => _ErrorCard(
              message: error.toString(),
              onRetry: () => ref.invalidate(homeFeaturedProvider),
            ),
            AsyncData(:final value) when value.isEmpty => AppCard(
              child: Text(
                l10n.homeFeaturedEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AsyncData(:final value) => Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _featuredController,
                    itemCount: value.length,
                    onPageChanged: (index) {
                      setState(() => _featuredIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final item = value[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == value.length - 1
                              ? 0
                              : tokens.spacing.sm,
                        ),
                        child: _FeaturedCard(
                          item: item,
                          colorScheme: colorScheme,
                          onTap: () => _handleFeaturedTap(item),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: tokens.spacing.sm),
                _DotsIndicator(
                  count: value.length,
                  activeIndex: _featuredIndex,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.outlineVariant,
                ),
              ],
            ),
          },
        ),
      ],
    );
  }

  Widget _buildRecents(
    BuildContext context,
    AsyncValue<List<Design>> recents,
    ColorScheme colorScheme, {
    required VoidCallback onSeeAll,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeRecentTitle,
          subtitle: l10n.homeRecentSubtitle,
          actionLabel: l10n.homeRecentActionLabel,
          onAction: onSeeAll,
        ),
        SizedBox(height: tokens.spacing.sm),
        SizedBox(
          height: 176,
          child: switch (recents) {
            AsyncLoading() => const _HorizontalSkeleton(
              itemWidth: 220,
              itemHeight: 176,
            ),
            AsyncError(:final error) => _ErrorCard(
              message: error.toString(),
              onRetry: () => ref.invalidate(homeRecentDesignsProvider),
            ),
            AsyncData(:final value) when value.isEmpty => AppCard(
              child: Text(
                l10n.homeRecentEmpty,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AsyncData(:final value) => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: value.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final design = value[index];
                return _RecentDesignCard(
                  design: design,
                  colorScheme: colorScheme,
                  onTap: () => _handleRecentTap(design, index),
                );
              },
            ),
          },
        ),
      ],
    );
  }

  Widget _buildRecommendations(
    BuildContext context,
    AsyncValue<List<RecommendedTemplate>> recommended,
    ColorScheme colorScheme,
  ) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.homeRecommendedTitle,
          subtitle: l10n.homeRecommendedSubtitle,
        ),
        SizedBox(height: tokens.spacing.sm),
        SizedBox(
          height: 190,
          child: switch (recommended) {
            AsyncLoading() => const _HorizontalSkeleton(
              itemWidth: 240,
              itemHeight: 190,
              tinted: true,
            ),
            AsyncError(:final error) => _ErrorCard(
              message: error.toString(),
              onRetry: () => ref.invalidate(homeRecommendedTemplatesProvider),
            ),
            AsyncData(:final value) when value.isEmpty => AppCard(
              child: Text(
                l10n.homeRecommendedLoading,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            AsyncData(:final value) => ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: value.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.sm),
              itemBuilder: (context, index) {
                final item = value[index];
                return _TemplateCard(
                  recommendation: item,
                  colorScheme: colorScheme,
                  onTap: () => _handleTemplateTap(item, index),
                );
              },
            ),
          },
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    final gates = ref.container.read(appExperienceGatesProvider);
    const sections = ['featured', 'recents', 'templates'];

    await Future.wait([
      ref.refreshValue(homeFeaturedProvider, keepPrevious: true),
      ref.refreshValue(homeRecentDesignsProvider, keepPrevious: true),
      ref.refreshValue(homeRecommendedTemplatesProvider, keepPrevious: true),
    ]);

    unawaited(
      ref.container
          .read(analyticsClientProvider)
          .track(
            HomeRefreshedEvent(
              persona: gates.personaKey,
              locale: gates.localeTag,
              sections: sections,
            ),
          ),
    );
  }

  void _handleFeaturedTap(HomeFeaturedItem item) {
    _trackTap(section: 'featured', id: item.id);
    context.go(item.targetRoute);
  }

  void _handleRecentTap(Design design, int index) {
    final id = design.id ?? 'recent-$index';
    _trackTap(section: 'recents', id: id);
    context.go(AppRoutePaths.designPreview);
  }

  void _handleTemplateTap(RecommendedTemplate template, int index) {
    _trackTap(
      section: 'templates',
      id: template.template.id ?? 'template-$index',
      reason: template.reason,
      position: index,
    );
    context.go(AppRoutePaths.designStyle);
  }

  void _trackTap({
    required String section,
    required String id,
    String? reason,
    int? position,
  }) {
    final gates = ref.container.read(appExperienceGatesProvider);
    unawaited(
      ref.container
          .read(analyticsClientProvider)
          .track(
            HomeSectionItemTappedEvent(
              section: section,
              itemId: id,
              position: position,
              reason: reason,
              persona: gates.personaKey,
              locale: gates.localeTag,
            ),
          ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.unread, required this.title});

  final AsyncValue<int> unread;
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = context.navigation;
    final tokens = DesignTokensTheme.of(context);
    final unreadCount = switch (unread) {
      AsyncData(:final value) => value,
      _ => 0,
    };

    return AppBar(
      centerTitle: true,
      title: Text(title),
      actions: [
        IconButton(
          tooltip: AppLocalizations.of(context).homeSearchTooltip,
          onPressed: () => navigation.go(AppRoutePaths.search),
          icon: const Icon(Icons.search_rounded),
        ),
        Padding(
          padding: EdgeInsets.only(right: tokens.spacing.sm),
          child: Badge.count(
            count: unreadCount,
            isLabelVisible: unreadCount > 0,
            offset: const Offset(2, -2),
            child: IconButton(
              tooltip: AppLocalizations.of(context).homeNotificationsTooltip,
              onPressed: () => navigation.go(AppRoutePaths.notifications),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.colorScheme,
    required this.onTap,
  });

  final HomeFeaturedItem item;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Ink.image(
              image: NetworkImage(item.imageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.25),
                BlendMode.darken,
              ),
              onImageError: (_, __) {},
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.12),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(item.badge),
                    avatar: const Icon(Icons.local_fire_department),
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.9,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (item.tagline != null) ...[
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        SizedBox(width: tokens.spacing.xs),
                        Flexible(
                          child: Text(
                            item.tagline!,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.sm),
                      ],
                      FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(item.actionLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onPrimaryContainer,
                          foregroundColor: colorScheme.primary,
                        ),
                        onPressed: onTap,
                      ),
                    ],
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

class _RecentDesignCard extends StatelessWidget {
  const _RecentDesignCard({
    required this.design,
    required this.colorScheme,
    required this.onTap,
  });

  final Design design;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusLabel = switch (design.status) {
      DesignStatus.draft => l10n.homeStatusDraft,
      DesignStatus.ready => l10n.homeStatusReady,
      DesignStatus.ordered => l10n.homeStatusOrdered,
      DesignStatus.locked => l10n.homeStatusLocked,
    };

    final shapeLabel = design.shape == SealShape.round
        ? l10n.homeShapeRound
        : l10n.homeShapeSquare;
    final writingLabel = switch (design.style.writing) {
      WritingStyle.tensho => l10n.homeWritingTensho,
      WritingStyle.reisho => l10n.homeWritingReisho,
      WritingStyle.kaisho => l10n.homeWritingKaisho,
      WritingStyle.gyosho => l10n.homeWritingGyosho,
      WritingStyle.koentai => l10n.homeWritingKoentai,
      WritingStyle.custom => l10n.homeWritingCustom,
    };

    final name = design.input?.rawName ?? l10n.homeNameUnset;
    final previewUrl = design.assets?.previewPngUrl;

    return SizedBox(
      width: 220,
      child: AppCard(
        padding: EdgeInsets.all(tokens.spacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(statusLabel),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.sm),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHigh,
                    child: previewUrl != null
                        ? Image.network(
                            previewUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_outlined,
                              color: colorScheme.outline,
                            ),
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: colorScheme.outline,
                          ),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        l10n.homeDesignSummary(
                          shape: shapeLabel,
                          size: design.size.mm.toString(),
                          style: writingLabel,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              design.ai?.registrable == true
                  ? l10n.homeDesignAiCheckDone
                  : l10n.homeDesignAiCheckLabel(
                      design.ai?.diagnostics.firstOrNull ??
                          l10n.homeDesignAiCheckNotRun,
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.recommendation,
    required this.colorScheme,
    required this.onTap,
  });

  final RecommendedTemplate recommendation;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final template = recommendation.template;
    final shapeLabel = template.shape == SealShape.round
        ? l10n.homeShapeRound
        : l10n.homeShapeSquare;
    final writingLabel = switch (template.writing) {
      WritingStyle.tensho => l10n.homeWritingTensho,
      WritingStyle.reisho => l10n.homeWritingReisho,
      WritingStyle.kaisho => l10n.homeWritingKaisho,
      WritingStyle.gyosho => l10n.homeWritingGyosho,
      WritingStyle.koentai => l10n.homeWritingKoentai,
      WritingStyle.custom => l10n.homeWritingCustom,
    };

    return SizedBox(
      width: 240,
      child: Card(
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.md),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text(
                    l10n.homeTemplateLabel(
                      shape: shapeLabel,
                      style: writingLabel,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.06,
                  ),
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  template.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  recommendation.reason,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                // Keep this section single-line to avoid vertical overflow in the
                // fixed-height card, but make it resilient on narrow widths.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeTemplateRecommendedSize(
                          template.defaults?.sizeMm?.toStringAsFixed(1) ?? '-',
                        ),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.xs),
                    Flexible(
                      child: FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: const Icon(Icons.style_outlined),
                        label: Text(
                          l10n.homeTemplateApply,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton({
    required this.itemWidth,
    required this.itemHeight,
    this.tinted = false,
  });

  final double itemWidth;
  final double itemHeight;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final baseColor = tinted
        ? Theme.of(context).colorScheme.surfaceContainerHigh
        : Theme.of(context).colorScheme.surface;

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.sm),
      itemBuilder: (context, index) {
        return Container(
          width: itemWidth,
          height: itemHeight,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(tokens.radii.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeletonBlock(width: 80, height: 18),
              SizedBox(height: tokens.spacing.sm),
              const AppSkeletonBlock(height: 16),
              SizedBox(height: tokens.spacing.xs),
              AppSkeletonBlock(width: itemWidth * 0.6, height: 14),
              const Spacer(),
              AppSkeletonBlock(width: itemWidth * 0.5, height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _FeaturedSkeleton extends StatelessWidget {
  const _FeaturedSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: Stack(
          children: [
            Positioned.fill(
              child: Shimmer(
                child: Container(color: Theme.of(context).colorScheme.surface),
              ),
            ),
            Positioned(
              left: tokens.spacing.lg,
              right: tokens.spacing.lg,
              bottom: tokens.spacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSkeletonBlock(width: 90, height: 20),
                  SizedBox(height: tokens.spacing.sm),
                  const AppSkeletonBlock(height: 18),
                  SizedBox(height: tokens.spacing.xs),
                  const AppSkeletonBlock(width: 180, height: 16),
                  SizedBox(height: tokens.spacing.md),
                  const AppSkeletonBlock(width: 120, height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: tokens.durations.fast,
          margin: EdgeInsets.symmetric(horizontal: tokens.spacing.xs / 2),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeLoadFailed,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
