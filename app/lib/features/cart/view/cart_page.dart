// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final TextEditingController _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final state = ref.watch(cartViewModel);
    final l10n = AppLocalizations.of(context);
    final data = state.valueOrNull;

    final appliedCode = data?.appliedPromo?.code;
    if (appliedCode != null && appliedCode.isNotEmpty) {
      final normalized = appliedCode.toUpperCase();
      if (_promoController.text.toUpperCase() != normalized) {
        _promoController.text = normalized;
      }
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.cartTitle),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: l10n.cartBulkEditTooltip,
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: data == null ? null : () => _showBulkActions(l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.lg),
          child: _buildBody(
            context: context,
            state: state,
            l10n: l10n,
            tokens: tokens,
          ),
        ),
      ),
      bottomNavigationBar: data == null || data.lines.isEmpty
          ? null
          : _SummarySheet(
              state: data,
              l10n: l10n,
              onCheckout: () => _goToCheckout(),
            ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<CartState> state,
    required AppLocalizations l10n,
    required DesignTokens tokens,
  }) {
    final router = GoRouter.of(context);

    if (state is AsyncLoading<CartState> && state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 3, itemHeight: 180),
      );
    }

    if (state is AsyncError<CartState> && state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: l10n.cartLoadFailedTitle,
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: l10n.commonRetry,
          onAction: () => unawaited(_refresh()),
        ),
      );
    }

    final data = state.valueOrNull;
    if (data == null) return const SizedBox.shrink();

    if (data.lines.isEmpty) {
      return RefreshIndicator.adaptive(
        onRefresh: _refresh,
        edgeOffset: tokens.spacing.md,
        displacement: tokens.spacing.lg,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
          children: [
            SizedBox(height: tokens.spacing.xl),
            AppEmptyState(
              title: l10n.cartEmptyTitle,
              message: l10n.cartEmptyMessage,
              icon: Icons.shopping_bag_outlined,
              actionLabel: l10n.cartEmptyAction,
              onAction: () => router.go(AppRoutePaths.shop),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: _refresh,
      edgeOffset: tokens.spacing.md,
      displacement: tokens.spacing.xl,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.md,
          tokens.spacing.lg,
          tokens.spacing.xxl,
        ),
        children: [
          ...data.lines.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.md),
              child: _CartLineCard(
                item: item,
                l10n: l10n,
                pending: data.pendingLineIds.contains(item.id),
                onIncrement: () =>
                    ref.invoke(cartViewModel.adjustQuantity(item.id, 1)),
                onDecrement: () =>
                    ref.invoke(cartViewModel.adjustQuantity(item.id, -1)),
                onEdit: () => _openEditSheet(item, l10n),
                onRemove: () => _removeItem(item, l10n),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          _PromoEntryCard(
            controller: _promoController,
            appliedPromo: data.appliedPromo,
            promoError: data.promoError,
            l10n: l10n,
            isApplying: data.isApplyingPromo,
            onApply: () => _applyPromo(l10n),
            onClear: () {
              _promoController.clear();
              ref.invoke(cartViewModel.clearPromo());
            },
          ),
          SizedBox(height: tokens.spacing.xl),
        ],
      ),
    );
  }

  Future<void> _refresh() {
    return ref.refreshValue(cartViewModel, keepPrevious: true);
  }

  Future<void> _removeItem(CartLineItem item, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.invoke(cartViewModel.removeLine(item.id));
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.cartRemovedItem(item.title)),
        action: SnackBarAction(
          label: l10n.cartUndo,
          onPressed: () => ref.invoke(cartViewModel.undoRemoval()),
        ),
      ),
    );
  }

  Future<void> _applyPromo(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.invoke(
      cartViewModel.applyPromo(_promoController.text),
    );
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    final message = result == null ? null : l10n.cartPromoApplied(result.label);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openEditSheet(CartLineItem item, AppLocalizations l10n) async {
    final tokens = DesignTokensTheme.of(context);
    final selection = {...item.selectedAddonIds};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: tokens.colors.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.lg,
            right: tokens.spacing.lg,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + tokens.spacing.lg,
            top: tokens.spacing.md,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cartEditOptionsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spacing.md),
                  ...item.addonOptions.map(
                    (addon) => CheckboxListTile(
                      dense: true,
                      value: selection.contains(addon.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          selection.add(addon.id);
                        } else {
                          selection.remove(addon.id);
                        }
                      }),
                      title: Row(
                        children: [
                          Icon(
                            addon.kind == CartAddonKind.option
                                ? Icons.tune_outlined
                                : Icons.add_task_outlined,
                            color: tokens.colors.primary,
                          ),
                          SizedBox(width: tokens.spacing.xs),
                          Expanded(child: Text(addon.label)),
                        ],
                      ),
                      subtitle: addon.description == null
                          ? null
                          : Text(
                              addon.description!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: tokens.colors.onSurface.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: tokens.colors.primary,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radii.sm),
                      ),
                      visualDensity: VisualDensity.compact,
                      secondary: addon.price == null
                          ? null
                          : Text(
                              addon.price!.amount == 0
                                  ? l10n.cartAddonIncluded
                                  : _formatMoney(addon.price!),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.colors.primary),
                            ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.md),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(
                            () => selection
                              ..clear()
                              ..addAll(item.selectedAddonIds),
                          );
                        },
                        icon: const Icon(Icons.replay_outlined),
                        label: Text(l10n.cartReset),
                      ),
                      const Spacer(),
                      AppButton(
                        label: l10n.cartSave,
                        onPressed: () {
                          ref.invoke(
                            cartViewModel.updateAddons(item.id, selection),
                          );
                          Navigator.of(context).maybePop();
                        },
                        dense: true,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showBulkActions(AppLocalizations l10n) {
    final tokens = DesignTokensTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.colors.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(tokens.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cartBulkActionsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                l10n.cartBulkActionsBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  ActionChip(
                    label: Text(l10n.cartBulkActionApplyField10),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      _promoController.text = 'FIELD10';
                      unawaited(_applyPromo(l10n));
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.cartBulkActionShipfree),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      _promoController.text = 'SHIPFREE';
                      unawaited(_applyPromo(l10n));
                    },
                  ),
                  ActionChip(
                    label: Text(l10n.cartBulkActionClearSelections),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToCheckout() {
    final router = GoRouter.of(context);
    router.go(AppRoutePaths.checkoutAddress);
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.item,
    required this.l10n,
    required this.pending,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onRemove,
  });

  final CartLineItem item;
  final AppLocalizations l10n;
  final bool pending;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final unitPrice = _formatMoney(item.unitPrice);
    final lineTotal = _formatMoney(item.lineTotal);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(item.thumbnailUrl, fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.ribbon != null) ...[
                                Chip(
                                  label: Text(item.ribbon!),
                                  side: BorderSide.none,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: tokens.colors.primary
                                      .withValues(alpha: 0.12),
                                  labelStyle: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: tokens.colors.primary),
                                ),
                                SizedBox(height: tokens.spacing.xs),
                              ],
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SizedBox(height: tokens.spacing.xs),
                              Text(
                                item.variantLabel,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: tokens.colors.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                              if (item.designLabel != null) ...[
                                SizedBox(height: tokens.spacing.xs),
                                Text(
                                  item.designLabel!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: tokens.colors.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.compareAtPrice != null)
                              Text(
                                _formatMoney(item.compareAtPrice!),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: tokens.colors.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                              ),
                            Text(
                              unitPrice,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              l10n.cartUnitPerItem,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: tokens.colors.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Wrap(
                      spacing: tokens.spacing.xs,
                      runSpacing: tokens.spacing.xs,
                      children: [
                        _InfoChip(
                          icon: Icons.tune_outlined,
                          label: item.variantLabel,
                          color: tokens.colors.primary,
                        ),
                        if (item.designLabel != null)
                          _InfoChip(
                            icon: Icons.edit_outlined,
                            label: item.designLabel!,
                            color: tokens.colors.secondary,
                          ),
                        ...item.selectedAddons.map(
                          (addon) => _InfoChip(
                            icon: addon.kind == CartAddonKind.option
                                ? Icons.check_circle_outline
                                : Icons.add_circle_outline,
                            label:
                                addon.price == null || addon.price?.amount == 0
                                ? addon.label
                                : '${addon.label} · ${_formatMoney(addon.price!)}',
                            color: tokens.colors.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Row(
            children: [
              _StepperButton(
                icon: Icons.remove,
                onPressed: item.quantity <= 1 || pending ? null : onDecrement,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
                child: Text(
                  'x${item.quantity}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onPressed: pending ? null : onIncrement,
              ),
              SizedBox(width: tokens.spacing.sm),
              if (pending)
                Padding(
                  padding: EdgeInsets.only(left: tokens.spacing.xs),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tokens.colors.primary,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: pending ? null : onEdit,
                icon: const Icon(Icons.tune_outlined),
                label: Text(l10n.cartEditOptionsAction),
              ),
              TextButton.icon(
                onPressed: pending ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.cartRemoveAction),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: tokens.colors.primary,
              ),
              SizedBox(width: tokens.spacing.xs),
              Text(
                l10n.cartLeadTimeLabel(
                  item.leadTimeMinDays,
                  item.leadTimeMaxDays,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                l10n.cartLineTotalLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(width: tokens.spacing.sm),
              Text(lineTotal, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          if (item.note != null) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              item.note!,
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

class _PromoEntryCard extends StatelessWidget {
  const _PromoEntryCard({
    required this.controller,
    required this.l10n,
    required this.onApply,
    required this.onClear,
    this.appliedPromo,
    this.promoError,
    this.isApplying = false,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final CartPromo? appliedPromo;
  final String? promoError;
  final bool isApplying;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final applied = appliedPromo;

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cartPromoTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.cartPromoFieldLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radii.md),
              ),
              suffixIcon: Padding(
                padding: EdgeInsets.only(right: tokens.spacing.sm),
                child: ActionChip(
                  avatar: applied == null
                      ? const Icon(Icons.local_offer_outlined, size: 18)
                      : const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    applied == null ? l10n.cartPromoApplyLabel : applied.code,
                  ),
                  onPressed: isApplying
                      ? null
                      : (applied == null ? onApply : onClear),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            onSubmitted: (_) => onApply(),
          ),
          SizedBox(height: tokens.spacing.xs),
          if (promoError != null)
            AppValidationMessage(
              message: promoError!,
              state: AppValidationState.error,
            )
          else if (applied != null)
            AppValidationMessage(
              message: applied.description ?? l10n.cartPromoAppliedFallback,
              state: AppValidationState.success,
            )
          else
            AppValidationMessage(message: l10n.cartPromoMockHint),
        ],
      ),
    );
  }
}

class _SummarySheet extends StatelessWidget {
  const _SummarySheet({
    required this.state,
    required this.l10n,
    required this.onCheckout,
  });

  final CartState state;
  final AppLocalizations l10n;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Material(
      elevation: 12,
      color: tokens.colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize_outlined, color: tokens.colors.primary),
                  SizedBox(width: tokens.spacing.xs),
                  Text(
                    l10n.cartSummaryTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    l10n.cartSummaryItems(state.itemCount),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              _SummaryRow(
                label: l10n.cartSummarySubtotal,
                value: _formatMoney(state.subtotal),
              ),
              if (state.discount.amount > 0)
                _SummaryRow(
                  label: l10n.cartSummaryDiscount,
                  value: '-${_formatMoney(state.discount)}',
                  valueColor: tokens.colors.success,
                ),
              _SummaryRow(
                label: l10n.cartSummaryShipping,
                value: state.shipping.amount == 0
                    ? l10n.cartSummaryFree
                    : _formatMoney(state.shipping),
              ),
              _SummaryRow(
                label: l10n.cartSummaryTax,
                value: _formatMoney(state.tax),
              ),
              Divider(height: tokens.spacing.xl),
              _SummaryRow(
                label: l10n.cartSummaryTotal,
                value: _formatMoney(state.total),
                valueStyle: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: tokens.spacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: tokens.colors.primary,
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(
                    child: Text(
                      l10n.cartSummaryEstimate(
                        state.estimate.minDays,
                        state.estimate.maxDays,
                        state.estimate.methodLabel,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              AppButton(
                label: l10n.cartProceedCheckout,
                onPressed: state.lines.isEmpty ? null : onCheckout,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: DesignTokensTheme.of(context).spacing.xs,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style:
                valueStyle ??
                Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.08),
      labelStyle: Theme.of(context).textTheme.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.sm),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon, size: 18),
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
