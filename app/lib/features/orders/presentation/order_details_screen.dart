import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/orders/application/order_details_provider.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({
    required this.orderId,
    this.subPage = '',
    super.key,
  });

  final String orderId;
  final String subPage;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _isReordering = false;
  bool _isRequestingInvoice = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncOrder = ref.watch(orderDetailsProvider(widget.orderId));
    final order = asyncOrder.asData?.value;

    final orderNumber = order?.orderNumber ?? widget.orderId;
    final tabs = [
      Tab(text: l10n.orderDetailsTabSummary),
      Tab(text: l10n.orderDetailsTabTimeline),
      Tab(text: l10n.orderDetailsTabFiles),
    ];

    final initialIndex = _initialTabIndex(widget.subPage);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar.medium(
                pinned: true,
                title: Text(l10n.orderDetailsAppBarTitle(orderNumber)),
                actions: [
                  _ReorderActionButton(
                    isLoading: _isReordering,
                    onPressed: order == null || _isReordering
                        ? null
                        : () => _handleReorder(context, l10n),
                    tooltip: l10n.orderDetailsActionReorder,
                  ),
                  IconButton(
                    tooltip: l10n.orderDetailsActionShare,
                    onPressed: order == null
                        ? null
                        : () => _handleShare(context, l10n, order),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ],
                bottom: TabBar(tabs: tabs),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildSummaryTab(context, l10n, asyncOrder),
              _buildTimelineTab(context, l10n, asyncOrder),
              _buildFilesTab(context, l10n, asyncOrder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<Order> asyncOrder,
  ) {
    return asyncOrder.when(
      data: (order) {
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(orderDetailsProvider(widget.orderId).future),
          displacement: 72,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceXL,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_shouldShowSupportBanner(order))
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTokens.spaceL,
                        ),
                        child: _SupportBanner(
                          l10n: l10n,
                          onContactTap: () => _handleSupport(context, l10n),
                          onReorderTap: () => _handleReorder(context, l10n),
                          onInvoiceTap: () => _handleInvoice(context, l10n),
                          isReordering: _isReordering,
                          isRequestingInvoice: _isRequestingInvoice,
                        ),
                      ),
                    _OrderOverviewHeader(order: order, l10n: l10n),
                    const SizedBox(height: AppTokens.spaceXL),
                    _SectionTitle(
                      label: l10n.orderDetailsItemsSectionTitle,
                      trailing: Text(
                        l10n.orderDetailsItemsSectionCount(
                          order.lineItems.length,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceM),
                    ..._buildLineItems(context, l10n, order),
                    const SizedBox(height: AppTokens.spaceXL),
                    _SectionTitle(
                      label: l10n.orderDetailsTotalsSectionTitle,
                      trailing: Text(
                        l10n.orderDetailsLastUpdated(
                          _formatRelativeTimestamp(l10n, order.updatedAt),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceM),
                    _OrderTotalsCard(order: order, l10n: l10n),
                    const SizedBox(height: AppTokens.spaceXL),
                    _SectionTitle(
                      label: l10n.orderDetailsAddressesSectionTitle,
                    ),
                    const SizedBox(height: AppTokens.spaceM),
                    _OrderAddressesSection(order: order, l10n: l10n),
                    if (order.contact != null) ...[
                      const SizedBox(height: AppTokens.spaceXL),
                      _SectionTitle(
                        label: l10n.orderDetailsContactSectionTitle,
                      ),
                      const SizedBox(height: AppTokens.spaceM),
                      _OrderContactCard(contact: order.contact!, l10n: l10n),
                    ],
                    const SizedBox(height: AppTokens.spaceXL),
                    if (_hasDesignSnapshots(order))
                      _SectionTitle(label: l10n.orderDetailsDesignSectionTitle),
                    if (_hasDesignSnapshots(order)) ...[
                      const SizedBox(height: AppTokens.spaceM),
                      _DesignSnapshotGallery(order: order),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const _OrderDetailsLoadingView(),
      error: (error, stackTrace) => _OrderDetailsErrorView(
        message: l10n.orderDetailsLoadErrorMessage,
        actionLabel: l10n.orderDetailsRetryLabel,
        onRetry: () => ref.refresh(orderDetailsProvider(widget.orderId).future),
      ),
    );
  }

  Widget _buildTimelineTab(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<Order> asyncOrder,
  ) {
    return asyncOrder.when(
      data: (order) {
        return _PlaceholderTab(
          icon: Icons.route_outlined,
          title: l10n.orderDetailsTimelineTabTitle,
          message: l10n.orderDetailsTimelinePlaceholder,
        );
      },
      loading: () => const _OrderDetailsLoadingView(),
      error: (error, stackTrace) => _OrderDetailsErrorView(
        message: l10n.orderDetailsLoadErrorMessage,
        actionLabel: l10n.orderDetailsRetryLabel,
        onRetry: null,
      ),
    );
  }

  Widget _buildFilesTab(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<Order> asyncOrder,
  ) {
    return asyncOrder.when(
      data: (order) {
        return _PlaceholderTab(
          icon: Icons.folder_shared_outlined,
          title: l10n.orderDetailsFilesTabTitle,
          message: l10n.orderDetailsFilesPlaceholder,
        );
      },
      loading: () => const _OrderDetailsLoadingView(),
      error: (error, stackTrace) => _OrderDetailsErrorView(
        message: l10n.orderDetailsLoadErrorMessage,
        actionLabel: l10n.orderDetailsRetryLabel,
        onRetry: () => ref.refresh(orderDetailsProvider(widget.orderId).future),
      ),
    );
  }

  Future<void> _handleReorder(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (_isReordering) {
      return;
    }
    setState(() {
      _isReordering = true;
    });
    final repository = ref.read(orderRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await repository.reorder(widget.orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isReordering = false;
      });
      _showSnackBar(
        messenger,
        l10n.orderDetailsReorderSuccess(order.orderNumber),
      );
      ref.invalidate(orderDetailsProvider(widget.orderId));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isReordering = false;
      });
      _showSnackBar(messenger, l10n.orderDetailsReorderError);
    }
  }

  Future<void> _handleInvoice(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (_isRequestingInvoice) {
      return;
    }
    setState(() {
      _isRequestingInvoice = true;
    });
    final repository = ref.read(orderRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final order = await repository.requestInvoice(widget.orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isRequestingInvoice = false;
      });
      _showSnackBar(
        messenger,
        l10n.orderDetailsInvoiceSuccess(order.orderNumber),
      );
      ref.invalidate(orderDetailsProvider(widget.orderId));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRequestingInvoice = false;
      });
      _showSnackBar(messenger, l10n.orderDetailsInvoiceError);
    }
  }

  void _handleSupport(BuildContext context, AppLocalizations l10n) {
    final messenger = ScaffoldMessenger.of(context);
    _showSnackBar(messenger, l10n.orderDetailsSupportMessage);
  }

  void _handleShare(BuildContext context, AppLocalizations l10n, Order order) {
    final total = _formatCurrency(context, order.totals.total, order.currency);
    final subject = l10n.orderDetailsShareSubject(order.orderNumber);
    final message = l10n.orderDetailsShareBody(order.orderNumber, total);
    Share.share(message, subject: subject);
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReorderActionButton extends StatelessWidget {
  const _ReorderActionButton({
    required this.isLoading,
    required this.onPressed,
    required this.tooltip,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(right: AppTokens.spaceS),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: const Icon(Icons.shopping_bag_outlined),
    );
  }
}

class _OrderDetailsLoadingView extends StatelessWidget {
  const _OrderDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTokens.spaceL),
      child: AppListSkeleton(items: 4),
    );
  }
}

class _OrderDetailsErrorView extends StatelessWidget {
  const _OrderDetailsErrorView({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: message,
      icon: const Icon(Icons.error_outline),
      primaryAction: onRetry == null
          ? null
          : AppButton(
              label: actionLabel,
              onPressed: onRetry,
              variant: AppButtonVariant.primary,
            ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppTokens.spaceL),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  const _SupportBanner({
    required this.l10n,
    required this.onContactTap,
    required this.onReorderTap,
    required this.onInvoiceTap,
    required this.isReordering,
    required this.isRequestingInvoice,
  });

  final AppLocalizations l10n;
  final VoidCallback onContactTap;
  final VoidCallback onReorderTap;
  final VoidCallback onInvoiceTap;
  final bool isReordering;
  final bool isRequestingInvoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = [
      ActionChip(
        label: Text(l10n.orderDetailsActionSupport),
        avatar: const Icon(Icons.support_agent_outlined),
        onPressed: onContactTap,
      ),
      ActionChip(
        label: Text(l10n.orderDetailsActionReorder),
        avatar: isReordering
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.shopping_basket_outlined),
        onPressed: isReordering ? null : onReorderTap,
      ),
      ActionChip(
        label: Text(l10n.orderDetailsActionInvoice),
        avatar: isRequestingInvoice
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long_outlined),
        onPressed: isRequestingInvoice ? null : onInvoiceTap,
      ),
    ];

    return MaterialBanner(
      backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(AppTokens.spaceL),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium,
      leading: Icon(Icons.info_outline, color: scheme.secondary),
      actions: const [SizedBox.shrink()],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.orderDetailsSupportBannerTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.orderDetailsSupportBannerMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppTokens.spaceM),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _OrderOverviewHeader extends StatelessWidget {
  const _OrderOverviewHeader({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalFormatted = _formatCurrency(
      context,
      order.totals.total,
      order.currency,
    );
    final timelineEntries = _buildTimelineEntries(order, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.orderDetailsHeadline(order.orderNumber),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  Row(
                    children: [
                      _StatusChip(status: order.status, l10n: l10n),
                      const SizedBox(width: AppTokens.spaceS),
                      Text(
                        totalFormatted,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.spaceS),
                    Text(
                      order.notes!.values.join('\n'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.orderDetailsProgressTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceM),
              Wrap(
                spacing: AppTokens.spaceXL,
                runSpacing: AppTokens.spaceL,
                children: timelineEntries,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final OrderStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _statusColors(status, scheme);
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppTokens.radiusS,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceS,
        vertical: AppTokens.spaceXS,
      ),
      child: Text(
        _statusLabel(status, l10n),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OrderTotalsCard extends StatelessWidget {
  const _OrderTotalsCard({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final totals = order.totals;
    final entries = [
      _TotalEntry(
        label: l10n.orderDetailsSubtotalLabel,
        value: totals.subtotal,
        currency: order.currency,
      ),
      _TotalEntry(
        label: l10n.orderDetailsDiscountLabel,
        value: -totals.discount,
        currency: order.currency,
      ),
      _TotalEntry(
        label: l10n.orderDetailsShippingLabel,
        value: totals.shipping,
        currency: order.currency,
      ),
      _TotalEntry(
        label: l10n.orderDetailsFeesLabel,
        value: totals.fees,
        currency: order.currency,
      ),
      _TotalEntry(
        label: l10n.orderDetailsTaxLabel,
        value: totals.tax,
        currency: order.currency,
      ),
    ];
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _TotalRow(entry: entries[i]),
            if (i != entries.length - 1)
              const Divider(height: AppTokens.spaceXL),
          ],
          const SizedBox(height: AppTokens.spaceL),
          const Divider(height: AppTokens.spaceL),
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceL),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.orderDetailsTotalLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatCurrency(context, totals.total, order.currency),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalEntry {
  const _TotalEntry({
    required this.label,
    required this.value,
    required this.currency,
  });

  final String label;
  final int value;
  final String currency;
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.entry});

  final _TotalEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            entry.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          _formatCurrency(context, entry.value, entry.currency),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

List<Widget> _buildLineItems(
  BuildContext context,
  AppLocalizations l10n,
  Order order,
) {
  return [
    for (final item in order.lineItems)
      Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
        child: _OrderLineItemCard(
          item: item,
          currency: order.currency,
          l10n: l10n,
        ),
      ),
  ];
}

class _OrderLineItemCard extends StatelessWidget {
  const _OrderLineItemCard({
    required this.item,
    required this.currency,
    required this.l10n,
  });

  final OrderLineItem item;
  final String currency;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = item.designSnapshot;
    final emoji = snapshot?['emoji'] as String? ?? '印';
    final background =
        _parseColor(snapshot?['background']) ??
        scheme.secondaryContainer.withValues(alpha: 0.4);
    final title = snapshot?['title'] as String? ?? item.name;
    final quantityLabel = l10n.orderDetailsQuantityLabel(item.quantity);
    final price = _formatCurrency(context, item.unitPrice, currency);
    final total = _formatCurrency(context, item.total, currency);

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DesignPreviewTile(emoji: emoji, color: background),
          const SizedBox(width: AppTokens.spaceL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? l10n.ordersUnknownItem,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  l10n.orderDetailsSkuLabel(item.sku),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  '$quantityLabel • $price',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (item.options != null && item.options!.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.spaceS),
                  Wrap(
                    spacing: AppTokens.spaceS,
                    runSpacing: AppTokens.spaceS,
                    children: item.options!.entries
                        .map(
                          (entry) => Chip(
                            label: Text(
                              '${entry.key}: ${entry.value}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceM),
          Text(
            total,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: AppTokens.radiusL,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 32)),
    );
  }
}

class _OrderAddressesSection extends StatelessWidget {
  const _OrderAddressesSection({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[
      _AddressCard(
        title: l10n.orderDetailsShippingAddressLabel,
        address: order.shippingAddress,
        l10n: l10n,
        icon: Icons.local_shipping_outlined,
      ),
      _AddressCard(
        title: l10n.orderDetailsBillingAddressLabel,
        address: order.billingAddress,
        l10n: l10n,
        icon: Icons.receipt_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (int i = 0; i < widgets.length; i++) ...[
                widgets[i],
                if (i != widgets.length - 1)
                  const SizedBox(height: AppTokens.spaceM),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widgets[0]),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(child: widgets[1]),
          ],
        );
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.address,
    required this.l10n,
    required this.icon,
  });

  final String title;
  final OrderAddress? address;
  final AppLocalizations l10n;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: AppTokens.spaceS),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          if (address == null)
            Text(
              l10n.orderDetailsAddressUnavailable,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address!.recipient),
                Text(address!.line1),
                if (address!.line2 != null && address!.line2!.isNotEmpty)
                  Text(address!.line2!),
                Text(
                  [
                    address!.city,
                    if (address!.state != null) address!.state,
                    address!.postalCode,
                  ].whereType<String>().join(', '),
                ),
                Text(address!.country),
                if (address!.phone != null && address!.phone!.isNotEmpty)
                  Text(l10n.orderDetailsPhoneLabel(address!.phone!)),
              ],
            ),
        ],
      ),
    );
  }
}

class _OrderContactCard extends StatelessWidget {
  const _OrderContactCard({required this.contact, required this.l10n});

  final OrderContact contact;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final entries = <Widget>[];
    if (contact.email != null && contact.email!.isNotEmpty) {
      entries.add(
        _ContactRow(
          icon: Icons.email_outlined,
          label: l10n.orderDetailsEmailLabel(contact.email!),
        ),
      );
    }
    if (contact.phone != null && contact.phone!.isNotEmpty) {
      entries.add(
        _ContactRow(
          icon: Icons.phone_outlined,
          label: l10n.orderDetailsPhoneLabel(contact.phone!),
        ),
      );
    }
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppTokens.spaceS),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DesignSnapshotGallery extends StatelessWidget {
  const _DesignSnapshotGallery({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final snapshots = order.lineItems
        .map((item) => item.designSnapshot)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (snapshots.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: snapshots.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.spaceM),
        itemBuilder: (context, index) {
          final snapshot = snapshots[index];
          final emoji = snapshot['emoji'] as String? ?? '印';
          final color =
              _parseColor(snapshot['background']) ??
              Theme.of(context).colorScheme.secondaryContainer;
          final title = snapshot['title'] as String? ?? '';
          return AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DesignPreviewTile(emoji: emoji, color: color),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

int _initialTabIndex(String subPage) {
  if (subPage.isEmpty) {
    return 0;
  }
  final segments = subPage
      .split('/')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return 0;
  }
  final normalized = segments.first.toLowerCase();
  return switch (normalized) {
    'timeline' => 1,
    'files' => 2,
    _ => 0,
  };
}

bool _shouldShowSupportBanner(Order order) {
  return switch (order.status) {
    OrderStatus.pendingPayment ||
    OrderStatus.inProduction ||
    OrderStatus.readyToShip => true,
    _ => false,
  };
}

bool _hasDesignSnapshots(Order order) {
  return order.lineItems.any(
    (item) => item.designSnapshot != null && item.designSnapshot!.isNotEmpty,
  );
}

Color? _parseColor(Object? value) {
  if (value is Color) {
    return value;
  }
  if (value is int) {
    return Color(value);
  }
  if (value is String) {
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      final numeric = int.tryParse(hex, radix: 16);
      if (numeric != null) {
        return Color(0xFF000000 | numeric);
      }
    }
  }
  return null;
}

String _formatCurrency(BuildContext context, num amount, String currency) {
  final locale = Localizations.localeOf(context);
  final isJpy = currency == 'JPY';
  final format = NumberFormat.currency(
    locale: locale.toLanguageTag(),
    symbol: isJpy
        ? '¥'
        : NumberFormat.simpleCurrency(name: currency).currencySymbol,
    decimalDigits: isJpy ? 0 : 2,
  );
  return format.format(amount);
}

String _formatRelativeTimestamp(AppLocalizations l10n, DateTime? timestamp) {
  final target = timestamp ?? DateTime.now();
  final now = DateTime.now();
  final difference = now.difference(target);
  if (difference.inMinutes < 1) {
    return l10n.orderDetailsUpdatedJustNow;
  }
  if (difference.inHours < 1) {
    return l10n.orderDetailsUpdatedMinutes(difference.inMinutes);
  }
  if (difference.inHours < 24) {
    return l10n.orderDetailsUpdatedHours(difference.inHours);
  }
  return l10n.orderDetailsUpdatedOn(DateFormat.yMMMd().format(target));
}

class _StatusColors {
  const _StatusColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_StatusColors _statusColors(OrderStatus status, ColorScheme scheme) {
  switch (status) {
    case OrderStatus.pendingPayment:
      return _StatusColors(
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      );
    case OrderStatus.paid:
      return _StatusColors(
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      );
    case OrderStatus.inProduction:
    case OrderStatus.readyToShip:
      return _StatusColors(
        background: scheme.tertiaryFixedDim,
        foreground: scheme.onTertiaryContainer,
      );
    case OrderStatus.shipped:
    case OrderStatus.delivered:
      return _StatusColors(
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    case OrderStatus.canceled:
    case OrderStatus.draft:
      return _StatusColors(
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
  }
}

String _statusLabel(OrderStatus status, AppLocalizations l10n) {
  return switch (status) {
    OrderStatus.pendingPayment => l10n.orderStatusPendingPayment,
    OrderStatus.paid => l10n.orderStatusPaid,
    OrderStatus.inProduction => l10n.orderStatusInProduction,
    OrderStatus.readyToShip => l10n.orderStatusReadyToShip,
    OrderStatus.shipped => l10n.orderStatusShipped,
    OrderStatus.delivered => l10n.orderStatusDelivered,
    OrderStatus.canceled => l10n.orderStatusCanceled,
    OrderStatus.draft => l10n.orderStatusCanceled,
  };
}

List<Widget> _buildTimelineEntries(Order order, AppLocalizations l10n) {
  final entries = <_TimelineEntry>[
    _TimelineEntry(
      label: l10n.ordersTimelineOrdered,
      timestamp: order.placedAt ?? order.createdAt,
      icon: Icons.note_add_outlined,
    ),
    if (order.paidAt != null)
      _TimelineEntry(
        label: l10n.orderDetailsTimelinePaid,
        timestamp: order.paidAt!,
        icon: Icons.payments_outlined,
      ),
    if (order.shippedAt != null)
      _TimelineEntry(
        label: l10n.ordersTimelineShipping,
        timestamp: order.shippedAt!,
        icon: Icons.local_shipping_outlined,
      ),
    if (order.deliveredAt != null)
      _TimelineEntry(
        label: l10n.ordersTimelineDelivered,
        timestamp: order.deliveredAt!,
        icon: Icons.home_outlined,
      ),
  ];
  if (entries.isEmpty) {
    entries.add(
      _TimelineEntry(
        label: l10n.orderDetailsTimelinePending,
        timestamp: order.createdAt,
        icon: Icons.pending_actions_outlined,
      ),
    );
  }
  return entries.map((entry) => _TimelineBadge(entry: entry)).toList();
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.label,
    required this.timestamp,
    required this.icon,
  });

  final String label;
  final DateTime timestamp;
  final IconData icon;
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_Hm().format(entry.timestamp);
    return AppCard(
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceL,
        vertical: AppTokens.spaceM,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(entry.icon, size: 20),
          const SizedBox(width: AppTokens.spaceS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.label, style: Theme.of(context).textTheme.labelLarge),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
