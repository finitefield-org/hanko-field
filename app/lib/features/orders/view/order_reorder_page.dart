// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/orders/view_model/order_reorder_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrderReorderPage extends ConsumerStatefulWidget {
  const OrderReorderPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderReorderPage> createState() => _OrderReorderPageState();
}

class _OrderReorderPageState extends ConsumerState<OrderReorderPage> {
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final vm = OrderReorderViewModel(orderId: widget.orderId);
    final stateAsync = ref.watch(vm);
    final toggleState = ref.watch(vm.toggleLineMut);
    final data = stateAsync.valueOrNull;
    final isLoading = stateAsync is AsyncLoading<OrderReorderState>;
    final isError = stateAsync is AsyncError<OrderReorderState>;
    final isBusy = toggleState is PendingMutationState;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.container.read(navigationControllerProvider).pop(),
        ),
        title: Text(l10n.orderReorderTitle),
      ),
      body: SafeArea(
        child: data != null
            ? _ReorderBody(
                state: data,
                l10n: l10n,
                isBusy: isBusy,
                showBanner: !_bannerDismissed,
                onToggle: (id) => ref.invoke(vm.toggleLine(id)),
                onCancel: _cancel,
                onDismissBanner: () {
                  setState(() => _bannerDismissed = true);
                },
                onRebuildCart: () => unawaited(_rebuildCart(data)),
              )
            : (isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : (isError
                        ? _ErrorState(
                            l10n: l10n,
                            onRetry: () => unawaited(
                              ref.refreshValue(vm, keepPrevious: true),
                            ),
                          )
                        : const SizedBox.shrink())),
      ),
    );
  }

  void _cancel() {
    ref.container.read(navigationControllerProvider).pop();
  }

  Future<void> _rebuildCart(OrderReorderState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final gates = ref.container.read(appExperienceGatesProvider);
    final l10n = AppLocalizations.of(context);

    final lines = buildCartLinesFromReorder(state, gates);
    if (lines.isEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderReorderSelectItem)),
      );
      return;
    }

    await ref.invoke(cartViewModel.replaceLines(lines));

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.orderReorderCartRebuilt)),
    );

    await ref.container
        .read(navigationControllerProvider)
        .go(AppRoutePaths.checkoutAddress);
  }
}

class _ReorderBody extends StatelessWidget {
  const _ReorderBody({
    required this.state,
    required this.l10n,
    required this.isBusy,
    required this.showBanner,
    required this.onToggle,
    required this.onRebuildCart,
    required this.onCancel,
    required this.onDismissBanner,
  });

  final OrderReorderState state;
  final AppLocalizations l10n;
  final bool isBusy;
  final bool showBanner;
  final ValueChanged<String> onToggle;
  final VoidCallback onRebuildCart;
  final VoidCallback onCancel;
  final VoidCallback onDismissBanner;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final orderNumber = state.order.orderNumber;

    final banner = showBanner ? _buildBanner(context) : null;
    final items = state.lines;

    return Column(
      children: [
        if (banner != null) banner,
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.md,
            tokens.spacing.md,
            tokens.spacing.md,
            tokens.spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orderReorderFromOrder(orderNumber),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                l10n.orderReorderSelectedCount(
                  state.selectedCount,
                  state.selectableCount,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: tokens.spacing.sm),
            itemBuilder: (context, index) {
              final line = items[index];
              return _ReorderLineCard(
                line: line,
                l10n: l10n,
                onToggle: isBusy ? null : () => onToggle(line.id),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.md,
            tokens.spacing.sm,
            tokens.spacing.md,
            tokens.spacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: isBusy ? null : onRebuildCart,
                  child: Text(l10n.orderReorderRebuildCart),
                ),
              ),
              SizedBox(width: tokens.spacing.sm),
              TextButton(onPressed: onCancel, child: Text(l10n.commonCancel)),
            ],
          ),
        ),
      ],
    );
  }

  MaterialBanner? _buildBanner(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (!state.hasOutOfStock && !state.hasPriceChanges) return null;

    final message = switch ((state.hasOutOfStock, state.hasPriceChanges)) {
      (true, true) => l10n.orderReorderBannerOutOfStockAndPrice,
      (true, false) => l10n.orderReorderBannerOutOfStock,
      (false, true) => l10n.orderReorderBannerPriceChanged,
      _ => l10n.orderReorderBannerUpdates,
    };

    return MaterialBanner(
      backgroundColor: tokens.colors.primary.withValues(alpha: 0.08),
      leading: Icon(Icons.info_outline, color: tokens.colors.primary),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onDismissBanner,
          child: Text(l10n.orderReorderDismiss),
        ),
      ],
    );
  }
}

class _ReorderLineCard extends StatelessWidget {
  const _ReorderLineCard({
    required this.line,
    required this.l10n,
    required this.onToggle,
  });

  final OrderReorderLine line;
  final AppLocalizations l10n;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final snapshotLabel = (line.item.designSnapshot?['label'] as String?)
        ?.trim();
    final title = line.item.name?.trim().isNotEmpty == true
        ? line.item.name!.trim()
        : l10n.orderReorderItemFallback;

    final subtitleParts = <String>[
      if (line.item.sku.isNotEmpty) line.item.sku,
      if (snapshotLabel != null && snapshotLabel.isNotEmpty)
        l10n.orderReorderDesignLabel(snapshotLabel),
      if (line.item.quantity > 1)
        l10n.orderDetailItemQtyLabel(line.item.quantity),
    ];

    final subtitle = subtitleParts.join(' · ');

    final disabled = line.issue == ReorderLineIssue.outOfStock;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onToggle,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: line.isSelected,
                onChanged: disabled ? null : (_) => onToggle?.call(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _PriceBlock(line: line),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spacing.sm),
                    Wrap(
                      spacing: tokens.spacing.xs,
                      runSpacing: tokens.spacing.xs,
                      children: [
                        if (line.issue == ReorderLineIssue.outOfStock)
                          _Chip(
                            label: l10n.orderReorderOutOfStock,
                            color: tokens.colors.error,
                          ),
                        if (line.issue == ReorderLineIssue.priceChanged)
                          _Chip(
                            label: l10n.orderReorderPriceUpdated,
                            color: tokens.colors.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.line});

  final OrderReorderLine line;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final priceNow = _formatMoney(line.unitPriceNow);
    final priceWas = _formatMoney(
      Money(amount: line.item.unitPrice, currency: line.unitPriceNow.currency),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (line.issue == ReorderLineIssue.priceChanged)
          Text(
            priceWas,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: tokens.colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        Text(priceNow, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Chip(
      label: Text(label),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: color),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.xs),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.l10n, required this.onRetry});

  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.orderReorderLoadFailed, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(Money money) {
  final symbol = switch (money.currency) {
    'JPY' => '¥',
    'USD' => r'$',
    'EUR' => '€',
    _ => '${money.currency} ',
  };
  return '$symbol${money.amount.toString()}';
}
