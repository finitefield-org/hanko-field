// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/view_model/product_detail_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  late final PageController _galleryController;
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final detail = ref.watch(
      ProductDetailViewModel(productId: widget.productId),
    );
    final data = detail.valueOrNull;
    final variant = data?.selectedVariant;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: switch (detail) {
          AsyncError(:final error) when data == null => _ErrorState(
            error: error,
            prefersEnglish: prefersEnglish,
            onRetry: _refresh,
          ),
          AsyncLoading() when data == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 4, itemHeight: 140),
          ),
          _ => RefreshIndicator.adaptive(
            onRefresh: _refresh,
            edgeOffset: tokens.spacing.md,
            displacement: tokens.spacing.xl,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (data != null && variant != null)
                  _ProductAppBar(
                    title: data.title,
                    heroImage: variant.heroImage ?? variant.gallery.first,
                    ribbon: data.ribbon,
                    favorite: data.isFavorite,
                    prefersEnglish: prefersEnglish,
                    onFavoritePressed: () => ref.invoke(
                      ProductDetailViewModel(
                        productId: widget.productId,
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
                    child: data == null || variant == null
                        ? const AppListSkeleton(items: 4, itemHeight: 140)
                        : _ProductDetailBody(
                            data: data,
                            variant: variant,
                            prefersEnglish: prefersEnglish,
                            galleryController: _galleryController,
                            galleryIndex: _galleryIndex,
                            onGalleryChanged: (index) =>
                                setState(() => _galleryIndex = index),
                            onSizeChanged: (size) => ref.invoke(
                              ProductDetailViewModel(
                                productId: widget.productId,
                              ).selectVariantBySize(size),
                            ),
                            onMaterialChanged: (material) => ref.invoke(
                              ProductDetailViewModel(
                                productId: widget.productId,
                              ).selectVariantByMaterial(material),
                            ),
                            onDesignChanged: (design) => ref.invoke(
                              ProductDetailViewModel(
                                productId: widget.productId,
                              ).selectDesign(design),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
      bottomNavigationBar: data == null || variant == null
          ? null
          : _ActionBar(
              prefersEnglish: prefersEnglish,
              selectedDesign: data.designOptions
                  .firstWhere(
                    (opt) => opt.id == data.selectedDesignId,
                    orElse: () => data.designOptions.first,
                  )
                  .label,
              onSave: () => _showSnack(
                prefersEnglish
                    ? 'Saved to library (mock)'
                    : 'ライブラリに保存しました（モック）',
              ),
              onAddToCart: () => _showSnack(
                prefersEnglish
                    ? 'Added ${variant.sku} with design ${data.selectedDesignId} (mock)'
                    : '${variant.sku} をデザイン ${data.selectedDesignId} でカートに追加しました（モック）',
              ),
              disabled: data.selectedDesignId == 'select-later',
            ),
    );
  }

  Future<void> _refresh() async {
    await ref.refreshValue(
      ProductDetailViewModel(productId: widget.productId),
      keepPrevious: true,
    );
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProductAppBar extends StatelessWidget {
  const _ProductAppBar({
    required this.title,
    required this.heroImage,
    required this.ribbon,
    required this.favorite,
    required this.prefersEnglish,
    required this.onFavoritePressed,
  });

  final String title;
  final String heroImage;
  final String? ribbon;
  final bool favorite;
  final bool prefersEnglish;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SliverAppBar.large(
      pinned: true,
      stretch: true,
      expandedHeight: 320,
      backgroundColor: tokens.colors.surface,
      title: Text(title),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              heroImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: tokens.colors.surfaceVariant,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            if (ribbon != null)
              Positioned(
                left: tokens.spacing.lg,
                bottom: tokens.spacing.lg,
                child: Chip(
                  label: Text(
                    ribbon!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tokens.colors.onPrimary,
                    ),
                  ),
                  backgroundColor: tokens.colors.primary,
                ),
              ),
          ],
        ),
      ),
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

class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({
    required this.data,
    required this.variant,
    required this.prefersEnglish,
    required this.galleryController,
    required this.galleryIndex,
    required this.onGalleryChanged,
    required this.onSizeChanged,
    required this.onMaterialChanged,
    required this.onDesignChanged,
  });

  final ProductDetailState data;
  final ProductVariant variant;
  final bool prefersEnglish;
  final PageController galleryController;
  final int galleryIndex;
  final ValueChanged<int> onGalleryChanged;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<String> onMaterialChanged;
  final ValueChanged<String> onDesignChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final sizeOptions = data.variants.map((v) => v.sizeMm).toSet().toList()
      ..sort();
    final materialOptions = <String, String>{};
    for (final item in data.variants) {
      materialOptions.putIfAbsent(item.materialRef, () => item.materialLabel);
    }
    final selectedDesign = data.designOptions.firstWhere(
      (opt) => opt.id == data.selectedDesignId,
      orElse: () => data.designOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.tagline, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.xs,
          runSpacing: tokens.spacing.xs,
          children: [
            ...variant.badges.map(
              (badge) => Chip(
                label: Text(badge),
                visualDensity: VisualDensity.compact,
                backgroundColor: tokens.colors.surfaceVariant,
              ),
            ),
            Chip(
              label: Text(
                prefersEnglish
                    ? '${variant.sizeMm.toStringAsFixed(0)}mm'
                    : '直径 ${variant.sizeMm}mm',
              ),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              label: Text(variant.materialLabel),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        _GalleryCarousel(
          gallery: variant.gallery,
          controller: galleryController,
          currentIndex: galleryIndex,
          prefersEnglish: prefersEnglish,
          onPageChanged: onGalleryChanged,
        ),
        SizedBox(height: tokens.spacing.lg),
        _VariantSelectorCard(
          variant: variant,
          prefersEnglish: prefersEnglish,
          sizeOptions: sizeOptions,
          materialOptions: materialOptions,
          onSizeChanged: sizeOptions.length <= 1
              ? null
              : (size) => onSizeChanged(size),
          onMaterialChanged: materialOptions.length <= 1
              ? null
              : (material) => onMaterialChanged(material),
        ),
        SizedBox(height: tokens.spacing.lg),
        _PricingCard(variant: variant, prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.lg),
        _StockCard(variant: variant, prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.lg),
        _DesignCard(
          productId: data.productId,
          options: data.designOptions,
          selected: selectedDesign,
          prefersEnglish: prefersEnglish,
          onChanged: onDesignChanged,
        ),
        if (variant.perks.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.lg),
          _PerksCard(perks: variant.perks, prefersEnglish: prefersEnglish),
        ],
      ],
    );
  }
}

class _GalleryCarousel extends StatelessWidget {
  const _GalleryCarousel({
    required this.gallery,
    required this.controller,
    required this.currentIndex,
    required this.prefersEnglish,
    required this.onPageChanged,
  });

  final List<String> gallery;
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
          height: 240,
          child: PageView.builder(
            controller: controller,
            itemCount: gallery.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final url = gallery[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == gallery.length - 1 ? 0 : tokens.spacing.md,
                ),
                child: Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: tokens.colors.surfaceVariant,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                      Positioned(
                        left: tokens.spacing.md,
                        bottom: tokens.spacing.md,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(
                              tokens.radii.sm,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.sm,
                              vertical: tokens.spacing.xs,
                            ),
                            child: Text(
                              prefersEnglish
                                  ? 'Tap to zoom · swipe'
                                  : 'タップで拡大・スワイプ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                gallery.length,
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
              prefersEnglish ? 'Swipe gallery' : 'ギャラリーをスワイプ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _VariantSelectorCard extends StatelessWidget {
  const _VariantSelectorCard({
    required this.variant,
    required this.prefersEnglish,
    required this.sizeOptions,
    required this.materialOptions,
    required this.onSizeChanged,
    required this.onMaterialChanged,
  });

  final ProductVariant variant;
  final bool prefersEnglish;
  final List<double> sizeOptions;
  final Map<String, String> materialOptions;
  final ValueChanged<double>? onSizeChanged;
  final ValueChanged<String>? onMaterialChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prefersEnglish ? 'Variants' : 'バリエーション',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                variant.sku,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: [
              _Pill(
                icon: variant.isRound
                    ? Icons.radio_button_unchecked
                    : Icons.crop_square,
                label: variant.isRound
                    ? (prefersEnglish ? 'Round' : '丸印')
                    : (prefersEnglish ? 'Square' : '角印'),
              ),
              _Pill(
                icon: Icons.straighten,
                label: '${variant.sizeMm.toStringAsFixed(0)}mm',
              ),
              _Pill(icon: Icons.layers_outlined, label: variant.materialLabel),
              _Pill(icon: Icons.texture, label: variant.finishLabel),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          if (sizeOptions.length > 1) ...[
            Text(prefersEnglish ? 'Size' : 'サイズ'),
            SizedBox(height: tokens.spacing.xs),
            SegmentedButton<double>(
              segments: sizeOptions
                  .map(
                    (size) => ButtonSegment(
                      value: size,
                      label: Text('${size.toStringAsFixed(0)}mm'),
                      icon: const Icon(Icons.straighten),
                    ),
                  )
                  .toList(),
              selected: {variant.sizeMm},
              showSelectedIcon: false,
              onSelectionChanged: onSizeChanged == null
                  ? null
                  : (values) => onSizeChanged!(values.first),
            ),
            SizedBox(height: tokens.spacing.sm),
          ],
          if (materialOptions.length > 1) ...[
            Text(prefersEnglish ? 'Material' : '素材'),
            SizedBox(height: tokens.spacing.xs),
            SegmentedButton<String>(
              segments: materialOptions.entries
                  .map(
                    (entry) => ButtonSegment(
                      value: entry.key,
                      label: Text(entry.value),
                      icon: const Icon(Icons.layers_outlined),
                    ),
                  )
                  .toList(),
              selected: {variant.materialRef},
              showSelectedIcon: false,
              onSelectionChanged: onMaterialChanged == null
                  ? null
                  : (values) => onMaterialChanged!(values.first),
            ),
          ],
          if (variant.designHint != null) ...[
            SizedBox(height: tokens.spacing.sm),
            Text(
              variant.designHint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.variant, required this.prefersEnglish});

  final ProductVariant variant;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final sale = variant.salePrice;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formatMoney(sale ?? variant.basePrice),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: tokens.colors.primary,
                ),
              ),
              SizedBox(width: tokens.spacing.sm),
              if (sale != null)
                Text(
                  _formatMoney(variant.basePrice),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(variant.leadTimeLabel),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish ? 'Pricing tiers (per piece)' : '価格帯（1本あたり）',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.xs),
          Column(
            children: variant.priceTiers
                .map(
                  (tier) => Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tier.label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          _formatMoney(tier.unitPrice),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SizedBox(width: tokens.spacing.sm),
                        Text(
                          '×${tier.minQuantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (tier.badge != null) ...[
                          SizedBox(width: tokens.spacing.sm),
                          InputChip(
                            label: Text(tier.badge!),
                            onSelected: (_) {},
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.variant, required this.prefersEnglish});

  final ProductVariant variant;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final stock = variant.stock;
    final color = switch (stock.level) {
      StockBadgeLevel.good => tokens.colors.success,
      StockBadgeLevel.warning => tokens.colors.warning,
      StockBadgeLevel.preorder => tokens.colors.secondary,
    };
    final ratio = _stockProgress(stock);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: color),
                  SizedBox(width: tokens.spacing.sm),
                  Text(
                    stock.statusLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: color),
                  ),
                ],
              ),
              Text(
                stock.windowLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          if (ratio != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.sm),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: tokens.colors.surfaceVariant.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            _stockLabel(stock, prefersEnglish),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (stock.note != null) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              stock.note!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _stockProgress(ProductStockInfo stock) {
    if (stock.availableQuantity == null || stock.safetyStock == null) {
      return null;
    }
    final total = (stock.availableQuantity! + stock.safetyStock!).toDouble();
    if (total <= 0) return null;
    return (stock.availableQuantity! / total).clamp(0, 1).toDouble();
  }

  String _stockLabel(ProductStockInfo stock, bool prefersEnglish) {
    final qty = stock.availableQuantity;
    if (qty == null) return prefersEnglish ? 'Made to order' : '受注生産';
    final safety = stock.safetyStock ?? 0;
    if (qty <= safety) {
      return prefersEnglish ? 'Low: $qty left' : '残り$qty本';
    }
    return prefersEnglish ? '$qty in queue' : '$qty本の在庫';
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.productId,
    required this.options,
    required this.selected,
    required this.prefersEnglish,
    required this.onChanged,
  });

  final String productId;
  final List<DesignOption> options;
  final DesignOption selected;
  final bool prefersEnglish;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                prefersEnglish ? 'Design selection' : 'デザイン選択',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () => router.go(AppRoutePaths.designStyle),
                icon: const Icon(Icons.brush_outlined),
                label: Text(prefersEnglish ? 'Open designer' : 'デザインを開く'),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(
                      option.badge != null
                          ? '${option.label} · ${option.badge}'
                          : option.label,
                    ),
                    selected: selected.id == option.id,
                    onSelected: (_) => onChanged(option.id),
                    avatar: option.badge != null
                        ? const Icon(Icons.check_circle, size: 16)
                        : null,
                  ),
                )
                .toList(),
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            selected.badge ??
                (prefersEnglish
                    ? 'Add-ons available after adding to cart.'
                    : 'カート追加後にオプションを選べます。'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => router.go(
                AppRoutePaths.productAddons.replaceFirst(
                  ':productId',
                  productId,
                ),
              ),
              icon: const Icon(Icons.extension_outlined),
              label: Text(prefersEnglish ? 'View add-ons' : 'オプションを見る'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerksCard extends StatelessWidget {
  const _PerksCard({required this.perks, required this.prefersEnglish});

  final List<String> perks;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Included perks' : '付属内容',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: perks
                .map(
                  (perk) => InputChip(
                    avatar: const Icon(Icons.check_circle_outline),
                    label: Text(perk),
                    onSelected: (_) {},
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          SizedBox(width: tokens.spacing.xs),
          Text(label),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.prefersEnglish,
    required this.selectedDesign,
    required this.onAddToCart,
    required this.onSave,
    this.disabled = false,
  });

  final bool prefersEnglish;
  final String selectedDesign;
  final VoidCallback onAddToCart;
  final VoidCallback onSave;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.sm,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish
                  ? 'Design: $selectedDesign'
                  : 'デザイン: $selectedDesign',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: prefersEnglish ? 'Add to cart' : 'カートに追加',
                    onPressed: disabled ? null : onAddToCart,
                    trailing: const Icon(Icons.add_shopping_cart_outlined),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                TextButton(
                  onPressed: onSave,
                  child: Text(prefersEnglish ? 'Save to library' : 'ライブラリへ保存'),
                ),
              ],
            ),
            if (disabled) ...[
              SizedBox(height: tokens.spacing.xs),
              Text(
                prefersEnglish
                    ? 'Select a design to continue'
                    : 'デザインを選択してください',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.colors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.prefersEnglish,
    required this.onRetry,
  });

  final Object error;
  final bool prefersEnglish;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.colors.error),
            SizedBox(height: tokens.spacing.md),
            Text(
              prefersEnglish ? 'Failed to load product' : '商品を読み込めませんでした',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.md),
            AppButton(
              label: prefersEnglish ? 'Retry' : '再試行',
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }
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
