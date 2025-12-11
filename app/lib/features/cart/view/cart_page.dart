// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
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
        title: Text(prefersEnglish ? 'Cart' : 'カート'),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Bulk edit' : 'まとめて編集',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: data == null
                ? null
                : () => _showBulkActions(prefersEnglish),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.lg),
          child: _buildBody(
            context: context,
            state: state,
            prefersEnglish: prefersEnglish,
            tokens: tokens,
          ),
        ),
      ),
      bottomNavigationBar: data == null || data.lines.isEmpty
          ? null
          : _SummarySheet(
              state: data,
              prefersEnglish: prefersEnglish,
              onCheckout: () => _goToCheckout(),
            ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<CartState> state,
    required bool prefersEnglish,
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
          title: prefersEnglish ? 'Could not load cart' : 'カートを読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
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
              title: prefersEnglish ? 'Cart is empty' : 'カートは空です',
              message: prefersEnglish
                  ? 'Add items from the shop to see an estimate.'
                  : 'ショップから商品を追加すると、見積もりが表示されます。',
              icon: Icons.shopping_bag_outlined,
              actionLabel: prefersEnglish ? 'Back to shop' : 'ショップへ戻る',
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
                prefersEnglish: prefersEnglish,
                pending: data.pendingLineIds.contains(item.id),
                onIncrement: () =>
                    ref.invoke(cartViewModel.adjustQuantity(item.id, 1)),
                onDecrement: () =>
                    ref.invoke(cartViewModel.adjustQuantity(item.id, -1)),
                onEdit: () => _openEditSheet(item, prefersEnglish),
                onRemove: () => _removeItem(item, prefersEnglish),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          _PromoEntryCard(
            controller: _promoController,
            appliedPromo: data.appliedPromo,
            promoError: data.promoError,
            prefersEnglish: prefersEnglish,
            isApplying: data.isApplyingPromo,
            onApply: () => _applyPromo(prefersEnglish),
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

  Future<void> _removeItem(CartLineItem item, bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.invoke(cartViewModel.removeLine(item.id));
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          prefersEnglish ? 'Removed ${item.title}' : '${item.title} を削除しました',
        ),
        action: SnackBarAction(
          label: prefersEnglish ? 'Undo' : '元に戻す',
          onPressed: () => ref.invoke(cartViewModel.undoRemoval()),
        ),
      ),
    );
  }

  Future<void> _applyPromo(bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.invoke(
      cartViewModel.applyPromo(_promoController.text),
    );
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    final message = result == null
        ? null
        : (prefersEnglish
              ? 'Applied ${result.label}'
              : '${result.label} を適用しました');
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openEditSheet(CartLineItem item, bool prefersEnglish) async {
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
                    prefersEnglish ? 'Edit options' : 'オプションを編集',
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
                                  ? (prefersEnglish ? 'Included' : '無料')
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
                        label: Text(prefersEnglish ? 'Reset' : '元に戻す'),
                      ),
                      const Spacer(),
                      AppButton(
                        label: prefersEnglish ? 'Save' : '保存',
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

  void _showBulkActions(bool prefersEnglish) {
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
                prefersEnglish ? 'Bulk actions' : 'まとめて操作',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(
                prefersEnglish
                    ? 'Apply promo, adjust quantities, or clear selections for all lines.'
                    : '全ての行にクーポン適用、数量調整、選択解除をまとめて行えます（モック）。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  ActionChip(
                    label: Text(
                      prefersEnglish ? 'Apply FIELD10' : 'FIELD10 を適用',
                    ),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      _promoController.text = 'FIELD10';
                      unawaited(_applyPromo(prefersEnglish));
                    },
                  ),
                  ActionChip(
                    label: Text(prefersEnglish ? 'Free shipping' : '送料無料コード'),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      _promoController.text = 'SHIPFREE';
                      unawaited(_applyPromo(prefersEnglish));
                    },
                  ),
                  ActionChip(
                    label: Text(prefersEnglish ? 'Clear selections' : '選択をクリア'),
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
    required this.prefersEnglish,
    required this.pending,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onRemove,
  });

  final CartLineItem item;
  final bool prefersEnglish;
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
                              prefersEnglish ? 'per item' : '1点あたり',
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
                label: Text(prefersEnglish ? 'Edit options' : 'オプション編集'),
              ),
              TextButton.icon(
                onPressed: pending ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(prefersEnglish ? 'Remove' : '削除'),
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
                prefersEnglish
                    ? 'Est. ${item.leadTimeMinDays}-${item.leadTimeMaxDays} days'
                    : 'お届け目安 ${item.leadTimeMinDays}〜${item.leadTimeMaxDays}日',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                prefersEnglish ? 'Line total' : '小計',
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
    required this.prefersEnglish,
    required this.onApply,
    required this.onClear,
    this.appliedPromo,
    this.promoError,
    this.isApplying = false,
  });

  final TextEditingController controller;
  final bool prefersEnglish;
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
            prefersEnglish ? 'Promo code' : 'クーポンコード',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: prefersEnglish ? 'Enter code' : 'コードを入力',
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
                    applied == null
                        ? (prefersEnglish ? 'Apply' : '適用')
                        : applied.code,
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
              message:
                  applied.description ??
                  (prefersEnglish ? 'Promo applied.' : 'クーポンを適用しました。'),
              state: AppValidationState.success,
            )
          else
            AppValidationMessage(
              message: prefersEnglish
                  ? 'Promo codes are simulated for this mock.'
                  : 'クーポン入力はモックです。',
            ),
        ],
      ),
    );
  }
}

class _SummarySheet extends StatelessWidget {
  const _SummarySheet({
    required this.state,
    required this.prefersEnglish,
    required this.onCheckout,
  });

  final CartState state;
  final bool prefersEnglish;
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
                    prefersEnglish ? 'Estimate summary' : '概算サマリー',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    prefersEnglish
                        ? '${state.itemCount} items'
                        : '${state.itemCount}点',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.sm),
              _SummaryRow(
                label: prefersEnglish ? 'Subtotal' : '商品小計',
                value: _formatMoney(state.subtotal),
              ),
              if (state.discount.amount > 0)
                _SummaryRow(
                  label: prefersEnglish ? 'Discount' : '割引',
                  value: '-${_formatMoney(state.discount)}',
                  valueColor: tokens.colors.success,
                ),
              _SummaryRow(
                label: prefersEnglish ? 'Shipping' : '送料',
                value: state.shipping.amount == 0
                    ? (prefersEnglish ? 'Free' : '無料')
                    : _formatMoney(state.shipping),
              ),
              _SummaryRow(
                label: prefersEnglish ? 'Estimated tax' : '推定税',
                value: _formatMoney(state.tax),
              ),
              Divider(height: tokens.spacing.xl),
              _SummaryRow(
                label: prefersEnglish ? 'Total (est.)' : '合計（概算）',
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
                      prefersEnglish
                          ? 'Est. ${state.estimate.minDays}-${state.estimate.maxDays} days · ${state.estimate.methodLabel}'
                          : '目安 ${state.estimate.minDays}〜${state.estimate.maxDays}日・${state.estimate.methodLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.md),
              AppButton(
                label: prefersEnglish ? 'Proceed to checkout' : '購入手続きへ',
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
