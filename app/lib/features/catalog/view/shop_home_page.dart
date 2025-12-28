// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart'
    as catalog;
import 'package:app/features/catalog/view_model/shop_home_providers.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ShopHomePage extends ConsumerStatefulWidget {
  const ShopHomePage({super.key});

  @override
  ConsumerState<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends ConsumerState<ShopHomePage> {
  late final PageController _promotionController;
  int _promotionIndex = 0;
  final GlobalKey _promotionsSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _promotionController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _promotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);
    final l10n = AppLocalizations.of(context);

    final categories = ref.watch(shopCategoriesProvider);
    final promotions = ref.watch(shopPromotionsProvider);
    final materials = ref.watch(shopMaterialRecommendationsProvider);
    final guides = ref.watch(shopGuideLinksProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        edgeOffset: tokens.spacing.lg,
        displacement: tokens.spacing.xl,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(context, router, l10n),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.md,
                  tokens.spacing.lg,
                  tokens.spacing.md,
                ),
                child: _HeroBanner(
                  l10n: l10n,
                  onTap: () => _handleHeroTap(router),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  0,
                  tokens.spacing.lg,
                  tokens.spacing.md,
                ),
                child: _buildGuideLinks(guides, l10n),
              ),
            ),
            _buildCategoryGrid(categories, l10n),
            SliverToBoxAdapter(
              key: _promotionsSectionKey,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.lg,
                  tokens.spacing.xl,
                  tokens.spacing.lg,
                  tokens.spacing.md,
                ),
                child: _buildPromotions(context, promotions, l10n),
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
                child: _buildMaterialRecommendations(context, materials, l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    GoRouter router,
    AppLocalizations l10n,
  ) {
    final tokens = DesignTokensTheme.of(context);

    return SliverAppBar.large(
      pinned: true,
      backgroundColor: tokens.colors.surface,
      title: Text(l10n.shopTitle),
      actions: [
        IconButton(
          tooltip: l10n.shopSearchTooltip,
          onPressed: () => router.go(AppRoutePaths.search),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: l10n.shopCartTooltip,
          onPressed: () => router.go(AppRoutePaths.cart),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              kToolbarHeight + tokens.spacing.sm,
              tokens.spacing.lg,
              tokens.spacing.md,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shopAppBarSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Wrap(
                    spacing: tokens.spacing.sm,
                    runSpacing: tokens.spacing.xs,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.local_offer_outlined,
                          size: 18,
                        ),
                        label: Text(l10n.shopActionPromotions),
                        onPressed: _scrollToPromotions,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(l10n.shopActionGuides),
                        onPressed: () =>
                            router.go('${AppRoutePaths.profile}/guides'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuideLinks(
    AsyncValue<List<ShopGuideLink>> links,
    AppLocalizations l10n,
  ) {
    final tokens = DesignTokensTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.shopQuickGuidesTitle,
          subtitle: l10n.shopQuickGuidesSubtitle,
        ),
        SizedBox(height: tokens.spacing.sm),
        switch (links) {
          AsyncLoading() => const AppListSkeleton(items: 2, itemHeight: 72),
          AsyncError(:final error) => _ErrorCard(
            message: error.toString(),
            onRetry: () => ref.invalidate(shopGuideLinksProvider),
          ),
          AsyncData(:final value) => Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: value
                .map(
                  (link) => SizedBox(
                    width: 320,
                    child: AppListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: tokens.colors.surfaceVariant
                            .withValues(alpha: 0.8),
                        child: Icon(link.icon, color: tokens.colors.primary),
                      ),
                      title: Text(link.title),
                      subtitle: Text(link.subtitle),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () => _handleGuideTap(link),
                    ),
                  ),
                )
                .toList(),
          ),
        },
      ],
    );
  }

  SliverPadding _buildCategoryGrid(
    AsyncValue<List<ShopCategory>> categories,
    AppLocalizations l10n,
  ) {
    final tokens = DesignTokensTheme.of(context);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: l10n.shopBrowseByMaterialTitle,
              subtitle: l10n.shopBrowseByMaterialSubtitle,
            ),
            SizedBox(height: tokens.spacing.md),
            switch (categories) {
              AsyncLoading() => _CategorySkeletonGrid(tokens: tokens),
              AsyncError(:final error) => _ErrorCard(
                message: error.toString(),
                onRetry: () => ref.invalidate(shopCategoriesProvider),
              ),
              AsyncData(:final value) => LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 640 ? 3 : 2;
                  final tileWidth =
                      (constraints.maxWidth -
                          tokens.spacing.sm * (crossAxisCount - 1)) /
                      crossAxisCount;
                  final aspectRatio = tileWidth / 150;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: value.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: tokens.spacing.sm,
                      mainAxisSpacing: tokens.spacing.sm,
                      childAspectRatio: aspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final category = value[index];
                      return _CategoryCard(
                        category: category,
                        onTap: () => _handleCategoryTap(category, index),
                      );
                    },
                  );
                },
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildPromotions(
    BuildContext context,
    AsyncValue<List<ShopPromotionHighlight>> promotions,
    AppLocalizations l10n,
  ) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.shopPromotionsTitle,
          subtitle: l10n.shopPromotionsSubtitle,
        ),
        SizedBox(height: tokens.spacing.md),
        SizedBox(
          height: 220,
          child: switch (promotions) {
            AsyncLoading() => const _HorizontalSkeleton(
              itemWidth: 280,
              itemHeight: 200,
            ),
            AsyncError(:final error) => _ErrorCard(
              message: error.toString(),
              onRetry: () => ref.invalidate(shopPromotionsProvider),
            ),
            AsyncData(:final value) when value.isEmpty => AppCard(
              child: Text(l10n.shopPromotionsEmpty),
            ),
            AsyncData(:final value) => Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _promotionController,
                    itemCount: value.length,
                    onPageChanged: (index) {
                      setState(() => _promotionIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final item = value[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == value.length - 1
                              ? 0
                              : tokens.spacing.sm,
                        ),
                        child: _PromotionCard(
                          item: item,
                          colorScheme: colorScheme,
                          onTap: () => _handlePromotionTap(item, index),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: tokens.spacing.sm),
                _DotsIndicator(
                  count: value.length,
                  activeIndex: _promotionIndex,
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

  Widget _buildMaterialRecommendations(
    BuildContext context,
    AsyncValue<List<ShopMaterialHighlight>> materials,
    AppLocalizations l10n,
  ) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.shopRecommendedMaterialsTitle,
          subtitle: l10n.shopRecommendedMaterialsSubtitle,
        ),
        SizedBox(height: tokens.spacing.sm),
        switch (materials) {
          AsyncLoading() => const AppListSkeleton(items: 3, itemHeight: 132),
          AsyncError(:final error) => _ErrorCard(
            message: error.toString(),
            onRetry: () => ref.invalidate(shopMaterialRecommendationsProvider),
          ),
          AsyncData(:final value) when value.isEmpty => AppCard(
            child: Text(l10n.shopRecommendedMaterialsEmpty),
          ),
          AsyncData(:final value) => Column(
            children: value.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == value.length - 1 ? 0 : tokens.spacing.sm,
                ),
                child: _MaterialCard(
                  highlight: item,
                  colorScheme: colorScheme,
                  onTap: () => _handleMaterialTap(item, index),
                ),
              );
            }).toList(),
          ),
        },
      ],
    );
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.refreshValue(shopCategoriesProvider, keepPrevious: true),
      ref.refreshValue(shopPromotionsProvider, keepPrevious: true),
      ref.refreshValue(shopMaterialRecommendationsProvider, keepPrevious: true),
      ref.refreshValue(shopGuideLinksProvider, keepPrevious: true),
    ]);
  }

  void _scrollToPromotions() {
    final ctx = _promotionsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 280),
      );
    }
  }

  void _handleHeroTap(GoRouter router) {
    _trackEvent(
      const ShopPromotionTappedEvent(
        promotionId: 'hero',
        code: 'SPRING24',
        entryPoint: 'hero',
      ),
    );
    router.go(
      AppRoutePaths.productDetail.replaceFirst(':productId', 'round-classic'),
    );
  }

  void _handleCategoryTap(ShopCategory category, int index) {
    _trackEvent(
      ShopCategoryTappedEvent(categoryId: category.id, position: index),
    );
    GoRouter.of(context).go(category.targetRoute);
  }

  void _handlePromotionTap(ShopPromotionHighlight promotion, int index) {
    _trackEvent(
      ShopPromotionTappedEvent(
        promotionId: promotion.id,
        code: promotion.code,
        position: index,
      ),
    );
    GoRouter.of(context).go(promotion.targetRoute);
  }

  void _handleMaterialTap(ShopMaterialHighlight material, int index) {
    final target = AppRoutePaths.materialDetail.replaceFirst(
      ':materialId',
      material.material.id ?? 'material-$index',
    );
    _trackEvent(
      ShopMaterialTappedEvent(
        materialId: material.material.id ?? 'material-$index',
        materialType: material.material.type.toJson(),
        position: index,
      ),
    );
    GoRouter.of(context).go(target);
  }

  void _handleGuideTap(ShopGuideLink link) {
    _trackEvent(ShopGuideTappedEvent(guideId: link.id));
    GoRouter.of(context).go(link.targetRoute);
  }

  void _trackEvent(AppAnalyticsEvent event) {
    final gates = ref.container.read(appExperienceGatesProvider);
    final enriched = switch (event) {
      ShopCategoryTappedEvent _ => event.copyWith(
        persona: gates.personaKey,
        locale: gates.localeTag,
      ),
      ShopPromotionTappedEvent _ => event.copyWith(
        persona: gates.personaKey,
        locale: gates.localeTag,
      ),
      ShopMaterialTappedEvent _ => event.copyWith(
        persona: gates.personaKey,
        locale: gates.localeTag,
      ),
      ShopGuideTappedEvent _ => event.copyWith(
        persona: gates.personaKey,
        locale: gates.localeTag,
      ),
      _ => event,
    };

    unawaited(ref.container.read(analyticsClientProvider).track(enriched));
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.lg),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.8),
              colorScheme.secondaryContainer.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1400&q=60',
            ),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            colorFilter: ColorFilter.mode(Colors.black26, BlendMode.darken),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(
                      label: Text(l10n.shopHeroBadge),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.12),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      l10n.shopHeroTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tokens.colors.onPrimary,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      l10n.shopHeroBody,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onPrimary.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.shopHeroAction),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ShopCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = category.accent ?? colorScheme.primaryContainer;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Ink.image(
                image: NetworkImage(category.imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.35),
                  BlendMode.darken,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.35),
                      colorScheme.surface.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(category.icon, color: tokens.colors.onPrimary),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: tokens.colors.onPrimary,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (category.badge != null) ...[
                    Chip(
                      label: Text(category.badge!),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: tokens.colors.onPrimary.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.xs),
                  ],
                  Text(
                    category.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.colors.onPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    category.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onPrimary.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.item,
    required this.colorScheme,
    required this.onTap,
  });

  final ShopPromotionHighlight item;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final badgeColor = item.limitedTime
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    return Card(
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
            ),
            Padding(
              padding: EdgeInsets.all(tokens.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: tokens.spacing.xs,
                    runSpacing: tokens.spacing.xs,
                    children: [
                      Chip(
                        label: Text(item.badge),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: badgeColor.withValues(alpha: 0.9),
                      ),
                      if (item.discountPercent != null)
                        Chip(
                          avatar: const Icon(Icons.percent, size: 18),
                          label: Text('-${item.discountPercent}%'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.12),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.9,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(item.actionLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onPrimaryContainer,
                      foregroundColor: colorScheme.primary,
                    ),
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

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.highlight,
    required this.colorScheme,
    required this.onTap,
  });

  final ShopMaterialHighlight highlight;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final material = highlight.material;
    final photo =
        material.photos.firstOrNull ??
        'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1000&q=60';
    final priceLabel = _formatMoney(highlight.startingPrice);

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.sm),
            child: Container(
              width: 96,
              height: 96,
              color: colorScheme.surfaceContainerHigh,
              child: Image.network(photo, fit: BoxFit.cover),
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (highlight.badge != null) ...[
                      Chip(
                        label: Text(highlight.badge!),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                      SizedBox(width: tokens.spacing.xs),
                    ],
                    Chip(
                      label: Text(material.type.toJson()),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  material.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  highlight.tagline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: tokens.spacing.xs),
                    Text(
                      highlight.leadTimeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.xs),
                Row(
                  children: [
                    Text(
                      priceLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.sm),
                    Text(
                      '〜',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (highlight.recommendationReason != null)
                      Text(
                        highlight.recommendationReason!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(Money money) {
    final digits = money.amount.abs().toString();
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final prefix = money.currency.toUpperCase() == 'JPY'
        ? '¥'
        : '${money.currency} ';
    return '$prefix$formatted';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
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
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton({
    required this.itemWidth,
    required this.itemHeight,
  });

  final double itemWidth;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.sm),
      itemBuilder: (context, index) {
        return Container(
          width: itemWidth,
          height: itemHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(tokens.radii.md),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeletonBlock(width: 80, height: 16),
              SizedBox(height: tokens.spacing.sm),
              const AppSkeletonBlock(height: 16),
              SizedBox(height: tokens.spacing.xs),
              AppSkeletonBlock(width: itemWidth * 0.6, height: 14),
              const Spacer(),
              AppSkeletonBlock(width: itemWidth * 0.5, height: 28),
            ],
          ),
        );
      },
    );
  }
}

class _CategorySkeletonGrid extends StatelessWidget {
  const _CategorySkeletonGrid({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: tokens.spacing.sm,
        crossAxisSpacing: tokens.spacing.sm,
        childAspectRatio: 1.2,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(tokens.radii.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeletonBlock(width: 28, height: 28),
            const Spacer(),
            const AppSkeletonBlock(height: 16),
            SizedBox(height: tokens.spacing.xs),
            const AppSkeletonBlock(width: 120, height: 14),
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
            l10n.commonLoadFailed,
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
