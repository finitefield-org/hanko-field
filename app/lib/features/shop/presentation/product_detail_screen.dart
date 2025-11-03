import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/catalog.dart';
import 'package:app/features/shop/application/product_detail_provider.dart';
import 'package:app/features/shop/domain/product_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final Map<String, String> _selectedOptions = {};
  late final PageController _mediaController;
  int _currentMediaIndex = 0;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _mediaController = PageController();
  }

  @override
  void dispose() {
    _mediaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(productDetailProvider(widget.productId));
    final experienceAsync = ref.watch(experienceGateProvider);
    return experienceAsync.when(
      data: (experience) {
        return detailAsync.when(
          data: (detail) {
            _ensureOptionDefaults(detail);
            final selections = _effectiveSelections(detail);
            final selectedVariant =
                detail.findVariantByOptions(selections) ??
                detail.variants.first;
            final images = _variantImages(detail, selectedVariant);
            if (_currentMediaIndex >= images.length) {
              _currentMediaIndex = 0;
            }
            return _ProductDetailLoadedView(
              detail: detail,
              experience: experience,
              selectedVariant: selectedVariant,
              selectedOptions: selections,
              isFavorite: _favorite,
              mediaController: _mediaController,
              mediaIndex: _currentMediaIndex,
              onMediaChanged: _handleMediaChanged,
              onToggleFavorite: _toggleFavorite,
              onOptionSelected: _handleOptionSelected,
              images: images,
              onAddToCart: () =>
                  _handleAddToCart(context, selectedVariant, experience),
              onSecondaryAction: () => _handleSecondaryAction(
                context,
                detail,
                selectedVariant,
                experience,
              ),
            );
          },
          loading: () => const _ProductDetailLoadingView(),
          error: (error, stack) => _ProductDetailErrorView(
            onRetry: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
          ),
        );
      },
      loading: () => const _ProductDetailLoadingView(),
      error: (error, stack) => _ProductDetailErrorView(
        onRetry: () {
          ref.invalidate(experienceGateProvider);
          ref.invalidate(productDetailProvider(widget.productId));
        },
      ),
    );
  }

  void _handleMediaChanged(int index) {
    setState(() {
      _currentMediaIndex = index;
    });
  }

  void _toggleFavorite() {
    setState(() {
      _favorite = !_favorite;
    });
  }

  void _handleOptionSelected(String groupId, String optionId) {
    setState(() {
      _selectedOptions[groupId] = optionId;
      _currentMediaIndex = 0;
    });
    if (_mediaController.hasClients) {
      _mediaController.animateToPage(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleAddToCart(
    BuildContext context,
    ProductVariant variant,
    ExperienceGate experience,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final message = experience.isInternational
        ? 'Added "${variant.displayLabel}" to cart.'
        : '「${variant.displayLabel}」をカートに追加しました。';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSecondaryAction(
    BuildContext context,
    ProductDetail detail,
    ProductVariant variant,
    ExperienceGate experience,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final label = detail.requiresDesignSelection
        ? (experience.isInternational ? 'Select design' : 'デザイン選択')
        : (experience.isInternational ? 'Save to library' : 'ライブラリ保存');
    final separator = experience.isInternational ? ': ' : '：';
    messenger.showSnackBar(
      SnackBar(content: Text('$label$separator${variant.displayLabel}')),
    );
  }

  void _ensureOptionDefaults(ProductDetail detail) {
    var updated = false;
    for (final group in detail.variantGroups) {
      final current = _selectedOptions[group.id];
      final hasCurrent =
          current != null &&
          group.options.any((option) => option.id == current);
      if (!hasCurrent && group.options.isNotEmpty) {
        _selectedOptions[group.id] = group.options.first.id;
        updated = true;
      }
    }
    if (updated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Map<String, String> _effectiveSelections(ProductDetail detail) {
    final selections = <String, String>{};
    for (final group in detail.variantGroups) {
      selections[group.id] =
          _selectedOptions[group.id] ?? group.options.first.id;
    }
    return selections;
  }

  List<String> _variantImages(ProductDetail detail, ProductVariant variant) {
    if (variant.galleryImages.isNotEmpty) {
      return variant.galleryImages;
    }
    if (detail.baseProduct.photos.isNotEmpty) {
      return detail.baseProduct.photos;
    }
    return [variant.primaryImageUrl];
  }
}

class _ProductDetailLoadedView extends StatelessWidget {
  const _ProductDetailLoadedView({
    required this.detail,
    required this.experience,
    required this.selectedVariant,
    required this.selectedOptions,
    required this.isFavorite,
    required this.mediaController,
    required this.mediaIndex,
    required this.onMediaChanged,
    required this.onToggleFavorite,
    required this.onOptionSelected,
    required this.images,
    required this.onAddToCart,
    required this.onSecondaryAction,
  });

  final ProductDetail detail;
  final ExperienceGate experience;
  final ProductVariant selectedVariant;
  final Map<String, String> selectedOptions;
  final bool isFavorite;
  final PageController mediaController;
  final int mediaIndex;
  final ValueChanged<int> onMediaChanged;
  final VoidCallback onToggleFavorite;
  final void Function(String groupId, String optionId) onOptionSelected;
  final List<String> images;
  final VoidCallback onAddToCart;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(detail.name),
            actions: [
              IconButton(
                tooltip: isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: onToggleFavorite,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProductMediaCarousel(
                images: images,
                controller: mediaController,
                pageIndex: mediaIndex,
                onPageChanged: onMediaChanged,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (detail.badges.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: detail.badges
                          .map(
                            (badge) => Chip(
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              label: Text(
                                badge,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    detail.subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(detail.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  _ProductPriceSummary(
                    experience: experience,
                    variant: selectedVariant,
                  ),
                  const SizedBox(height: 12),
                  _ProductStockBanner(
                    variant: selectedVariant,
                    experience: experience,
                  ),
                  const SizedBox(height: 16),
                  if (detail.highlights.isNotEmpty)
                    _ProductHighlightSection(
                      highlights: detail.highlights,
                      experience: experience,
                    ),
                  const SizedBox(height: 16),
                  ...detail.variantGroups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _ProductVariantSelector(
                        group: group,
                        selectedOptionId: selectedOptions[group.id]!,
                        onSelected: (value) =>
                            onOptionSelected(group.id, value),
                      ),
                    ),
                  ),
                  _ProductPricingCard(
                    variant: selectedVariant,
                    experience: experience,
                  ),
                  const SizedBox(height: 20),
                  if (detail.specs.isNotEmpty)
                    _ProductSpecsSection(
                      detail: detail,
                      experience: experience,
                    ),
                  if (detail.includedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _ProductIncludedItems(
                        items: detail.includedItems,
                        experience: experience,
                      ),
                    ),
                  if (detail.careNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _ProductNoteCard(
                        icon: Icons.spa_outlined,
                        title: 'お手入れ',
                        body: detail.careNote!,
                      ),
                    ),
                  if (detail.shippingNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _ProductNoteCard(
                        icon: Icons.local_shipping_outlined,
                        title: experience.isInternational ? 'Shipping' : '配送',
                        body: detail.shippingNote!,
                      ),
                    ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ProductDetailActionBar(
        experience: experience,
        detail: detail,
        variant: selectedVariant,
        onAddToCart: onAddToCart,
        onSecondaryAction: onSecondaryAction,
      ),
    );
  }
}

class _ProductMediaCarousel extends StatelessWidget {
  const _ProductMediaCarousel({
    required this.images,
    required this.controller,
    required this.pageIndex,
    required this.onPageChanged,
  });

  final List<String> images;
  final PageController controller;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: controller,
            itemCount: images.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Image.network(images[index], fit: BoxFit.cover),
              );
            },
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  '${pageIndex + 1} / ${images.length}',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPriceSummary extends StatelessWidget {
  const _ProductPriceSummary({required this.experience, required this.variant});

  final ExperienceGate experience;
  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salePrice = variant.salePrice;
    final formattedPrice = _formatMoney(variant.price, experience);
    final formattedSale = salePrice != null
        ? _formatMoney(
            CatalogMoney(
              amount: salePrice.amount,
              currency: salePrice.currency,
            ),
            experience,
          )
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formattedSale ?? formattedPrice,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (formattedSale != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              formattedPrice,
              style: theme.textTheme.labelLarge?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductStockBanner extends StatelessWidget {
  const _ProductStockBanner({required this.variant, required this.experience});

  final ProductVariant variant;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (variant.stock.level) {
      ProductStockLevel.inStock => theme.colorScheme.tertiaryContainer,
      ProductStockLevel.limited => theme.colorScheme.errorContainer,
      ProductStockLevel.backorder => theme.colorScheme.secondaryContainer,
      ProductStockLevel.preorder => theme.colorScheme.secondaryContainer,
    };
    final onColor = switch (variant.stock.level) {
      ProductStockLevel.inStock => theme.colorScheme.onTertiaryContainer,
      ProductStockLevel.limited => theme.colorScheme.onErrorContainer,
      ProductStockLevel.backorder => theme.colorScheme.onSecondaryContainer,
      ProductStockLevel.preorder => theme.colorScheme.onSecondaryContainer,
    };
    final leadLabel = experience.isInternational
        ? 'Estimated lead time'
        : 'リードタイム';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            variant.stock.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (variant.stock.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              variant.stock.detail!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: onColor),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$leadLabel: ${variant.leadTime}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: onColor),
          ),
        ],
      ),
    );
  }
}

class _ProductHighlightSection extends StatelessWidget {
  const _ProductHighlightSection({
    required this.highlights,
    required this.experience,
  });

  final List<String> highlights;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = experience.isInternational ? 'Highlights' : '特長';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Column(
          children: highlights
              .map(
                (highlight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          highlight,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ProductVariantSelector extends StatelessWidget {
  const _ProductVariantSelector({
    required this.group,
    required this.selectedOptionId,
    required this.onSelected,
  });

  final ProductVariantGroup group;
  final String selectedOptionId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.label, style: titleStyle),
        const SizedBox(height: 8),
        switch (group.selectionType) {
          ProductVariantSelectionType.segmented => SegmentedButton<String>(
            segments: group.options
                .map(
                  (option) => ButtonSegment<String>(
                    value: option.id,
                    label: Text(option.label),
                    tooltip: option.helperText,
                  ),
                )
                .toList(),
            selected: {selectedOptionId},
            showSelectedIcon: false,
            onSelectionChanged: (values) {
              if (values.isNotEmpty) {
                onSelected(values.first);
              }
            },
          ),
          ProductVariantSelectionType.chip => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options
                .map(
                  (option) => FilterChip(
                    label: Text(option.label),
                    selected: selectedOptionId == option.id,
                    onSelected: (_) => onSelected(option.id),
                    avatar: option.helperText != null
                        ? const Icon(Icons.style_outlined, size: 18)
                        : null,
                  ),
                )
                .toList(),
          ),
        },
        if (group.selectionType == ProductVariantSelectionType.segmented)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              group.options
                      .firstWhere(
                        (option) => option.id == selectedOptionId,
                        orElse: () => group.options.first,
                      )
                      .helperText ??
                  '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductPricingCard extends StatelessWidget {
  const _ProductPricingCard({required this.variant, required this.experience});

  final ProductVariant variant;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              experience.isInternational ? 'Pricing tiers' : '価格帯',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...variant.pricingTiers.map((tier) {
              final range = _formatTierQuantity(tier);
              final price = _formatMoney(tier.price, experience);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(range, style: theme.textTheme.bodyLarge),
                          if (tier.note != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                tier.note!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          price,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (tier.savingsLabel != null)
                          Text(
                            tier.savingsLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProductSpecsSection extends StatelessWidget {
  const _ProductSpecsSection({required this.detail, required this.experience});

  final ProductDetail detail;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = experience.isInternational ? 'Specifications' : '仕様';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: detail.specs
                .map(
                  (spec) => ListTile(
                    title: Text(spec.label),
                    subtitle: spec.detail != null ? Text(spec.detail!) : null,
                    trailing: Text(
                      spec.value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ProductIncludedItems extends StatelessWidget {
  const _ProductIncludedItems({required this.items, required this.experience});

  final List<String> items;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = experience.isInternational ? 'Included items' : '同梱物';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 6, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductNoteCard extends StatelessWidget {
  const _ProductNoteCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailActionBar extends StatelessWidget {
  const _ProductDetailActionBar({
    required this.experience,
    required this.detail,
    required this.variant,
    required this.onAddToCart,
    required this.onSecondaryAction,
  });

  final ExperienceGate experience;
  final ProductDetail detail;
  final ProductVariant variant;
  final VoidCallback onAddToCart;
  final VoidCallback onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryLabel = experience.isInternational ? 'Add to cart' : 'カートに追加';
    final secondaryLabel = detail.requiresDesignSelection
        ? (experience.isInternational ? 'Select design' : 'デザインを選択')
        : (experience.isInternational ? 'Save to library' : 'ライブラリに保存');
    final priceLabel = _formatMoney(
      variant.salePrice != null
          ? CatalogMoney(
              amount: variant.salePrice!.amount,
              currency: variant.salePrice!.currency,
            )
          : variant.price,
      experience,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  experience.isInternational ? 'Current selection' : '選択中',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  priceLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: onAddToCart, child: Text(primaryLabel)),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailLoadingView extends StatelessWidget {
  const _ProductDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ProductDetailErrorView extends StatelessWidget {
  const _ProductDetailErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('商品情報の取得に失敗しました。'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}

String _formatTierQuantity(ProductPriceTier tier) {
  if (tier.maxQuantity == null) {
    return tier.minQuantity == 1 ? '1+' : '${tier.minQuantity}+';
  }
  if (tier.minQuantity == tier.maxQuantity) {
    return '${tier.minQuantity}';
  }
  return '${tier.minQuantity}〜${tier.maxQuantity}';
}

String _formatMoney(CatalogMoney money, ExperienceGate experience) {
  final currency = money.currency;
  final locale = currency == 'JPY' ? 'ja_JP' : 'en_US';
  final decimalDigits = currency == 'JPY' ? 0 : 2;
  final symbol = currency == 'JPY'
      ? '¥'
      : currency == 'USD'
      ? r'$'
      : experience.currencySymbol;
  final formatter = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: decimalDigits,
  );
  final value = decimalDigits == 0 ? money.amount : money.amount.toDouble();
  return formatter.format(value);
}
