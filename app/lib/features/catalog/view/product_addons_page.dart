// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/catalog/view_model/product_addons_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProductAddonsPage extends ConsumerStatefulWidget {
  const ProductAddonsPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductAddonsPage> createState() => _ProductAddonsPageState();
}

class _ProductAddonsPageState extends ConsumerState<ProductAddonsPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final addons = ref.watch(
      ProductAddonsViewModel(productId: widget.productId),
    );
    final state = addons.valueOrNull;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(prefersEnglish ? 'Add-ons' : 'オプション'),
        actions: [
          TextButton(
            onPressed: state?.hasSelection == true
                ? () => ref.invoke(
                    ProductAddonsViewModel(
                      productId: widget.productId,
                    ).clearAll(),
                  )
                : null,
            child: Text(prefersEnglish ? 'Clear all' : '全て外す'),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (addons) {
          AsyncError(:final error) when state == null => _ErrorState(
            prefersEnglish: prefersEnglish,
            error: error,
            onRetry: _refresh,
          ),
          AsyncLoading() when state == null => Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: const AppListSkeleton(items: 5, itemHeight: 120),
          ),
          _ => RefreshIndicator.adaptive(
            displacement: tokens.spacing.xl,
            edgeOffset: tokens.spacing.sm,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.xxl + tokens.spacing.lg,
              ),
              children: [
                if (state != null) ...[
                  _ProductSummary(
                    productName: state.productName,
                    basePrice: state.basePrice,
                    prefersEnglish: prefersEnglish,
                  ),
                  SizedBox(height: tokens.spacing.md),
                  if (state.recommendation != null)
                    _UpsellBanner(
                      recommendation: state.recommendation!,
                      prefersEnglish: prefersEnglish,
                      applied: state.qualifiesForBundle,
                      addonLabels: {
                        for (final addon in state.allAddons)
                          addon.id: addon.name,
                      },
                      onApply: () => ref.invoke(
                        ProductAddonsViewModel(
                          productId: widget.productId,
                        ).applyRecommendation(),
                      ),
                      selectedAddons: state.selectedAddonIds,
                    ),
                  SizedBox(height: tokens.spacing.md),
                  for (final group in state.groups) ...[
                    _AddonGroup(
                      group: group,
                      prefersEnglish: prefersEnglish,
                      selectedAddons: state.selectedAddonIds,
                      onToggle: (addonId) => ref.invoke(
                        ProductAddonsViewModel(
                          productId: widget.productId,
                        ).toggleAddon(addonId),
                      ),
                    ),
                    SizedBox(height: tokens.spacing.md),
                  ],
                  SizedBox(height: tokens.spacing.xl),
                ],
              ],
            ),
          ),
        },
      ),
      bottomNavigationBar: state == null
          ? null
          : _AddonsFooter(
              prefersEnglish: prefersEnglish,
              addonsTotal: state.addonsTotal,
              bundleSavings: state.bundleSavings,
              estimatedLineTotal: state.estimatedLineTotal,
              saving: _saving,
              hasSelection: state.hasSelection,
              onContinue: () => _commitSelection(
                prefersEnglish: prefersEnglish,
                selection: state.selectedAddonIds,
              ),
              onSkip: _skip,
            ),
    );
  }

  Future<void> _refresh() async {
    await ref.refreshValue(
      ProductAddonsViewModel(productId: widget.productId),
      keepPrevious: true,
    );
  }

  Future<void> _commitSelection({
    required bool prefersEnglish,
    required Set<String> selection,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.invoke(
        ProductAddonsViewModel(productId: widget.productId).commitSelection(),
      );
      if (!mounted) return;

      final count = result.addonNames.length;
      final summary = count == 0
          ? (prefersEnglish
                ? 'Cart updated without add-ons.'
                : 'オプションなしでカートを更新しました。')
          : (prefersEnglish
                ? 'Added $count add-ons (${_formatMoney(result.addonsTotal)})'
                : '$count件のオプションを追加しました（${_formatMoney(result.addonsTotal)}）');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary)));

      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutePaths.cart);
      }
    } catch (error, stackTrace) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              prefersEnglish
                  ? 'Failed to update cart: $error'
                  : 'カート更新に失敗しました: $error',
            ),
          ),
        );
      debugPrint('Commit selection failed: $error\n$stackTrace');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutePaths.shop);
    }
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.productName,
    required this.basePrice,
    required this.prefersEnglish,
  });

  final String productName;
  final Money basePrice;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(tokens.radii.md),
            ),
            child: const Icon(Icons.inventory_2_outlined),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'For product' : '対象商品',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  productName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'Base price: ${_formatMoney(basePrice)}'
                      : '本体価格: ${_formatMoney(basePrice)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
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

class _UpsellBanner extends StatelessWidget {
  const _UpsellBanner({
    required this.recommendation,
    required this.prefersEnglish,
    required this.applied,
    required this.onApply,
    required this.selectedAddons,
    required this.addonLabels,
  });

  final AddonRecommendation recommendation;
  final bool prefersEnglish;
  final bool applied;
  final VoidCallback onApply;
  final Set<String> selectedAddons;
  final Map<String, String> addonLabels;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chipColor = applied
        ? tokens.colors.primary.withValues(alpha: 0.12)
        : tokens.colors.surfaceVariant;

    return Card.outlined(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: applied
                      ? tokens.colors.primary
                      : tokens.colors.onSurface,
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recommendation.title, style: textTheme.titleMedium),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        recommendation.description,
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.colors.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (recommendation.badge != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.sm,
                      vertical: tokens.spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(tokens.radii.sm),
                    ),
                    child: Text(
                      recommendation.badge!,
                      style: textTheme.labelMedium?.copyWith(
                        color: applied
                            ? tokens.colors.onSurface
                            : tokens.colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: recommendation.addonIds
                  .map(
                    (id) => Chip(
                      avatar: Icon(
                        selectedAddons.contains(id)
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        size: 16,
                      ),
                      label: Text(addonLabels[id] ?? id),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  applied
                      ? (prefersEnglish ? 'Bundle savings applied' : 'まとめ割を適用中')
                      : (prefersEnglish ? 'Apply bundle to save' : 'まとめ割を適用'),
                  style: textTheme.bodySmall?.copyWith(
                    color: applied
                        ? tokens.colors.primary
                        : tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: onApply,
                  child: Text(
                    applied
                        ? (prefersEnglish ? 'Applied' : '適用済み')
                        : (prefersEnglish ? 'Apply' : '適用する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonGroup extends StatelessWidget {
  const _AddonGroup({
    required this.group,
    required this.prefersEnglish,
    required this.selectedAddons,
    required this.onToggle,
  });

  final AddonGroup group;
  final bool prefersEnglish;
  final Set<String> selectedAddons;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.title, style: textTheme.titleMedium),
        SizedBox(height: tokens.spacing.xs),
        Text(
          group.note,
          style: textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.68),
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        Card.outlined(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.md),
          ),
          child: Column(
            children: [
              for (final addon in group.items) ...[
                _AddonTile(
                  addon: addon,
                  prefersEnglish: prefersEnglish,
                  selected: selectedAddons.contains(addon.id),
                  onChanged: () => onToggle(addon.id),
                ),
                if (addon != group.items.last)
                  Divider(
                    height: 1,
                    color: tokens.colors.outline.withValues(alpha: 0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AddonTile extends StatelessWidget {
  const _AddonTile({
    required this.addon,
    required this.prefersEnglish,
    required this.selected,
    required this.onChanged,
  });

  final ProductAddon addon;
  final bool prefersEnglish;
  final bool selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final compare = addon.compareAt;
    final savings = addon.savings;
    final priceLabel = compare == null
        ? _formatMoney(addon.price)
        : '${_formatMoney(addon.price)} · '
              '${prefersEnglish ? 'was' : '通常'} ${_formatMoney(compare)}';

    return SwitchListTile.adaptive(
      value: selected,
      onChanged: (_) => onChanged(),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.sm,
      ),
      secondary: _AddonThumbnail(url: addon.thumbnail),
      title: Row(
        children: [
          Expanded(child: Text(addon.name)),
          if (addon.badge != null) ...[
            SizedBox(width: tokens.spacing.xs),
            Chip(
              label: Text(addon.badge!),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(addon.description, style: textTheme.bodyMedium),
          SizedBox(height: tokens.spacing.xs),
          Row(
            children: [
              Text(
                priceLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.76),
                ),
              ),
              if (savings > 0) ...[
                SizedBox(width: tokens.spacing.xs),
                Text(
                  prefersEnglish ? 'Save ¥$savings' : '¥$savings お得',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.colors.primary,
                  ),
                ),
              ],
            ],
          ),
          if (addon.leadTimeLabel != null) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              addon.leadTimeLabel!,
              style: textTheme.labelSmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          if (addon.limited) ...[
            SizedBox(height: tokens.spacing.xs),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: tokens.colors.error,
                ),
                SizedBox(width: tokens.spacing.xs),
                Text(
                  prefersEnglish ? 'Limited stock' : '数量限定',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.colors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddonThumbnail extends StatelessWidget {
  const _AddonThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.sm),
      child: Container(
        width: 60,
        height: 60,
        color: tokens.colors.surfaceVariant,
        child: url == null
            ? const Icon(Icons.inventory_2_outlined)
            : Image.network(url!, fit: BoxFit.cover),
      ),
    );
  }
}

class _AddonsFooter extends StatelessWidget {
  const _AddonsFooter({
    required this.prefersEnglish,
    required this.addonsTotal,
    required this.bundleSavings,
    required this.estimatedLineTotal,
    required this.saving,
    required this.hasSelection,
    required this.onContinue,
    required this.onSkip,
  });

  final bool prefersEnglish;
  final Money addonsTotal;
  final Money bundleSavings;
  final Money estimatedLineTotal;
  final bool saving;
  final bool hasSelection;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasSavings = bundleSavings.amount > 0;

    return Material(
      color: tokens.colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prefersEnglish ? 'Add-ons total' : 'オプション小計',
                          style: textTheme.bodySmall,
                        ),
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          _formatMoney(addonsTotal),
                          style: textTheme.titleMedium,
                        ),
                        if (hasSavings) ...[
                          SizedBox(height: tokens.spacing.xs),
                          Text(
                            '${prefersEnglish ? 'Bundle savings' : 'まとめ割'}: '
                            '${_formatMoney(bundleSavings)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        prefersEnglish ? 'Est. line total' : '見積合計',
                        style: textTheme.bodySmall,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        _formatMoney(estimatedLineTotal),
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onSkip,
                      child: Text(prefersEnglish ? 'Skip' : 'スキップ'),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: saving ? null : onContinue,
                      child: saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.colors.onSecondary,
                              ),
                            )
                          : Text(
                              hasSelection
                                  ? (prefersEnglish ? 'Continue' : '続行')
                                  : (prefersEnglish
                                        ? 'Continue without add-ons'
                                        : 'オプションなしで続行'),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.prefersEnglish,
    required this.error,
    required this.onRetry,
  });

  final bool prefersEnglish;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 42, color: tokens.colors.error),
            SizedBox(height: tokens.spacing.sm),
            Text(
              prefersEnglish ? 'Could not load add-ons' : 'オプションを読み込めませんでした',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
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
