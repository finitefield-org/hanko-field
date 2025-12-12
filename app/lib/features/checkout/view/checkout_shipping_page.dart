// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_shipping_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutShippingPage extends ConsumerStatefulWidget {
  const CheckoutShippingPage({super.key});

  @override
  ConsumerState<CheckoutShippingPage> createState() =>
      _CheckoutShippingPageState();
}

class _CheckoutShippingPageState extends ConsumerState<CheckoutShippingPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(checkoutShippingViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: const BackButton(),
        title: Text(prefersEnglish ? 'Shipping method' : '配送方法'),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Shipping FAQs' : '配送FAQ',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _openFaq(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: _buildBody(
            context: context,
            prefersEnglish: prefersEnglish,
            state: state,
          ),
        ),
      ),
      bottomNavigationBar: _buildFooter(
        context: context,
        prefersEnglish: prefersEnglish,
        state: state,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required bool prefersEnglish,
    required AsyncValue<CheckoutShippingState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);

    if (state is AsyncLoading<CheckoutShippingState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 3, itemHeight: 140),
      );
    }

    if (state is AsyncError<CheckoutShippingState> &&
        state.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load shipping' : '配送方法を読み込めません',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () =>
              ref.refreshValue(checkoutShippingViewModel, keepPrevious: false),
        ),
      );
    }

    final data =
        state.valueOrNull ?? (throw StateError('Missing shipping state'));

    if (!data.hasAddress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'Add a shipping address' : '配送先を設定してください',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Choose or add an address first to unlock shipping options.'
                      : '先に配送先住所を選択・追加すると、配送方法を選べるようになります。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                SizedBox(height: tokens.spacing.md),
                AppButton(
                  label: prefersEnglish ? 'Select address' : '住所を選択',
                  expand: true,
                  onPressed: () =>
                      GoRouter.of(context).go(AppRoutePaths.checkoutAddress),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final selectState = ref.watch(checkoutShippingViewModel.selectShippingMut);
    final selecting = selectState is PendingMutationState;

    final visible = data.sortedOptions;
    if (visible.isEmpty) {
      return AppEmptyState(
        title: prefersEnglish ? 'No options' : '選択できる配送方法がありません',
        message: prefersEnglish
            ? 'Try switching to a different address.'
            : '別の住所でお試しください。',
        icon: Icons.local_shipping_outlined,
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () =>
          ref.refreshValue(checkoutShippingViewModel, keepPrevious: true),
      edgeOffset: tokens.spacing.sm,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          if (data.bannerMessage != null) ...[
            _ServiceBanner(
              message: data.bannerMessage!,
              prefersEnglish: prefersEnglish,
            ),
            SizedBox(height: tokens.spacing.sm),
          ],
          Row(
            children: [
              Chip(
                label: Text(
                  data.isInternational
                      ? (prefersEnglish ? 'International' : '海外配送')
                      : (prefersEnglish ? 'Domestic' : '国内配送'),
                ),
                avatar: Icon(
                  data.isInternational
                      ? Icons.flight_takeoff_outlined
                      : Icons.home_work_outlined,
                ),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (data.requiresExpress)
                Text(
                  prefersEnglish ? 'Promo requires express' : 'クーポン適用には速達が必要です',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.colors.warning),
                ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Pick a carrier and speed. Totals update automatically.'
                : '希望の配送スピードを選択してください。合計額は自動更新されます。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: ShippingFocus.values.map((focus) {
              final selected = data.focus == focus;
              return FilterChip(
                label: Text(switch (focus) {
                  ShippingFocus.speed => prefersEnglish ? 'Faster' : '最短',
                  ShippingFocus.cost => prefersEnglish ? 'Lower cost' : '低コスト',
                  ShippingFocus.balanced =>
                    prefersEnglish ? 'Balanced' : 'バランス',
                }),
                avatar: Icon(switch (focus) {
                  ShippingFocus.speed => Icons.bolt,
                  ShippingFocus.cost => Icons.savings_outlined,
                  ShippingFocus.balanced => Icons.tune_outlined,
                }),
                selected: selected,
                onSelected: (_) =>
                    ref.invoke(checkoutShippingViewModel.setFocus(focus)),
              );
            }).toList(),
          ),
          SizedBox(height: tokens.spacing.md),
          ...visible.map(
            (option) => Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.sm),
              child: _ShippingOptionCard(
                option: option,
                prefersEnglish: prefersEnglish,
                selected: data.selectedOption?.id == option.id,
                disabled: selecting,
                waived: data.shippingWaived && !option.express,
                requiresExpress: data.requiresExpress,
                onSelect: () =>
                    _selectOption(option.id, prefersEnglish: prefersEnglish),
              ),
            ),
          ),
          if (data.visibleOptions.length < data.options.length) ...[
            SizedBox(height: tokens.spacing.md),
            Text(
              prefersEnglish ? 'Other segment' : 'その他の配送セグメント',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              prefersEnglish
                  ? 'Switch address to use these routes.'
                  : '住所を切り替えると利用できます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            ...data.options
                .where((item) => item.international != data.isInternational)
                .map(
                  (option) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                    child: Opacity(
                      opacity: 0.45,
                      child: _ShippingOptionCard(
                        option: option,
                        prefersEnglish: prefersEnglish,
                        selected: false,
                        disabled: true,
                        waived: false,
                        requiresExpress: false,
                        onSelect: () {},
                      ),
                    ),
                  ),
                ),
          ],
          SizedBox(height: tokens.spacing.xl),
        ],
      ),
    );
  }

  Widget _buildFooter({
    required BuildContext context,
    required bool prefersEnglish,
    required AsyncValue<CheckoutShippingState> state,
  }) {
    final tokens = DesignTokensTheme.of(context);
    final data = state.valueOrNull;
    final selecting =
        ref.watch(checkoutShippingViewModel.selectShippingMut)
            is PendingMutationState;

    if (data == null) return const SizedBox.shrink();

    final selection = data.selectedOption;
    final shipping = data.shippingCost;
    final total = data.total;
    final eta = selection == null
        ? ''
        : (prefersEnglish
              ? 'Est. ${selection.minDays}-${selection.maxDays} days'
              : '目安 ${selection.minDays}〜${selection.maxDays}日');

    return Material(
      color: tokens.colors.surface,
      elevation: 10,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
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
                Icon(
                  Icons.local_shipping_outlined,
                  color: tokens.colors.primary,
                ),
                SizedBox(width: tokens.spacing.xs),
                Expanded(
                  child: Text(
                    eta.isEmpty
                        ? (prefersEnglish
                              ? 'Select a method to see delivery window'
                              : '配送方法を選択してください')
                        : eta,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                Text(
                  shipping.amount == 0
                      ? (prefersEnglish ? 'Free' : '無料')
                      : _formatMoney(shipping),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                Text(
                  prefersEnglish ? 'Total' : '合計',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  _formatMoney(total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            AppButton(
              label: prefersEnglish ? 'Continue to payment' : '支払いへ進む',
              expand: true,
              isLoading: selecting,
              onPressed: selection == null || selecting
                  ? null
                  : () => _goToPayment(prefersEnglish: prefersEnglish),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectOption(String id, {required bool prefersEnglish}) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.invoke(
      checkoutShippingViewModel.selectShipping(id),
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.error ??
                  (prefersEnglish
                      ? 'Could not select shipping.'
                      : '配送方法を選択できませんでした。'),
            ),
          ),
        );
    }
  }

  void _openFaq() {
    final router = GoRouter.of(context);
    router.push(AppRoutePaths.supportFaq);
  }

  Future<void> _goToPayment({required bool prefersEnglish}) async {
    final messenger = ScaffoldMessenger.of(context);
    final selection = ref.container
        .read(checkoutShippingViewModel)
        .valueOrNull
        ?.selectedOption;
    if (selection == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              prefersEnglish
                  ? 'Select a shipping method first.'
                  : '配送方法を選択してください。',
            ),
          ),
        );
      return;
    }

    final flow = ref.container.read(checkoutFlowProvider);
    if (flow.shippingMethodId != selection.id) {
      final result = await ref.invoke(
        checkoutShippingViewModel.selectShipping(selection.id),
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                result.error ??
                    (prefersEnglish
                        ? 'Could not save shipping selection.'
                        : '配送方法の保存に失敗しました。'),
              ),
            ),
          );
        return;
      }
    }

    GoRouter.of(context).go(AppRoutePaths.checkoutPayment);
  }
}

class _ShippingOptionCard extends StatelessWidget {
  const _ShippingOptionCard({
    required this.option,
    required this.prefersEnglish,
    required this.selected,
    required this.disabled,
    required this.waived,
    required this.requiresExpress,
    required this.onSelect,
  });

  final ShippingOption option;
  final bool prefersEnglish;
  final bool selected;
  final bool disabled;
  final bool waived;
  final bool requiresExpress;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final effectiveCost = waived && !option.express
        ? Money(amount: 0, currency: option.cost.currency)
        : option.cost;

    final radius = BorderRadius.circular(tokens.radii.md);
    final tile = Material(
      color: selected ? tokens.colors.surfaceVariant : tokens.colors.surface,
      elevation: selected ? 4 : 1,
      shadowColor: tokens.colors.outline.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: tokens.colors.outline.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: disabled ? null : onSelect,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    option.international
                        ? Icons.flight_takeoff_outlined
                        : Icons.local_shipping_outlined,
                    color: tokens.colors.primary,
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                option.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (option.badge != null) ...[
                              SizedBox(width: tokens.spacing.xs),
                              Chip(
                                label: Text(option.badge!),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: tokens.spacing.xs),
                        Text(
                          option.carrier,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.colors.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        effectiveCost.amount == 0
                            ? (prefersEnglish ? 'Free' : '無料')
                            : _formatMoney(effectiveCost),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        prefersEnglish ? 'Est.' : '目安',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '${option.minDays}-${option.maxDays} ${prefersEnglish ? 'days' : '日'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? tokens.colors.primary
                        : tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: tokens.colors.onSurface,
                  ),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(
                    child: Text(
                      prefersEnglish
                          ? 'Delivers in ${option.minDays}-${option.maxDays} days'
                          : '${option.minDays}〜${option.maxDays}日でお届け',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (option.express)
                    Chip(
                      label: Text(
                        prefersEnglish ? 'Express' : '速達',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      avatar: const Icon(Icons.bolt, size: 16),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              if (option.note != null) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  option.note!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (requiresExpress && !option.express) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'This option cannot be used with the current promo.'
                      : '現在のクーポンでは利用できません。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.colors.warning),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return AbsorbPointer(absorbing: disabled, child: tile);
  }
}

class _ServiceBanner extends StatelessWidget {
  const _ServiceBanner({required this.message, required this.prefersEnglish});

  final String message;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Material(
      color: tokens.colors.surfaceVariant,
      borderRadius: BorderRadius.circular(tokens.radii.md),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.md),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: tokens.colors.warning),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefersEnglish ? 'Service notice' : '配送のお知らせ',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
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
