import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late final TextEditingController _promoController;

  @override
  void initState() {
    super.initState();
    _promoController = TextEditingController();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(cartControllerProvider);

    ref.listen<AsyncValue<CartViewState>>(cartControllerProvider, (
      previous,
      next,
    ) {
      final prevData = previous?.value;
      final nextData = next.value;
      if (nextData == null) {
        return;
      }
      final prevMessage = prevData?.feedbackMessage;
      final nextMessage = nextData.feedbackMessage;
      if (nextMessage != null && nextMessage != prevMessage) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        final wasRemoval =
            prevData != null && prevData.lines.length > nextData.lines.length;
        final undoLabel = nextData.snapshot.experience.isInternational
            ? 'Undo'
            : '元に戻す';
        messenger.showSnackBar(
          SnackBar(
            content: Text(nextMessage),
            action: wasRemoval
                ? SnackBarAction(
                    label: undoLabel,
                    onPressed: () => ref
                        .read(cartControllerProvider.notifier)
                        .undoLastRemoval(),
                  )
                : null,
          ),
        );
        ref.read(cartControllerProvider.notifier).clearFeedback();
      }
      final prevPromo = prevData?.snapshot.promotion?.code;
      final nextPromo = nextData.snapshot.promotion?.code;
      if (prevPromo != nextPromo) {
        _promoController
          ..text = ''
          ..clear();
      }
    });

    return asyncState.when(
      data: (state) =>
          _CartLoadedView(state: state, promoController: _promoController),
      loading: () => const _CartLoadingView(),
      error: (error, stackTrace) => _CartErrorView(
        error: error,
        onRetry: () => ref.read(cartControllerProvider.notifier).reload(),
      ),
    );
  }
}

class _CartLoadedView extends ConsumerWidget {
  const _CartLoadedView({required this.state, required this.promoController});

  final CartViewState state;
  final TextEditingController promoController;

  CartController getController(WidgetRef ref) =>
      ref.read(cartControllerProvider.notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = state.snapshot.experience;
    final checkoutLabel = experience.isInternational
        ? 'Proceed to Checkout'
        : 'チェックアウトに進む';
    final appBarTitle = experience.isInternational ? 'Your Cart' : 'カート';
    final bulkEditTooltip = experience.isInternational
        ? 'Edit selections'
        : 'まとめて編集';
    final emptyView = state.lines.isEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            centerTitle: true,
            pinned: true,
            title: Text(appBarTitle),
            actions: [
              IconButton(
                tooltip: bulkEditTooltip,
                icon: const Icon(Icons.edit_note_outlined),
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        experience.isInternational
                            ? 'Bulk edit is planned for a future update.'
                            : 'まとめ編集は今後のアップデートで対応予定です。',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (emptyView)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _CartEmptyState(experience: experience),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceXS,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final line = state.lines[index];
                  final processing = state.processingLineIds.contains(line.id);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == state.lines.length - 1
                          ? AppTokens.spaceM
                          : AppTokens.spaceL,
                    ),
                    child: _CartLineCard(
                      line: line,
                      experience: experience,
                      isProcessing: processing,
                      onIncrement: () =>
                          getController(ref).incrementQuantity(line.id),
                      onDecrement: () =>
                          getController(ref).decrementQuantity(line.id),
                      onRemove: () => getController(ref).removeLine(line.id),
                      onEditAddons: () => _navigateToAddons(context, ref, line),
                    ),
                  );
                }, childCount: state.lines.length),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                0,
                AppTokens.spaceL,
                AppTokens.spaceL,
              ),
              sliver: SliverToBoxAdapter(
                child: _PromoEntrySection(
                  state: state,
                  controller: promoController,
                  onApply: () => getController(
                    ref,
                  ).applyPromotion(promoController.text.trim()),
                  onRemove: () => getController(ref).removePromotion(),
                  onClearError: () => getController(ref).clearPromoError(),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTokens.spaceXXL),
            ),
          ],
        ],
      ),
      bottomNavigationBar: state.lines.isEmpty
          ? null
          : _CartSummarySheet(
              state: state,
              checkoutLabel: checkoutLabel,
              onCheckout: () {
                ref.read(appStateProvider.notifier).push(CheckoutRoute());
              },
            ),
    );
  }

  void _navigateToAddons(BuildContext context, WidgetRef ref, CartLine line) {
    final notifier = ref.read(appStateProvider.notifier);
    notifier.push(
      ShopDetailRoute(
        entity: 'products',
        identifier: line.productId,
        trailingSegments: const ['addons'],
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.experience,
    required this.isProcessing,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onEditAddons,
  });

  final CartLine line;
  final ExperienceGate experience;
  final bool isProcessing;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onEditAddons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = _CurrencyFormatter(experience);
    final removeLabel = experience.isInternational ? 'Remove' : '削除';
    final editLabel = experience.isInternational ? 'Edit add-ons' : 'オプションを編集';

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CartThumbnail(imageUrl: line.thumbnailUrl),
                const SizedBox(width: AppTokens.spaceL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppTokens.spaceXS),
                      Text(line.subtitle, style: theme.textTheme.bodySmall),
                      if (line.optionChips.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.spaceS),
                        Wrap(
                          spacing: AppTokens.spaceS,
                          runSpacing: AppTokens.spaceS,
                          children: line.optionChips
                              .take(6)
                              .map(
                                (chip) => InputChip(
                                  label: Text(chip),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onEditAddons,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceM),
            _QuantityStepper(
              quantity: line.quantity,
              onIncrement: isProcessing ? null : onIncrement,
              onDecrement: isProcessing ? null : onDecrement,
              experience: experience,
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (line.addons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.isInternational ? 'Add-ons' : '追加オプション',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXS),
                    for (final addon in line.addons)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceXS,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline, size: 18),
                            const SizedBox(width: AppTokens.spaceS),
                            Expanded(child: Text(addon.name)),
                            Text(
                              formatter.format(addon.price),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (line.estimatedLeadTime != null)
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 18),
                          const SizedBox(width: AppTokens.spaceXS),
                          Text(
                            line.estimatedLeadTime!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    if (line.quantityWarning != null) ...[
                      const SizedBox(height: AppTokens.spaceXS),
                      Text(
                        line.quantityWarning!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatter.format(line.lineTotal),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (line.addonsTotal > 0)
                      Text(
                        experience.isInternational
                            ? '+ ${formatter.format(line.addonsTotal)} add-ons'
                            : '+ ${formatter.format(line.addonsTotal)}（オプション）',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.tune_outlined),
                  label: Text(editLabel),
                  onPressed: isProcessing ? null : onEditAddons,
                ),
                TextButton(
                  onPressed: isProcessing ? null : onRemove,
                  child: Text(removeLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.experience,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final ExperienceGate experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyLabel = experience.isInternational ? 'Quantity' : '数量';
    return Row(
      children: [
        Text(qtyLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(width: AppTokens.spaceM),
        FilledButton.tonal(
          onPressed: onDecrement,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(8),
          ),
          child: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceM),
          child: Text(quantity.toString(), style: theme.textTheme.titleMedium),
        ),
        FilledButton.tonal(
          onPressed: onIncrement,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(8),
          ),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _CartThumbnail extends StatelessWidget {
  const _CartThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppTokens.radiusM,
      child: Image.network(
        imageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 96,
          height: 96,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}

class _PromoEntrySection extends StatelessWidget {
  const _PromoEntrySection({
    required this.state,
    required this.controller,
    required this.onApply,
    required this.onRemove,
    required this.onClearError,
  });

  final CartViewState state;
  final TextEditingController controller;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    final experience = state.snapshot.experience;
    final theme = Theme.of(context);
    final formatter = _CurrencyFormatter(experience);
    final label = experience.isInternational ? 'Promo code' : 'プロモコード';
    final helper = experience.isInternational
        ? 'Save with seasonal promotions'
        : 'シーズンキャンペーン等のコードを入力';
    final applyLabel = experience.isInternational ? 'Apply' : '適用';
    final removeLabel = experience.isInternational ? 'Remove' : '解除';
    final appliedLabel = experience.isInternational ? 'Applied' : '適用済み';
    final promotion = state.snapshot.promotion;
    final errorText = state.promoError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          experience.isInternational ? 'Promotions' : 'プロモーション',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(helper, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppTokens.spaceM),
        TextField(
          controller: controller,
          enabled: !state.isApplyingPromotion,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: errorText,
            suffixIcon: state.isApplyingPromotion
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: applyLabel,
                        onPressed: hasText ? onApply : null,
                      );
                    },
                  ),
          ),
          onChanged: (_) => onClearError(),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (controller.text.trim().isNotEmpty) {
              onApply();
            }
          },
        ),
        if (promotion != null) ...[
          const SizedBox(height: AppTokens.spaceM),
          Wrap(
            spacing: AppTokens.spaceS,
            children: [
              Chip(
                avatar: const Icon(Icons.local_offer_outlined, size: 18),
                label: Text('${promotion.code} • $appliedLabel'),
              ),
              TextButton.icon(
                onPressed: state.isApplyingPromotion ? null : onRemove,
                icon: const Icon(Icons.close),
                label: Text(removeLabel),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            promotion.detail ??
                (experience.isInternational
                    ? 'You saved ${formatter.format(promotion.savingsAmount)}'
                    : '${formatter.format(promotion.savingsAmount)}の割引が適用されました'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _CartSummarySheet extends StatelessWidget {
  const _CartSummarySheet({
    required this.state,
    required this.checkoutLabel,
    required this.onCheckout,
  });

  final CartViewState state;
  final String checkoutLabel;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final experience = state.snapshot.experience;
    final formatter = _CurrencyFormatter(experience);
    final theme = Theme.of(context);
    final estimate = state.estimate;

    final subtotalLabel = experience.isInternational ? 'Subtotal' : '小計';
    final discountLabel = experience.isInternational ? 'Discount' : '割引';
    final shippingLabel = experience.isInternational ? 'Shipping' : '送料';
    final taxLabel = experience.isInternational ? 'Tax' : '税額';
    final totalLabel = experience.isInternational ? 'Total' : '合計';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceS,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: Card(
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryRow(
                  label: subtotalLabel,
                  value: formatter.format(estimate.subtotal),
                ),
                if (estimate.discount > 0)
                  _SummaryRow(
                    label: discountLabel,
                    value: '-${formatter.format(estimate.discount)}',
                    valueStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                _SummaryRow(
                  label: shippingLabel,
                  value: formatter.format(estimate.shipping),
                ),
                if (estimate.tax > 0)
                  _SummaryRow(
                    label: taxLabel,
                    value: formatter.format(estimate.tax),
                  ),
                const Divider(height: AppTokens.spaceXXL),
                _SummaryRow(
                  label: totalLabel,
                  value: formatter.format(estimate.total),
                  valueStyle: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined),
                    const SizedBox(width: AppTokens.spaceS),
                    Expanded(
                      child: Text(
                        estimate.estimatedDelivery,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceL),
                FilledButton(onPressed: onCheckout, child: Text(checkoutLabel)),
              ],
            ),
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
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: valueStyle ?? theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CartEmptyState extends ConsumerWidget {
  const _CartEmptyState({required this.experience});

  final ExperienceGate experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final headline = experience.isInternational
        ? 'Your cart is empty'
        : 'カートには商品がありません';
    final description = experience.isInternational
        ? 'Save your favourite materials and kits, then return here to review promotions.'
        : '気になる素材やセットを追加すると、ここで編集やプロモ適用ができます。';
    final browseLabel = experience.isInternational ? 'Browse shop' : 'ショップを見る';

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceXXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 80),
          const SizedBox(height: AppTokens.spaceL),
          Text(headline, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.spaceL),
          FilledButton.tonal(
            onPressed: () {
              ref.read(appStateProvider.notifier).selectTab(AppTab.shop);
            },
            child: Text(browseLabel),
          ),
        ],
      ),
    );
  }
}

class _CartLoadingView extends StatelessWidget {
  const _CartLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _CartErrorView extends StatelessWidget {
  const _CartErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceXXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppTokens.spaceL),
              Text('Failed to load cart', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTokens.spaceS),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppTokens.spaceL),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyFormatter {
  _CurrencyFormatter(this.experience);

  final ExperienceGate experience;

  String format(double amount) {
    final symbol = experience.currencySymbol;
    if (experience.isInternational) {
      return '$symbol${amount.toStringAsFixed(2)}';
    }
    return '$symbol${amount.toStringAsFixed(0)}';
  }
}
