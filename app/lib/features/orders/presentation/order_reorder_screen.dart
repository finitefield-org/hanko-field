import 'package:app/core/domain/entities/order_reorder.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/orders/application/order_reorder_preview_provider.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OrderReorderScreen extends ConsumerStatefulWidget {
  const OrderReorderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderReorderScreen> createState() => _OrderReorderScreenState();
}

class _OrderReorderScreenState extends ConsumerState<OrderReorderScreen> {
  Set<String> _selectedLineIds = <String>{};
  bool _selectionInitialized = false;
  bool _isSubmitting = false;
  OrderReorderPreview? _currentPreview;

  void _handlePreviewUpdate(OrderReorderPreview preview) {
    final availableIds = <String>{
      for (final line in preview.lines)
        if (line.isAvailable) line.id,
    };
    if (!_selectionInitialized) {
      setState(() {
        _currentPreview = preview;
        _selectedLineIds = availableIds;
        _selectionInitialized = true;
      });
      return;
    }
    final retained = _selectedLineIds.intersection(availableIds);
    setState(() {
      _currentPreview = preview;
      _selectedLineIds = retained.isNotEmpty ? retained : availableIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<OrderReorderPreview>>(
      orderReorderPreviewProvider(widget.orderId),
      (previous, next) {
        next.whenData(_handlePreviewUpdate);
      },
    );
    final l10n = AppLocalizations.of(context);
    final previewAsync = ref.watch(orderReorderPreviewProvider(widget.orderId));

    return Scaffold(
      body: previewAsync.when(
        data: (preview) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orderReorderPreviewProvider(widget.orderId));
            await ref.read(orderReorderPreviewProvider(widget.orderId).future);
          },
          displacement: 72,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(context, l10n, preview),
              if (_shouldShowBanner(preview))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceL,
                      AppTokens.spaceS,
                      AppTokens.spaceL,
                      0,
                    ),
                    child: _ReorderNoticeBanner(preview: preview, l10n: l10n),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceL,
                    AppTokens.spaceS,
                  ),
                  child: _SelectionHeader(
                    selectedCount: _selectedLineIds.length,
                    availableCount: _availableCount(preview),
                    onToggleAll: (value) => _toggleAll(value, preview),
                    allSelected: _allAvailableSelected(preview),
                    l10n: l10n,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceL,
                  vertical: AppTokens.spaceXS,
                ),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final line = preview.lines[index];
                    final isSelected = _selectedLineIds.contains(line.id);
                    return _ReorderLineTile(
                      line: line,
                      isSelected: isSelected,
                      currency: preview.order.currency,
                      l10n: l10n,
                      onToggle: (value) => _toggleLine(line, value),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppTokens.spaceS),
                  itemCount: preview.lines.length,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
        ),
        loading: () => const _OrderReorderLoadingView(),
        error: (error, stackTrace) => _OrderReorderErrorView(
          message: l10n.orderReorderLoadError,
          onRetry: () =>
              ref.invalidate(orderReorderPreviewProvider(widget.orderId)),
        ),
      ),
      bottomNavigationBar: previewAsync.maybeWhen(
        data: (preview) => _ReorderBottomBar(
          hasSelection: _selectedLineIds.isNotEmpty,
          isSubmitting: _isSubmitting,
          onSubmit: () => _handleSubmit(context, l10n),
          onCancel: () => ref.read(appStateProvider.notifier).pop(),
          l10n: l10n,
        ),
        orElse: () => null,
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    OrderReorderPreview preview,
  ) {
    final order = preview.order;
    final number = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    final placedAt = order.placedAt ?? order.createdAt;
    final dateFormatter = DateFormat.yMMMMd(l10n.localeName);
    final dateLabel = dateFormatter.format(placedAt);
    return SliverAppBar(
      pinned: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.orderReorderAppBarTitle(number),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.orderReorderAppBarSubtitle(dateLabel),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  bool _shouldShowBanner(OrderReorderPreview preview) {
    return preview.hasUnavailable || preview.hasPriceChanges;
  }

  int _availableCount(OrderReorderPreview preview) {
    return preview.lines.where((line) => line.isAvailable).length;
  }

  bool _allAvailableSelected(OrderReorderPreview preview) {
    final available = _availableCount(preview);
    return available > 0 && _selectedLineIds.length == available;
  }

  void _toggleLine(OrderReorderLine line, bool value) {
    if (!line.isAvailable) {
      return;
    }
    setState(() {
      final updated = _selectedLineIds.toSet();
      if (value) {
        updated.add(line.id);
      } else {
        updated.remove(line.id);
      }
      _selectedLineIds = updated;
    });
  }

  void _toggleAll(bool selectAll, OrderReorderPreview preview) {
    final availableIds = <String>{
      for (final line in preview.lines)
        if (line.isAvailable) line.id,
    };
    setState(() {
      _selectedLineIds = selectAll ? availableIds : <String>{};
    });
  }

  Future<void> _handleSubmit(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final preview = _currentPreview;
    if (preview == null ||
        _selectedLineIds.isEmpty ||
        _isSubmitting ||
        !mounted) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    final repository = ref.read(orderRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await repository.reorder(
        widget.orderId,
        lineIds: _selectedLineIds,
      );
      await ref.read(cartControllerProvider.notifier).reload();
      ref.invalidate(orderReorderPreviewProvider(widget.orderId));

      final addedLabel = l10n.orderReorderResultAdded(result.addedCount);
      final skippedLabel = result.skippedCount > 0
          ? l10n.orderReorderResultSkipped(result.skippedCount)
          : null;
      final priceLabel = result.hasPriceAdjustments
          ? l10n.orderReorderResultPriceAdjusted
          : null;
      final parts = <String>[addedLabel];
      if (skippedLabel != null) {
        parts.add(skippedLabel);
      }
      if (priceLabel != null) {
        parts.add(priceLabel);
      }
      messenger.showSnackBar(SnackBar(content: Text(parts.join(' • '))));

      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _selectedLineIds = result.addedLineIds.toSet();
      });

      ref.read(appStateProvider.notifier).push(CheckoutRoute(['review']));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderReorderSubmitError)),
      );
    }
  }
}

class _OrderReorderLoadingView extends StatelessWidget {
  const _OrderReorderLoadingView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          sliver: SliverList.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: AppTokens.spaceM),
              child: AppSkeletonBlock(height: 92),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderReorderErrorView extends StatelessWidget {
  const _OrderReorderErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        title: message,
        primaryAction: AppButton(
          label: AppLocalizations.of(context).orderReorderRetryLabel,
          onPressed: onRetry,
          fullWidth: true,
        ),
      ),
    );
  }
}

class _ReorderNoticeBanner extends StatelessWidget {
  const _ReorderNoticeBanner({required this.preview, required this.l10n});

  final OrderReorderPreview preview;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final messages = <String>[];
    if (preview.hasUnavailable) {
      messages.add(l10n.orderReorderBannerUnavailable);
    }
    if (preview.hasPriceChanges) {
      messages.add(l10n.orderReorderBannerPriceChanges);
    }
    return MaterialBanner(
      content: Text(messages.join(' ')),
      leading: const Icon(Icons.info_outline),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      dividerColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      actions: [
        TextButton(
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({
    required this.selectedCount,
    required this.availableCount,
    required this.onToggleAll,
    required this.allSelected,
    required this.l10n,
  });

  final int selectedCount;
  final int availableCount;
  final ValueChanged<bool>? onToggleAll;
  final bool allSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = availableCount == 0
        ? l10n.orderReorderNoItemsAvailable
        : l10n.orderReorderSelectionSummary(selectedCount, availableCount);
    return Row(
      children: [
        Checkbox(
          value: availableCount > 0 && allSelected,
          onChanged: availableCount == 0
              ? null
              : (value) => onToggleAll?.call(value ?? false),
        ),
        const SizedBox(width: AppTokens.spaceS),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (availableCount > 0)
          TextButton(
            onPressed: () => onToggleAll?.call(!allSelected),
            child: Text(
              allSelected
                  ? l10n.orderReorderSelectNone
                  : l10n.orderReorderSelectAll,
            ),
          ),
      ],
    );
  }
}

class _ReorderLineTile extends StatelessWidget {
  const _ReorderLineTile({
    required this.line,
    required this.isSelected,
    required this.currency,
    required this.l10n,
    required this.onToggle,
  });

  final OrderReorderLine line;
  final bool isSelected;
  final String currency;
  final AppLocalizations l10n;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = line.item.designSnapshot;
    final emoji = snapshot?['emoji'] as String? ?? '印';
    final background =
        _parseColor(snapshot?['background']) ??
        scheme.secondaryContainer.withValues(alpha: 0.4);
    final title = snapshot?['title'] as String? ?? line.item.name;
    final quantityLabel = l10n.orderReorderQuantity(line.item.quantity);
    final priceLabel = _formatCurrency(context, line.item.unitPrice, currency);
    final updatedPriceLabel = _formatCurrency(
      context,
      line.effectiveUnitPrice,
      currency,
    );
    final availabilityChip = _buildAvailabilityChip(context, scheme);

    return InkWell(
      borderRadius: AppTokens.radiusL,
      onTap: line.isAvailable ? () => onToggle(!isSelected) : null,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        decoration: BoxDecoration(
          borderRadius: AppTokens.radiusL,
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: line.isAvailable
                  ? (value) => onToggle(value ?? false)
                  : null,
            ),
            const SizedBox(width: AppTokens.spaceS),
            _DesignPreviewTile(emoji: emoji, color: background),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? l10n.ordersUnknownItem,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    l10n.orderReorderSkuLabel(line.item.sku),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(
                    '$quantityLabel • ${line.hasPriceChange ? updatedPriceLabel : priceLabel}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (line.hasPriceChange)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                      child: Text(
                        l10n.orderReorderPriceChangeLabel(
                          updatedPriceLabel,
                          priceLabel,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (line.item.options != null &&
                      line.item.options!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceS),
                      child: Wrap(
                        spacing: AppTokens.spaceXS,
                        runSpacing: AppTokens.spaceXS,
                        children: line.item.options!.entries
                            .map(
                              (entry) => Chip(
                                label: Text(entry.value.toString()),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (line.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceS),
                      child: Text(
                        line.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (availabilityChip != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTokens.spaceS),
                      child: availabilityChip,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildAvailabilityChip(BuildContext context, ColorScheme scheme) {
    switch (line.availability) {
      case OrderReorderLineAvailability.available:
        return null;
      case OrderReorderLineAvailability.lowStock:
        return Chip(
          label: Text(l10n.orderReorderAvailabilityLowStock),
          backgroundColor: scheme.tertiaryContainer,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case OrderReorderLineAvailability.unavailable:
        return Chip(
          label: Text(l10n.orderReorderAvailabilityUnavailable),
          backgroundColor: scheme.errorContainer,
          labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    }
  }
}

class _ReorderBottomBar extends StatelessWidget {
  const _ReorderBottomBar({
    required this.hasSelection,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onCancel,
    required this.l10n,
  });

  final bool hasSelection;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final disabled = isSubmitting || !hasSelection;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppTokens.spaceL,
        AppTokens.spaceS,
        AppTokens.spaceL,
        AppTokens.spaceL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonal(
            onPressed: disabled ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.orderReorderPrimaryCta),
          ),
          TextButton(
            onPressed: isSubmitting ? null : onCancel,
            child: Text(l10n.orderReorderCancelCta),
          ),
        ],
      ),
    );
  }
}

class _DesignPreviewTile extends StatelessWidget {
  const _DesignPreviewTile({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved = color.withValues(alpha: 0.75);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: AppTokens.radiusL,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}

Color? _parseColor(Object? value) {
  if (value is int) {
    return Color(value);
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed == null ? null : Color(parsed);
  }
  return null;
}

String _formatCurrency(BuildContext context, num amount, String currency) {
  final locale = Localizations.localeOf(context).toString();
  final formatter = NumberFormat.currency(
    locale: locale,
    name: currency,
    symbol: NumberFormat.simpleCurrency(name: currency).currencySymbol,
    decimalDigits: 0,
  );
  return formatter.format(amount);
}
