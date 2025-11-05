import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_shipping_controller.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutShippingScreen extends ConsumerStatefulWidget {
  const CheckoutShippingScreen({super.key});

  @override
  ConsumerState<CheckoutShippingScreen> createState() =>
      _CheckoutShippingScreenState();
}

class _CheckoutShippingScreenState
    extends ConsumerState<CheckoutShippingScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    ref.listen<AsyncValue<CheckoutShippingState>>(
      checkoutShippingControllerProvider,
      (previous, next) {
        final prevError = previous?.value?.errorMessage;
        final nextError = next.value?.errorMessage;
        if (nextError != null && nextError != prevError) {
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(nextError)));
          ref.read(checkoutShippingControllerProvider.notifier).clearError();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  CheckoutShippingController get _controller =>
      ref.read(checkoutShippingControllerProvider.notifier);

  Future<void> _showFaqSheet(bool isInternational) async {
    final title = isInternational ? 'Shipping FAQ' : '配送のよくある質問';
    final body = isInternational
        ? 'Learn about customs, delivery windows, and how express upgrades work.'
        : '配送スケジュールやエクスプレス便の条件などをご確認いただけます。';
    final closeLabel = isInternational ? 'Close' : '閉じる';
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(closeLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirm(CheckoutShippingState state) async {
    if (state.selectedOptionId == null) {
      final experience = ref.read(experienceGateProvider).value;
      final isIntl = experience?.isInternational ?? false;
      final message = isIntl
          ? 'Select a shipping option to continue.'
          : '配送方法を選択してください。';
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final experienceAsync = ref.watch(experienceGateProvider);
    final isIntl = experienceAsync.value?.isInternational ?? false;
    final asyncState = ref.watch(checkoutShippingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isIntl ? 'Shipping options' : '配送方法'),
        actions: [
          IconButton(
            tooltip: isIntl ? 'View FAQs' : 'FAQを見る',
            onPressed: () => _showFaqSheet(isIntl),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _ShippingLoadingView(),
          error: (error, stackTrace) => _ShippingErrorView(
            message: error.toString(),
            onRetry: _controller.refresh,
            isInternational: isIntl,
          ),
          data: (state) => RefreshIndicator(
            onRefresh: _controller.refresh,
            child: _ShippingListView(
              state: state,
              isInternational: isIntl,
              controller: _controller,
              scrollController: _scrollController,
            ),
          ),
        ),
      ),
      bottomNavigationBar: asyncState.maybeWhen(
        data: (state) {
          final confirmLabel = isIntl ? 'Continue' : '次へ';
          return SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FilledButton(
              onPressed: state.isSaving ? null : () => _handleConfirm(state),
              child: Text(confirmLabel),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}

class _ShippingListView extends StatelessWidget {
  const _ShippingListView({
    required this.state,
    required this.isInternational,
    required this.controller,
    required this.scrollController,
  });

  final CheckoutShippingState state;
  final bool isInternational;
  final CheckoutShippingController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = <Widget>[];
    if (state.isSaving) {
      sections.add(const LinearProgressIndicator(minHeight: 2));
    }
    if (state.hasAdvisory && state.advisory != null) {
      final advisory = state.advisory!;
      final colorScheme = Theme.of(context).colorScheme;
      final background = advisory.level == CheckoutShippingAdvisoryLevel.warning
          ? colorScheme.errorContainer
          : colorScheme.secondaryContainer;
      final foreground = advisory.level == CheckoutShippingAdvisoryLevel.warning
          ? colorScheme.onErrorContainer
          : colorScheme.onSecondaryContainer;
      sections.add(
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTokens.spaceL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advisory.title,
                style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              ),
              const SizedBox(height: 8),
              Text(
                advisory.message,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      );
    }
    sections.add(
      _ShippingFocusChips(
        state: state,
        isInternational: isInternational,
        onChanged: controller.changeFocus,
      ),
    );
    for (final region in CheckoutShippingRegion.values) {
      final options = state.optionsForRegion(region);
      if (options.isEmpty) {
        continue;
      }
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            _regionLabel(region, isInternational),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final option in options) {
        final isSelected = state.selectedOptionId == option.id;
        final isRestricted = state.isRestricted(option.id);
        sections.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _ShippingOptionCard(
              option: option,
              isSelected: isSelected,
              isDisabled: state.isSaving || isRestricted,
              isInternational: isInternational,
              onSelected: () => controller.selectOption(option.id),
              showRestriction: isRestricted,
            ),
          ),
        );
      }
    }
    if (sections.length == 1) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isInternational
                ? 'No shipping options available.'
                : '利用可能な配送方法がありません。',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      children: sections,
    );
  }
}

class _ShippingFocusChips extends StatelessWidget {
  const _ShippingFocusChips({
    required this.state,
    required this.isInternational,
    required this.onChanged,
  });

  final CheckoutShippingState state;
  final bool isInternational;
  final ValueChanged<CheckoutShippingFocus> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        focus: CheckoutShippingFocus.balance,
        label: isInternational ? 'Balanced' : 'バランス',
      ),
      (
        focus: CheckoutShippingFocus.cost,
        label: isInternational ? 'Cost saver' : 'コスパ重視',
      ),
      (
        focus: CheckoutShippingFocus.speed,
        label: isInternational ? 'Fastest' : '速度重視',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        children: [
          for (final entry in entries)
            FilterChip(
              label: Text(entry.label),
              selected: state.focus == entry.focus,
              onSelected: (_) => onChanged(entry.focus),
            ),
        ],
      ),
    );
  }
}

class _ShippingOptionCard extends StatelessWidget {
  const _ShippingOptionCard({
    required this.option,
    required this.isSelected,
    required this.isDisabled,
    required this.isInternational,
    required this.onSelected,
    required this.showRestriction,
  });

  final CheckoutShippingOption option;
  final bool isSelected;
  final bool isDisabled;
  final bool isInternational;
  final VoidCallback onSelected;
  final bool showRestriction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isSelected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final foreground = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final priceText = option.price <= 0
        ? (isInternational ? 'Free' : '無料')
        : option.currency == 'USD'
        ? '\$${option.price.toStringAsFixed(2)}'
        : '¥${option.price.toStringAsFixed(0)}';
    final deliveryLabel = isInternational ? 'Estimated delivery' : 'お届け目安';
    final restrictionText = isInternational
        ? 'FREESHIP requires express shipping.'
        : 'FREESHIPご利用中はエクスプレス便をご選択ください。';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDisabled ? 0.6 : 1,
      child: Card(
        elevation: isSelected ? 6 : 1,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.spaceL),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.spaceL),
          onTap: isDisabled ? null : onSelected,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  option.label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: foreground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (option.badge != null) ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(option.badge!),
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  labelStyle: theme.textTheme.labelMedium
                                      ?.copyWith(
                                        color: theme
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: foreground.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          priceText,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: foreground.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$deliveryLabel • ${option.estimatedDelivery}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                if (option.perks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final perk in option.perks)
                        InputChip(label: Text(perk), onPressed: null),
                    ],
                  ),
                ],
                if (showRestriction) ...[
                  const SizedBox(height: 12),
                  Text(
                    restrictionText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShippingLoadingView extends StatelessWidget {
  const _ShippingLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ShippingErrorView extends StatelessWidget {
  const _ShippingErrorView({
    required this.message,
    required this.onRetry,
    required this.isInternational,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final retryLabel = isInternational ? 'Retry' : '再試行';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

String _regionLabel(CheckoutShippingRegion region, bool isInternational) {
  return switch (region) {
    CheckoutShippingRegion.domestic =>
      isInternational ? 'Domestic shipping' : '国内配送',
    CheckoutShippingRegion.international =>
      isInternational ? 'International shipping' : '国際配送',
  };
}
