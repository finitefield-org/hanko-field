import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/routing/app_state.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/shop/application/shop_home_controller.dart';
import 'package:app/features/shop/domain/shop_home_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopHomeScreen extends ConsumerStatefulWidget {
  const ShopHomeScreen({super.key});

  @override
  ConsumerState<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends ConsumerState<ShopHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(analyticsControllerProvider.notifier);
      unawaited(
        analytics.logScreenView(
          const ScreenViewAnalyticsEvent(
            screenName: 'shop_home',
            screenClass: 'ShopHomeScreen',
          ),
        ),
      );
    });
  }

  Future<void> _handleRefresh() async {
    await ref.read(shopHomeControllerProvider.notifier).reload();
  }

  void _openDestination(ShopDestination destination) {
    final notifier = ref.read(appStateProvider.notifier);
    final AppState currentState = ref.read(appStateProvider);
    final AppTab? overrideTab = destination.overrideTab;
    if (overrideTab != null && overrideTab != currentState.currentTab) {
      notifier.selectTab(overrideTab);
      Future.microtask(() => notifier.push(destination.route));
      return;
    }
    notifier.push(destination.route);
  }

  void _onCategoryTap(ShopCategory category, int index) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        ShopCategorySelectedEvent(categoryId: category.id, position: index),
      ),
    );
    _openDestination(category.destination);
  }

  void _onPromotionTap(ShopPromotion promotion, int index) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        ShopPromotionTappedEvent(promotionId: promotion.id, position: index),
      ),
    );
    _openDestination(promotion.destination);
  }

  void _onMaterialTap(ShopMaterialRecommendation material, int index) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        ShopMaterialSelectedEvent(materialId: material.id, position: index),
      ),
    );
    _openDestination(material.destination);
  }

  void _onGuideTap(ShopGuideLink guide, int index) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        ShopGuideLinkTappedEvent(linkId: guide.id, position: index),
      ),
    );
    _openDestination(guide.destination);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(shopHomeControllerProvider);
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      displacement: 64,
      child: asyncState.when(
        data: (state) => _ShopHomeContent(
          state: state,
          onCategoryTap: _onCategoryTap,
          onPromotionTap: _onPromotionTap,
          onMaterialTap: _onMaterialTap,
          onGuideTap: _onGuideTap,
        ),
        loading: () => const _ShopHomeLoading(),
        error: (error, stackTrace) => _ShopHomeError(
          message: 'ショップ情報の読み込みに失敗しました。',
          onRetry: _handleRefresh,
        ),
      ),
    );
  }
}

class _ShopHomeContent extends StatelessWidget {
  const _ShopHomeContent({
    required this.state,
    required this.onCategoryTap,
    required this.onPromotionTap,
    required this.onMaterialTap,
    required this.onGuideTap,
  });

  final ShopHomeState state;
  final void Function(ShopCategory category, int index) onCategoryTap;
  final void Function(ShopPromotion promotion, int index) onPromotionTap;
  final void Function(ShopMaterialRecommendation material, int index)
  onMaterialTap;
  final void Function(ShopGuideLink guide, int index) onGuideTap;

  ExperienceGate get experience => state.context.experience;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstPromotion = state.promotions.isNotEmpty
        ? state.promotions.first
        : null;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.spaceM)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            child: _HeroBanner(
              experience: experience,
              promotion: firstPromotion,
              onPromotionTap: firstPromotion != null
                  ? () => onPromotionTap(firstPromotion, 0)
                  : null,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTokens.spaceL)),
        if (state.guides.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'ガイドで予習',
                    subtitle: experience.isDomestic
                        ? '素材の違いや登録までの流れを短時間でキャッチアップ'
                        : 'Learn etiquette and care tips with bilingual explainers',
                  ),
                  const SizedBox(height: AppTokens.spaceM),
                  Wrap(
                    spacing: AppTokens.spaceM,
                    runSpacing: AppTokens.spaceS,
                    children: [
                      for (var index = 0; index < state.guides.length; index++)
                        ActionChip(
                          avatar: Icon(state.guides[index].icon, size: 18),
                          label: Text(state.guides[index].label),
                          onPressed: () =>
                              onGuideTap(state.guides[index], index),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (state.guides.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: AppTokens.spaceL)),
        if (state.categories.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(
                title: '素材・カテゴリから探す',
                subtitle: experience.isDomestic
                    ? '${experience.currencySymbol}${experience.currencyCode} 表記で人気順に表示'
                    : 'Trending categories tailored for international orders',
              ),
            ),
          ),
        if (state.categories.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceM,
              AppTokens.spaceL,
              0,
            ),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = state.categories[index];
                return _CategoryCard(
                  category: category,
                  onTap: () => onCategoryTap(category, index),
                );
              }, childCount: state.categories.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppTokens.spaceM,
                mainAxisSpacing: AppTokens.spaceM,
                childAspectRatio: 0.82,
              ),
            ),
          ),
        if (state.promotions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceXL,
                AppTokens.spaceL,
                AppTokens.spaceM,
              ),
              child: _SectionHeader(
                title: '注目のキャンペーン',
                subtitle: experience.isDomestic
                    ? 'オンライン限定特典や先行予約をチェック'
                    : 'Limited-time offers with international shipping support',
              ),
            ),
          ),
        if (state.promotions.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceL,
                ),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final promotion = state.promotions[index];
                  return SizedBox(
                    width: 280,
                    child: _PromotionCard(
                      promotion: promotion,
                      colorScheme: scheme,
                      onTap: () => onPromotionTap(promotion, index),
                    ),
                  );
                },
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppTokens.spaceM),
                itemCount: state.promotions.length,
              ),
            ),
          ),
        if (state.materials.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceXL,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'おすすめ素材',
                subtitle: experience.isDomestic
                    ? '耐久性や用途に合わせてプロが厳選'
                    : 'Curated picks with care instructions for overseas use',
              ),
            ),
          ),
        if (state.materials.isNotEmpty)
          SliverList.builder(
            itemCount: state.materials.length,
            itemBuilder: (context, index) {
              final material = state.materials[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  index == 0 ? AppTokens.spaceM : AppTokens.spaceS,
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                ),
                child: _MaterialCard(
                  material: material,
                  onTap: () => onMaterialTap(material, index),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: AppTokens.spaceXL * 2),
        ),
      ],
    );
  }
}

class _ShopHomeLoading extends StatelessWidget {
  const _ShopHomeLoading();

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _ShopHomeError extends StatelessWidget {
  const _ShopHomeError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXL,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceL),
                ElevatedButton.icon(
                  onPressed: () {
                    unawaited(onRetry());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.experience,
    this.promotion,
    this.onPromotionTap,
  });

  final ExperienceGate experience;
  final ShopPromotion? promotion;
  final VoidCallback? onPromotionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      variant: AppCardVariant.filled,
      backgroundColor: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ショップ',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            experience.isDomestic
                ? '国内向け素材と${experience.currencyCode}価格でショッピング。'
                : 'Browse curated materials with international support and pricing.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTokens.spaceL),
          Wrap(
            spacing: AppTokens.spaceM,
            runSpacing: AppTokens.spaceS,
            children: [
              ActionChip(
                avatar: const Icon(Icons.campaign_outlined, size: 18),
                label: Text(promotion != null ? '最新キャンペーンを見る' : 'キャンペーン情報'),
                onPressed: onPromotionTap,
              ),
              Chip(
                avatar: const Icon(Icons.currency_exchange_outlined, size: 18),
                label: Text(
                  experience.isDomestic
                      ? '通貨: ${experience.currencySymbol}${experience.currencyCode}'
                      : 'Currency: ${experience.currencySymbol} (${experience.currencyCode})',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.flight_takeoff_outlined, size: 18),
                label: Text(
                  experience.isDomestic ? '国内配送対応' : 'International shipping',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXS),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: variant),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, this.onTap});

  final ShopCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.filled,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusL.copyWith(
              bottomLeft: Radius.zero,
              bottomRight: Radius.zero,
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(category.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  category.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.promotion,
    required this.colorScheme,
    this.onTap,
  });

  final ShopPromotion promotion;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusL.copyWith(
              bottomLeft: Radius.zero,
              bottomRight: Radius.zero,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(promotion.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (promotion.badgeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceS,
                        vertical: AppTokens.spaceXS,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusM.topLeft.x,
                        ),
                      ),
                      child: Text(
                        promotion.badgeLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  if (promotion.badgeLabel != null)
                    const SizedBox(height: AppTokens.spaceS),
                  Text(
                    promotion.headline,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    promotion.subheading,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(promotion.ctaLabel),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(0, 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, this.onTap});

  final ShopMaterialRecommendation material;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppTokens.radiusM,
            child: Image.network(
              material.imageUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  material.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Wrap(
                  spacing: AppTokens.spaceM,
                  runSpacing: AppTokens.spaceXS,
                  children: [
                    _InfoChip(
                      icon: Icons.place_outlined,
                      label: material.origin,
                    ),
                    _InfoChip(
                      icon: Icons.auto_fix_high_outlined,
                      label: material.hardness,
                    ),
                    _InfoChip(
                      icon: Icons.sell_outlined,
                      label: material.priceLabel,
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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceS,
        vertical: AppTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppTokens.radiusM,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: AppTokens.spaceXS),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
