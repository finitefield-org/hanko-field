import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/catalog.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:app/features/shop/application/product_addons_provider.dart';
import 'package:app/features/shop/domain/product_addons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProductAddonsScreen extends ConsumerStatefulWidget {
  const ProductAddonsScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductAddonsScreen> createState() =>
      _ProductAddonsScreenState();
}

class _ProductAddonsScreenState extends ConsumerState<ProductAddonsScreen> {
  final Set<String> _selectedAddonIds = <String>{};
  bool _initializedDefaults = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final addonsAsync = ref.watch(productAddonsProvider(widget.productId));
    final experienceAsync = ref.watch(experienceGateProvider);
    return experienceAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                '体験設定の取得に失敗しました。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(experienceGateProvider),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
      data: (experience) {
        return addonsAsync.when(
          data: (addons) {
            _ensureDefaults(addons);
            final selectedAddons = addons.allAddons
                .where((addon) => _selectedAddonIds.contains(addon.id))
                .toList();
            final totalFormatted = _formatSelectedTotal(
              addons: addons,
              selectedIds: _selectedAddonIds,
              experience: experience,
            );
            final canContinue = !_isSaving;
            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar.medium(
                    centerTitle: true,
                    title: Text(
                      experience.isInternational
                          ? 'Add-on Accessories'
                          : 'オプションアクセサリー',
                    ),
                    actions: [
                      TextButton(
                        onPressed: _selectedAddonIds.isEmpty
                            ? null
                            : () => _handleClearAll(addons),
                        child: Text(
                          experience.isInternational ? 'Clear all' : 'すべて解除',
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (addons.recommendations.isNotEmpty)
                            ...addons.recommendations.map(
                              (rec) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _UpsellRecommendationCard(
                                  recommendation: rec,
                                  addons: addons,
                                  experience: experience,
                                  onApply: () =>
                                      _applyRecommendation(addons, rec),
                                  alreadyApplied: _isRecommendationApplied(rec),
                                ),
                              ),
                            ),
                          _SelectionSummary(
                            selectedAddons: selectedAddons,
                            totalLabel: totalFormatted,
                            experience: experience,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  for (final group in addons.groups)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: _AddonGroupSection(
                          group: group,
                          experience: experience,
                          isSelected: _selectedAddonIds.contains,
                          onToggle: (id, value) =>
                              _handleToggleAddon(addons, id, value),
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: canContinue
                            ? () => _handleContinue(addons, experience)
                            : null,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                experience.isInternational
                                    ? 'Add selected to cart'
                                    : '選択をカートに追加',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: canContinue
                            ? () => _handleSkip(addons, experience)
                            : null,
                        child: Text(
                          experience.isInternational ? 'Skip for now' : '後で選ぶ',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => _ProductAddonsErrorView(
            onRetry: () =>
                ref.invalidate(productAddonsProvider(widget.productId)),
          ),
        );
      },
    );
  }

  void _ensureDefaults(ProductAddons addons) {
    if (_initializedDefaults) {
      return;
    }
    final defaults = addons.allAddons
        .where((addon) => addon.isDefaultSelected)
        .map((addon) => addon.id);
    _selectedAddonIds.addAll(defaults);
    _initializedDefaults = true;
  }

  Future<void> _handleToggleAddon(
    ProductAddons addons,
    String addonId,
    bool selected,
  ) async {
    setState(() {
      if (selected) {
        _selectedAddonIds.add(addonId);
      } else {
        _selectedAddonIds.remove(addonId);
      }
    });
    await _persistSelection(addons);
  }

  Future<void> _handleClearAll(ProductAddons addons) async {
    if (_selectedAddonIds.isEmpty) {
      return;
    }
    setState(_selectedAddonIds.clear);
    await _persistSelection(addons);
    if (!mounted) return;
    _showFeedback(
      message: ref
          .read(experienceGateProvider)
          .maybeWhen(
            data: (experience) => experience.isInternational
                ? 'Selections cleared.'
                : '選択をリセットしました。',
            orElse: () => 'Selections cleared.',
          ),
    );
  }

  Future<void> _handleContinue(
    ProductAddons addons,
    ExperienceGate experience,
  ) async {
    setState(() {
      _isSaving = true;
    });
    await _persistSelection(addons);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    final count = _selectedAddonIds.length;
    final message = experience.isInternational
        ? (count == 0
              ? 'No add-ons added.'
              : '$count add-ons added to your cart entry.')
        : (count == 0 ? 'オプションは追加されませんでした。' : '$count 件のオプションをカートに保存しました。');
    _showFeedback(message: message);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSkip(
    ProductAddons addons,
    ExperienceGate experience,
  ) async {
    if (_selectedAddonIds.isNotEmpty) {
      setState(_selectedAddonIds.clear);
      await _persistSelection(addons);
    }
    if (!mounted) {
      return;
    }
    final message = experience.isInternational
        ? 'You can add accessories later from the cart.'
        : 'カートからいつでもオプションを追加できます。';
    _showFeedback(message: message);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _applyRecommendation(
    ProductAddons addons,
    ProductAddonRecommendation recommendation,
  ) async {
    setState(() {
      _selectedAddonIds
        ..clear()
        ..addAll(recommendation.addonIds);
    });
    await _persistSelection(addons);
  }

  bool _isRecommendationApplied(ProductAddonRecommendation recommendation) {
    if (recommendation.addonIds.isEmpty) {
      return false;
    }
    for (final id in recommendation.addonIds) {
      if (!_selectedAddonIds.contains(id)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persistSelection(ProductAddons addons) async {
    final cache = ref.read(offlineCacheRepositoryProvider);
    final readResult = await cache.readCart();
    final existing = readResult.value;
    final addonsMap = <String, dynamic>{
      'selectedAddonIds': _selectedAddonIds.toList(),
      'selectedAddonCount': _selectedAddonIds.length,
      'selectedAddonDetails': addons.allAddons
          .where((addon) => _selectedAddonIds.contains(addon.id))
          .map(
            (addon) => {
              'id': addon.id,
              'name': addon.name,
              'price': addon.price.amount,
              'currency': addon.price.currency,
              'category': addon.category.name,
            },
          )
          .toList(),
    };

    final currency = addons.allAddons.isEmpty
        ? existing?.currency
        : addons.allAddons.first.price.currency;
    final lines = List<CartLineCache>.from(
      existing?.lines ?? <CartLineCache>[],
    );
    final lineIndex = lines.indexWhere(
      (line) => line.productId == addons.productId,
    );
    final totalAmount = addons.allAddons
        .where((addon) => _selectedAddonIds.contains(addon.id))
        .fold<int>(0, (sum, addon) => sum + addon.price.amount);
    addonsMap['selectedAddonTotalAmount'] = totalAmount;
    addonsMap['selectedAddonCurrency'] = currency;
    final now = DateTime.now();

    if (lineIndex >= 0) {
      final existingLine = lines[lineIndex];
      lines[lineIndex] = CartLineCache(
        lineId: existingLine.lineId,
        productId: existingLine.productId,
        quantity: existingLine.quantity,
        designSnapshot: existingLine.designSnapshot,
        price: existingLine.price,
        currency: existingLine.currency ?? currency,
        addons: addonsMap,
      );
    } else {
      lines.add(
        CartLineCache(
          lineId: 'pending-${addons.productId}',
          productId: addons.productId,
          quantity: 1,
          // price omitted: server-calculated base price when synced.
          currency: currency,
          addons: addonsMap,
        ),
      );
    }

    final snapshot = CachedCartSnapshot(
      lines: lines,
      currency: existing?.currency ?? currency,
      subtotal: existing?.subtotal,
      total: existing?.total,
      discount: existing?.discount,
      shipping: existing?.shipping,
      tax: existing?.tax,
      promotion: existing?.promotion,
      updatedAt: now,
    );
    await cache.writeCart(snapshot);
  }

  void _showFeedback({required String message}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddonGroupSection extends StatelessWidget {
  const _AddonGroupSection({
    required this.group,
    required this.experience,
    required this.isSelected,
    required this.onToggle,
  });

  final ProductAddonGroup group;
  final ExperienceGate experience;
  final bool Function(String addonId) isSelected;
  final FutureOr<void> Function(String addonId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.displayLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (group.helperText != null) ...[
          const SizedBox(height: 4),
          Text(group.helperText!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: Column(
            children: [
              for (final (index, addon) in group.addons.indexed)
                Column(
                  children: [
                    _AddonListItem(
                      addon: addon,
                      experience: experience,
                      selected: isSelected(addon.id),
                      onChanged: (value) => onToggle(addon.id, value),
                    ),
                    if (index != group.addons.length - 1)
                      const Divider(height: 1),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddonListItem extends StatelessWidget {
  const _AddonListItem({
    required this.addon,
    required this.experience,
    required this.selected,
    required this.onChanged,
  });

  final ProductAddon addon;
  final ExperienceGate experience;
  final bool selected;
  final FutureOr<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final priceLabel = _formatMoney(addon.price, experience);
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final subtitleStyle = theme.textTheme.bodyMedium;
    final descriptionStyle = subtitleStyle?.copyWith(color: onSurfaceVariant);
    final badge = addon.badge;
    final titleRowChildren = <Widget>[
      Flexible(child: Text(addon.name, style: theme.textTheme.titleMedium)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Chip(
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          label: Text(badge),
        ),
      ],
    ];
    return InkWell(
      onTap: () {
        final result = onChanged(!selected);
        if (result is Future) {
          unawaited(result);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                addon.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: titleRowChildren),
                  const SizedBox(height: 4),
                  Text(addon.description, style: descriptionStyle),
                  const SizedBox(height: 8),
                  Text(priceLabel, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            Switch.adaptive(
              value: selected,
              onChanged: (value) {
                final result = onChanged(value);
                if (result is Future) {
                  unawaited(result);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.selectedAddons,
    required this.totalLabel,
    required this.experience,
  });

  final List<ProductAddon> selectedAddons;
  final String totalLabel;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final countLabel = experience.isInternational
        ? '${selectedAddons.length} add-ons selected'
        : '選択中: ${selectedAddons.length} 件';
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(countLabel, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (selectedAddons.isEmpty)
              Text(
                experience.isInternational
                    ? 'Accessories help protect and present your seal.'
                    : 'オプションを追加すると、印章の保護や贈答がより安心になります。',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedAddons
                    .map(
                      (addon) => Chip(
                        avatar: const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(addon.name),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  experience.isInternational
                      ? 'Estimated add-on total'
                      : 'オプション小計',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  totalLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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

class _UpsellRecommendationCard extends StatelessWidget {
  const _UpsellRecommendationCard({
    required this.recommendation,
    required this.addons,
    required this.experience,
    required this.onApply,
    required this.alreadyApplied,
  });

  final ProductAddonRecommendation recommendation;
  final ProductAddons addons;
  final ExperienceGate experience;
  final VoidCallback onApply;
  final bool alreadyApplied;

  @override
  Widget build(BuildContext context) {
    final appliedLabel = experience.isInternational ? 'Applied' : '適用中';
    final applyLabel = experience.isInternational ? 'Apply bundle' : 'セットを適用';
    final totalLabel = _formatMoney(recommendation.estimatedTotal, experience);
    final selectedAddons = recommendation.addonIds
        .map(
          (id) => addons.allAddons.firstWhere(
            (addon) => addon.id == id,
            orElse: () => ProductAddon(
              id: id,
              name: id,
              description: '',
              category: ProductAddonCategory.caseAccessory,
              price: recommendation.estimatedTotal,
              imageUrl: '',
            ),
          ),
        )
        .toList();
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (recommendation.badge != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(recommendation.badge!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedAddons
                  .map(
                    (addon) => Chip(
                      avatar: const Icon(Icons.add_circle_outline, size: 16),
                      label: Text(addon.name),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  experience.isInternational ? 'Bundle total' : 'セット合計',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  totalLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: alreadyApplied ? null : onApply,
                child: Text(alreadyApplied ? appliedLabel : applyLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductAddonsErrorView extends StatelessWidget {
  const _ProductAddonsErrorView({required this.onRetry});

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
            const Text('オプションの読み込みに失敗しました。'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}

String _formatSelectedTotal({
  required ProductAddons addons,
  required Set<String> selectedIds,
  required ExperienceGate experience,
}) {
  final selected = addons.allAddons
      .where((addon) => selectedIds.contains(addon.id))
      .toList();
  if (selected.isEmpty) {
    final currency = addons.allAddons.isEmpty
        ? experience.currencyCode
        : addons.allAddons.first.price.currency;
    final zeroMoney = CatalogMoney(amount: 0, currency: currency);
    return _formatMoney(zeroMoney, experience);
  }
  final totalAmount = selected.fold<int>(
    0,
    (previousValue, element) => previousValue + element.price.amount,
  );
  final currency = selected.first.price.currency;
  return _formatMoney(
    CatalogMoney(amount: totalAmount, currency: currency),
    experience,
  );
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
