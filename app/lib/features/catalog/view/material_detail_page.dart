// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart'
    as catalog;
import 'package:app/features/catalog/view_model/material_detail_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class MaterialDetailPage extends ConsumerStatefulWidget {
  const MaterialDetailPage({super.key, required this.materialId});

  final String materialId;

  @override
  ConsumerState<MaterialDetailPage> createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends ConsumerState<MaterialDetailPage> {
  late final PageController _pageController;
  int _mediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final detail = ref.watch(
      MaterialDetailViewModel(materialId: widget.materialId),
    );
    final data = detail.valueOrNull;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: switch (detail) {
          AsyncError(:final error) when data == null => _ErrorState(
            error: error,
            prefersEnglish: prefersEnglish,
            onRetry: () => ref.refreshValue(
              MaterialDetailViewModel(materialId: widget.materialId),
              keepPrevious: true,
            ),
          ),
          AsyncLoading() when data == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 4, itemHeight: 120),
          ),
          _ => RefreshIndicator.adaptive(
            displacement: tokens.spacing.xl,
            edgeOffset: tokens.spacing.md,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (data != null)
                  _MaterialAppBar(
                    title: data.material.name,
                    favorite: data.isFavorite,
                    prefersEnglish: prefersEnglish,
                    onFavoritePressed: () => ref.invoke(
                      MaterialDetailViewModel(
                        materialId: widget.materialId,
                      ).toggleFavorite(),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.lg,
                      tokens.spacing.md,
                      tokens.spacing.lg,
                      tokens.spacing.xxl,
                    ),
                    child: data == null
                        ? const AppListSkeleton(items: 3, itemHeight: 160)
                        : _MaterialDetailBody(
                            data: data,
                            prefersEnglish: prefersEnglish,
                            mediaIndex: _mediaIndex,
                            pageController: _pageController,
                            onMediaChanged: (index) =>
                                setState(() => _mediaIndex = index),
                          ),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
      bottomNavigationBar: data == null
          ? null
          : _ActionRail(
              prefersEnglish: prefersEnglish,
              onShare: () => _showSnack(
                prefersEnglish
                    ? 'Share sheet opened (mock)'
                    : '共有シートを開きました（モック）',
              ),
              onStartOrder: () => context.go(AppRoutePaths.cart),
            ),
    );
  }

  Future<void> _refresh() async {
    await ref.refreshValue(
      MaterialDetailViewModel(materialId: widget.materialId),
      keepPrevious: true,
    );
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MaterialAppBar extends StatelessWidget {
  const _MaterialAppBar({
    required this.title,
    required this.favorite,
    required this.prefersEnglish,
    required this.onFavoritePressed,
  });

  final String title;
  final bool favorite;
  final bool prefersEnglish;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SliverAppBar.medium(
      pinned: true,
      backgroundColor: tokens.colors.surface,
      title: Text(title),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'Favorite' : 'お気に入り',
          onPressed: onFavoritePressed,
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    );
  }
}

class _MaterialDetailBody extends StatelessWidget {
  const _MaterialDetailBody({
    required this.data,
    required this.prefersEnglish,
    required this.mediaIndex,
    required this.pageController,
    required this.onMediaChanged,
  });

  final MaterialDetailState data;
  final bool prefersEnglish;
  final int mediaIndex;
  final PageController pageController;
  final ValueChanged<int> onMediaChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;
    final material = data.material;
    final chips = <String>[
      data.surfaceFinish,
      if (material.finish != null)
        _finishLabel(material.finish, prefersEnglish),
      if (material.color != null) material.color!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.tagline, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.xs,
          runSpacing: tokens.spacing.xs,
          children: chips
              .map(
                (chip) => Chip(
                  label: Text(chip),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: tokens.colors.surfaceVariant,
                ),
              )
              .toList(),
        ),
        SizedBox(height: tokens.spacing.lg),
        _GalleryCard(
          media: data.media,
          controller: pageController,
          currentIndex: mediaIndex,
          prefersEnglish: prefersEnglish,
          onPageChanged: onMediaChanged,
        ),
        SizedBox(height: tokens.spacing.lg),
        _SpecsCard(data: data, prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.lg),
        AppCard(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish ? 'Compatible products' : '対応する商品',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: data.compatibleProductRefs
                    .map(
                      (id) => ActionChip(
                        avatar: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                        ),
                        label: Text(id),
                        onPressed: () => navigation.go('/products/$id'),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: tokens.spacing.md),
              TextButton.icon(
                onPressed: () => navigation.go(
                  '/products/${data.compatibleProductRefs.first}',
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  prefersEnglish ? 'View product detail' : '商品の詳細を見る',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.media,
    required this.controller,
    required this.currentIndex,
    required this.prefersEnglish,
    required this.onPageChanged,
  });

  final List<MaterialMedia> media;
  final PageController controller;
  final int currentIndex;
  final bool prefersEnglish;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final radius = BorderRadius.circular(tokens.radii.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: media.length,
            itemBuilder: (context, index) {
              final item = media[index];
              final messenger = ScaffoldMessenger.of(context);
              return Padding(
                padding: EdgeInsets.only(
                  right: index == media.length - 1 ? 0 : tokens.spacing.md,
                ),
                child: Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  child: InkWell(
                    onTap: item.type == MaterialMediaType.video
                        ? () {
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  prefersEnglish
                                      ? 'Playing video preview (mock)'
                                      : '動画プレビューを再生します（モック）',
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 3,
                            child: _MediaContent(item: item),
                          ),
                        ),
                        if (item.caption != null)
                          Positioned(
                            left: tokens.spacing.md,
                            right: tokens.spacing.md,
                            bottom: tokens.spacing.md,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(
                                  tokens.radii.sm,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(tokens.spacing.sm),
                                child: Text(
                                  item.caption!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        if (item.type == MaterialMediaType.video)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.45),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 64,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: tokens.spacing.xs,
              children: List.generate(
                media.length,
                (index) => AnimatedContainer(
                  duration: tokens.durations.fast,
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == currentIndex
                        ? tokens.colors.primary
                        : tokens.colors.outline.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Text(
              prefersEnglish ? 'Pinch to zoom · swipe' : 'ピンチで拡大・スワイプで切替',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaContent extends StatelessWidget {
  const _MediaContent({required this.item});

  final MaterialMedia item;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      item.url,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
      },
    );
  }
}

class _SpecsCard extends StatelessWidget {
  const _SpecsCard({required this.data, required this.prefersEnglish});

  final MaterialDetailState data;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final material = data.material;
    final hardness = material.hardness != null
        ? material.hardness!.toStringAsFixed(1)
        : '-';
    final density = material.density != null
        ? material.density!.toStringAsFixed(2)
        : '-';

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: Text(
              prefersEnglish ? 'Specs & availability' : '仕様と在庫',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.science_outlined),
            title: Text(prefersEnglish ? 'Hardness' : '硬度'),
            subtitle: Text(prefersEnglish ? 'Mohs scale' : 'モース硬度'),
            trailing: _PillChip(label: hardness),
          ),
          Divider(height: tokens.spacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.texture),
            title: Text(prefersEnglish ? 'Texture' : '質感'),
            subtitle: Text(data.surfaceFinish),
            trailing: _PillChip(
              label: material.finish != null
                  ? _finishLabel(material.finish, prefersEnglish)
                  : (prefersEnglish ? 'Custom' : 'カスタム'),
            ),
          ),
          Divider(height: tokens.spacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.water_drop_outlined),
            title: Text(prefersEnglish ? 'Density' : '密度'),
            subtitle: Text(prefersEnglish ? 'g/cm3 (approx.)' : 'g/cm3 目安'),
            trailing: _PillChip(label: density),
          ),
          Divider(height: tokens.spacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(prefersEnglish ? 'Availability' : '在庫状況'),
            subtitle: Text(data.availability.windowLabel),
            trailing: Wrap(
              spacing: tokens.spacing.xs,
              runSpacing: tokens.spacing.xs,
              children: data.availability.badges
                  .map((badge) => _PillChip(label: badge))
                  .toList(),
            ),
          ),
          if (data.availability.note != null) ...[
            SizedBox(height: tokens.spacing.sm),
            Text(
              data.availability.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.prefersEnglish,
    required this.onShare,
    required this.onStartOrder,
  });

  final bool prefersEnglish;
  final VoidCallback onShare;
  final VoidCallback onStartOrder;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.md,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        decoration: BoxDecoration(
          color: tokens.colors.surface,
          border: Border(
            top: BorderSide(
              color: tokens.colors.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(prefersEnglish ? 'Share' : '共有'),
              ),
            ),
            SizedBox(width: tokens.spacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: onStartOrder,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(prefersEnglish ? 'Start order' : '注文を始める'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return RawChip(
      label: Text(label),
      pressElevation: 0,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      backgroundColor: tokens.colors.surfaceVariant,
      side: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.4)),
    );
  }
}

String _finishLabel(catalog.MaterialFinish? finish, bool prefersEnglish) {
  if (finish == null) return prefersEnglish ? 'Custom' : 'カスタム';
  return switch (finish) {
    catalog.MaterialFinish.matte => prefersEnglish ? 'Matte' : 'マット',
    catalog.MaterialFinish.gloss => prefersEnglish ? 'Gloss' : 'グロス',
    catalog.MaterialFinish.hairline => prefersEnglish ? 'Hairline' : 'ヘアライン',
  };
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.prefersEnglish,
    this.onRetry,
  });

  final Object error;
  final bool prefersEnglish;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: AppEmptyState(
        title: prefersEnglish ? 'Could not load material' : '素材を読み込めませんでした',
        message: error.toString(),
        icon: Icons.error_outline,
        actionLabel: onRetry == null
            ? null
            : (prefersEnglish ? 'Retry' : '再試行'),
        onAction: onRetry,
      ),
    );
  }
}
