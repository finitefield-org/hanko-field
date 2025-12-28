// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/view_model/order_detail_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(OrderDetailViewModel(orderId: widget.orderId));
    final order = orderAsync.valueOrNull;

    final title = order?.orderNumber ?? l10n.orderDetailTitleFallback;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar.medium(
                  pinned: true,
                  backgroundColor: tokens.colors.surface,
                  title: Text(title),
                  actions: [
                    IconButton(
                      tooltip: l10n.orderDetailTooltipReorder,
                      icon: const Icon(Icons.replay_outlined),
                      onPressed: order == null
                          ? null
                          : () => _openReorderFlow(),
                    ),
                    IconButton(
                      tooltip: l10n.orderDetailTooltipShare,
                      icon: const Icon(Icons.ios_share_outlined),
                      onPressed: order == null
                          ? null
                          : () => _share(order, l10n),
                    ),
                    PopupMenuButton<_OrderMenuAction>(
                      tooltip: l10n.orderDetailTooltipMore,
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                            value: _OrderMenuAction.contactSupport,
                            child: Text(l10n.orderDetailMenuContactSupport),
                          ),
                          if (order != null &&
                              order.status != OrderStatus.canceled)
                            PopupMenuItem(
                              value: _OrderMenuAction.cancel,
                              child: Text(l10n.orderDetailMenuCancelOrder),
                            ),
                        ];
                      },
                      onSelected: (action) {
                        final current = order;
                        if (current == null) return;
                        switch (action) {
                          case _OrderMenuAction.contactSupport:
                            _contactSupport();
                          case _OrderMenuAction.cancel:
                            unawaited(_confirmCancel(current, l10n));
                        }
                      },
                    ),
                  ],
                  bottom: TabBar(
                    tabs: [
                      Tab(text: l10n.orderDetailTabSummary),
                      Tab(text: l10n.orderDetailTabTimeline),
                      Tab(text: l10n.orderDetailTabFiles),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _TabScaffold(
                  tokens: tokens,
                  l10n: l10n,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _SummaryTab(
                          order: order,
                          l10n: l10n,
                          onTapDesign: _showDesignPreview,
                          onOpenProduction: () => _pushSubRoute('production'),
                          onOpenTracking: () => _pushSubRoute('tracking'),
                          onRequestInvoice: () =>
                              unawaited(_requestInvoice(l10n)),
                          onContactSupport: _contactSupport,
                        ),
                ),
                _TabScaffold(
                  tokens: tokens,
                  l10n: l10n,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _TimelineTab(order: order, l10n: l10n),
                ),
                _TabScaffold(
                  tokens: tokens,
                  l10n: l10n,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _FilesTab(
                          order: order,
                          l10n: l10n,
                          onTapDesign: _showDesignPreview,
                          onRequestInvoice: () =>
                              unawaited(_requestInvoice(l10n)),
                          onOpenInvoice: () => _pushSubRoute('invoice'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.refreshValue(
      OrderDetailViewModel(orderId: widget.orderId),
      keepPrevious: true,
    );
  }

  void _share(Order order, AppLocalizations l10n) {
    final text = l10n.orderDetailShareText(order.orderNumber);
    Share.share(text, subject: order.orderNumber);
  }

  void _openReorderFlow() {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push<Object?>('${AppRoutePaths.orders}/${widget.orderId}/reorder'),
    );
  }

  Future<void> _requestInvoice(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.invoke(
        OrderDetailViewModel(orderId: widget.orderId).requestInvoice(),
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderDetailInvoiceRequestSent)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderDetailInvoiceRequestFailed)),
      );
    }
  }

  void _pushSubRoute(String subPath) {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push<Object?>('${AppRoutePaths.orders}/${widget.orderId}/$subPath'),
    );
  }

  void _contactSupport() {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push<Object?>(AppRoutePaths.supportContact),
    );
  }

  Future<void> _confirmCancel(Order order, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppModal<bool>(
      context: context,
      title: l10n.orderDetailCancelTitle,
      body: Text(l10n.orderDetailCancelBody),
      primaryAction: l10n.orderDetailCancelConfirm,
      secondaryAction: l10n.orderDetailCancelKeep,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true) return;

    try {
      await ref.invoke(OrderDetailViewModel(orderId: widget.orderId).cancel());
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderDetailCancelSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderDetailCancelFailed)),
      );
    }
  }

  Future<void> _showDesignPreview(_DesignSnapshot snapshot) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final tokens = DesignTokensTheme.of(ctx);
        return Dialog(
          insetPadding: EdgeInsets.all(tokens.spacing.lg),
          backgroundColor: tokens.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radii.lg),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.label,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.md),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radii.md),
                    child: snapshot.imageUrl == null
                        ? ColoredBox(
                            color: tokens.colors.surfaceVariant,
                            child: const Center(
                              child: Icon(Icons.image_outlined, size: 44),
                            ),
                          )
                        : Image.network(
                            snapshot.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: tokens.colors.surfaceVariant,
                              child: const Center(
                                child: Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: tokens.spacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    label: AppLocalizations.of(
                      context,
                    ).orderDetailDesignPreviewOk,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _OrderMenuAction { contactSupport, cancel }

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({
    required this.tokens,
    required this.l10n,
    required this.state,
    required this.onRetry,
    required this.child,
  });

  final DesignTokens tokens;
  final AppLocalizations l10n;
  final AsyncValue<Order> state;
  final Future<void> Function() onRetry;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final data = state.valueOrNull;
    return RefreshIndicator.adaptive(
      edgeOffset: tokens.spacing.md,
      displacement: tokens.spacing.xl,
      onRefresh: onRetry,
      child: Builder(
        builder: (context) {
          if (state is AsyncLoading<Order> && data == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.all(tokens.spacing.lg),
              children: const [AppListSkeleton(items: 5, itemHeight: 120)],
            );
          }

          if (state is AsyncError<Order> && data == null) {
            final error = (state as AsyncError<Order>).error;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.all(tokens.spacing.xl),
              children: [
                AppEmptyState(
                  title: l10n.commonLoadFailed,
                  message: error.toString(),
                  icon: Icons.error_outline,
                  actionLabel: l10n.commonRetry,
                  onAction: () => unawaited(onRetry()),
                ),
              ],
            );
          }

          return child ??
              ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.all(tokens.spacing.lg),
                children: const [AppListSkeleton(items: 5, itemHeight: 120)],
              );
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.order,
    required this.l10n,
    required this.onTapDesign,
    required this.onOpenProduction,
    required this.onOpenTracking,
    required this.onRequestInvoice,
    required this.onContactSupport,
  });

  final Order order;
  final AppLocalizations l10n;
  final ValueChanged<_DesignSnapshot> onTapDesign;
  final VoidCallback onOpenProduction;
  final VoidCallback onOpenTracking;
  final VoidCallback onRequestInvoice;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        if (order.status != OrderStatus.delivered &&
            order.status != OrderStatus.canceled)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.md),
            child: MaterialBanner(
              leading: const Icon(Icons.info_outline),
              content: Text(l10n.orderDetailBannerInProgress),
              actions: [
                ActionChip(
                  label: Text(l10n.orderDetailBannerProduction),
                  onPressed: onOpenProduction,
                ),
                ActionChip(
                  label: Text(l10n.orderDetailBannerTracking),
                  onPressed: onOpenTracking,
                ),
              ],
            ),
          ),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.orderDetailSectionOrder,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      _orderMeta(order, l10n: l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                status: order.status,
                l10n: l10n,
                scheme: scheme,
                tokens: tokens,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailSectionItems,
          child: Column(
            children: order.lineItems.map((item) {
              final name = item.name ?? item.sku;
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SizedBox(height: tokens.spacing.xs),
                          Text(
                            l10n.orderDetailItemQtyLabel(item.quantity),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.colors.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(item.total, currency: order.currency),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailSectionTotal,
          child: Column(
            children: [
              _TotalRow(
                label: l10n.orderDetailSubtotal,
                value: _formatCurrency(
                  order.totals.subtotal,
                  currency: order.currency,
                ),
              ),
              if (order.totals.discount != 0)
                _TotalRow(
                  label: l10n.orderDetailDiscount,
                  value:
                      '-${_formatCurrency(order.totals.discount, currency: order.currency)}',
                ),
              _TotalRow(
                label: l10n.orderDetailShipping,
                value: order.totals.shipping == 0
                    ? l10n.orderDetailShippingFree
                    : _formatCurrency(
                        order.totals.shipping,
                        currency: order.currency,
                      ),
              ),
              _TotalRow(
                label: l10n.orderDetailTax,
                value: _formatCurrency(
                  order.totals.tax,
                  currency: order.currency,
                ),
              ),
              Divider(height: tokens.spacing.lg),
              _TotalRow(
                label: l10n.orderDetailTotal,
                value: _formatCurrency(
                  order.totals.total,
                  currency: order.currency,
                ),
                emphasize: true,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailShippingAddress,
          child: _AddressBlock(address: order.shippingAddress),
        ),
        if (order.billingAddress != null) ...[
          SizedBox(height: tokens.spacing.md),
          _SectionCard(
            title: l10n.orderDetailBillingAddress,
            child: _AddressBlock(address: order.billingAddress!),
          ),
        ],
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailPayment,
          child: _PaymentSummary(order: order, l10n: l10n),
        ),
        SizedBox(height: tokens.spacing.md),
        _ElevatedSectionCard(
          title: l10n.orderDetailDesignSnapshots,
          child: _DesignGallery(
            snapshots: _collectSnapshots(order),
            onTap: onTapDesign,
            tokens: tokens,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailQuickActions,
          child: Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: [
              ActionChip(
                label: Text(l10n.orderDetailRequestInvoice),
                onPressed: onRequestInvoice,
              ),
              ActionChip(
                label: Text(l10n.orderDetailContactSupport),
                onPressed: onContactSupport,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final milestones = _milestones(order, l10n: l10n);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.orderDetailTimelineTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: tokens.spacing.md),
              ...milestones.map((m) {
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(m.icon, size: 20),
                      SizedBox(width: tokens.spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            SizedBox(height: tokens.spacing.xs),
                            Text(
                              m.timeLabel ?? l10n.commonPlaceholder,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (order.productionEvents.isNotEmpty) ...[
                Divider(height: tokens.spacing.lg),
                Text(
                  l10n.orderDetailProductionEvents,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: tokens.spacing.md),
                ...order.productionEvents.map((e) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: tokens.spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.type.toJson(),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              SizedBox(height: tokens.spacing.xs),
                              Text(
                                _formatDateTime(e.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (e.note != null &&
                                  e.note!.trim().isNotEmpty) ...[
                                SizedBox(height: tokens.spacing.xs),
                                Text(
                                  e.note!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.order,
    required this.l10n,
    required this.onTapDesign,
    required this.onRequestInvoice,
    required this.onOpenInvoice,
  });

  final Order order;
  final AppLocalizations l10n;
  final ValueChanged<_DesignSnapshot> onTapDesign;
  final VoidCallback onRequestInvoice;
  final VoidCallback onOpenInvoice;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        _ElevatedSectionCard(
          title: l10n.orderDetailDesignSnapshots,
          child: _DesignGallery(
            snapshots: _collectSnapshots(order),
            onTap: onTapDesign,
            tokens: tokens,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: l10n.orderDetailInvoiceTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.orderDetailInvoiceHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: tokens.spacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.orderDetailInvoiceRequest,
                      variant: AppButtonVariant.secondary,
                      leading: const Icon(Icons.receipt_long_outlined),
                      expand: true,
                      onPressed: onRequestInvoice,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: AppButton(
                      label: l10n.orderDetailInvoiceView,
                      variant: AppButtonVariant.ghost,
                      expand: true,
                      onPressed: onOpenInvoice,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}

class _ElevatedSectionCard extends StatelessWidget {
  const _ElevatedSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: tokens.spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.l10n,
    required this.scheme,
    required this.tokens,
  });

  final OrderStatus status;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status, scheme: scheme, tokens: tokens);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Text(
        _statusLabel(status, l10n: l10n),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({required this.address});

  final OrderAddress address;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final lines = <String>[
      address.recipient,
      address.line1,
      if (address.line2 != null && address.line2!.trim().isNotEmpty)
        address.line2!,
      [
        address.city,
        if (address.state != null && address.state!.trim().isNotEmpty)
          address.state!,
        address.postalCode,
        address.country,
      ].where((e) => e.trim().isNotEmpty).join(' '),
      if (address.phone != null && address.phone!.trim().isNotEmpty)
        address.phone!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines.map(
          (line) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.xs),
            child: Text(line),
          ),
        ),
      ],
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final payment = order.payments.isNotEmpty ? order.payments.first : null;
    final paidAt = order.paidAt;
    final status = order.status;

    final headline = switch (status) {
      OrderStatus.pendingPayment => l10n.orderDetailPaymentPending,
      OrderStatus.paid ||
      OrderStatus.inProduction ||
      OrderStatus.readyToShip => l10n.orderDetailPaymentPaid,
      OrderStatus.shipped ||
      OrderStatus.delivered => l10n.orderDetailPaymentPaid,
      OrderStatus.canceled => l10n.orderDetailPaymentCanceled,
      _ => l10n.orderDetailPaymentProcessing,
    };

    final detail = payment == null
        ? (paidAt == null
              ? l10n.orderDetailPaymentNoInfo
              : l10n.orderDetailPaymentPaidAt(_formatDateTime(paidAt)))
        : _paymentDetail(payment, l10n: l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: tokens.spacing.xs),
        Text(
          detail,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: tokens.colors.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

String _paymentDetail(OrderPayment payment, {required AppLocalizations l10n}) {
  final method = payment.method;
  final separator = l10n.orderDetailPaymentSeparator;
  final base =
      '${payment.provider.toJson()}$separator${payment.status.toJson()}';
  if (method == null) return base;

  final methodLabel = switch (method.type) {
    PaymentMethodType.card => l10n.orderDetailPaymentMethodCard,
    PaymentMethodType.wallet => l10n.orderDetailPaymentMethodWallet,
    PaymentMethodType.bank => l10n.orderDetailPaymentMethodBank,
    PaymentMethodType.other => l10n.orderDetailPaymentMethodOther,
  };

  final suffix = [
    method.brand,
    if (method.last4 != null) '•••• ${method.last4}',
    if (method.expMonth != null && method.expYear != null)
      '${method.expMonth}/${method.expYear}',
  ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');

  final joiner = l10n.orderDetailPaymentSeparator;
  return suffix.isEmpty
      ? '$base$joiner$methodLabel'
      : '$base$joiner$methodLabel $suffix';
}

class _DesignGallery extends StatelessWidget {
  const _DesignGallery({
    required this.snapshots,
    required this.onTap,
    required this.tokens,
  });

  final List<_DesignSnapshot> snapshots;
  final ValueChanged<_DesignSnapshot> onTap;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Text(
        l10n.commonPlaceholder,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: tokens.spacing.sm,
      runSpacing: tokens.spacing.sm,
      children: snapshots.map((snapshot) {
        return SizedBox(
          width: 112,
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.sm),
            onTap: () => onTap(snapshot),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radii.sm),
                    child: snapshot.imageUrl == null
                        ? ColoredBox(
                            color: tokens.colors.surfaceVariant,
                            child: const Center(
                              child: Icon(Icons.image_outlined),
                            ),
                          )
                        : Image.network(
                            snapshot.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: tokens.colors.surfaceVariant,
                              child: const Center(
                                child: Icon(Icons.image_not_supported_outlined),
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  snapshot.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DesignSnapshot {
  const _DesignSnapshot({required this.label, this.imageUrl});
  final String label;
  final String? imageUrl;
}

List<_DesignSnapshot> _collectSnapshots(Order order) {
  final snapshots = <_DesignSnapshot>[];

  for (final item in order.lineItems) {
    final map = item.designSnapshot;
    final label =
        _stringFromMap(map, const ['label', 'name']) ?? item.name ?? item.sku;
    final url =
        _stringFromMap(map, const [
          'thumbnailUrl',
          'imageUrl',
          'previewUrl',
          'url',
        ]) ??
        _firstStringFromList(map?['images']);

    snapshots.add(_DesignSnapshot(label: label, imageUrl: url));
  }

  return snapshots;
}

String? _firstStringFromList(Object? value) {
  if (value is! List) return null;
  for (final entry in value) {
    if (entry is String && entry.trim().isNotEmpty) return entry.trim();
  }
  return null;
}

String? _stringFromMap(Map<String, Object?>? map, List<String> keys) {
  if (map == null) return null;
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _orderMeta(Order order, {required AppLocalizations l10n}) {
  final id = order.id;
  final created = _formatDateTime(order.createdAt);
  if (id == null) return created;
  return l10n.orderDetailMeta(id, created);
}

String _formatDateTime(DateTime dateTime) {
  final y = dateTime.year.toString().padLeft(4, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String _formatCurrency(int amount, {required String currency}) {
  final prefix = currency.toUpperCase() == 'JPY'
      ? '¥'
      : '${currency.toUpperCase()} ';
  final digits = amount.toString();
  final sb = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final reverseIndex = digits.length - i;
    sb.write(digits[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) sb.write(',');
  }
  return '$prefix$sb';
}

String _statusLabel(OrderStatus status, {required AppLocalizations l10n}) {
  return switch (status) {
    OrderStatus.pendingPayment => l10n.orderDetailStatusPending,
    OrderStatus.paid => l10n.orderDetailStatusPaid,
    OrderStatus.inProduction => l10n.orderDetailStatusInProduction,
    OrderStatus.readyToShip => l10n.orderDetailStatusReadyToShip,
    OrderStatus.shipped => l10n.orderDetailStatusShipped,
    OrderStatus.delivered => l10n.orderDetailStatusDelivered,
    OrderStatus.canceled => l10n.orderDetailStatusCanceled,
    _ => l10n.orderDetailStatusProcessing,
  };
}

({Color bg, Color fg}) _statusColors(
  OrderStatus status, {
  required ColorScheme scheme,
  required DesignTokens tokens,
}) {
  return switch (status) {
    OrderStatus.pendingPayment => (
      bg: scheme.secondaryContainer,
      fg: scheme.onSecondaryContainer,
    ),
    OrderStatus.paid => (
      bg: scheme.primaryContainer,
      fg: scheme.onPrimaryContainer,
    ),
    OrderStatus.inProduction || OrderStatus.readyToShip => (
      bg: scheme.tertiaryContainer,
      fg: scheme.onTertiaryContainer,
    ),
    OrderStatus.shipped || OrderStatus.delivered => (
      bg: scheme.surfaceContainerHighest,
      fg: scheme.onSurfaceVariant,
    ),
    OrderStatus.canceled => (
      bg: scheme.errorContainer,
      fg: scheme.onErrorContainer,
    ),
    _ => (bg: tokens.colors.surfaceVariant, fg: tokens.colors.onSurface),
  };
}

({IconData icon, String label, String? timeLabel}) _milestone(
  IconData icon,
  String label,
  DateTime? when,
) {
  return (
    icon: icon,
    label: label,
    timeLabel: when == null ? null : _formatDateTime(when),
  );
}

List<({IconData icon, String label, String? timeLabel})> _milestones(
  Order order, {
  required AppLocalizations l10n,
}) {
  DateTime? productionAt;
  for (final event in order.productionEvents) {
    final createdAt = event.createdAt;
    if (productionAt == null || createdAt.isBefore(productionAt)) {
      productionAt = createdAt;
    }
  }

  return [
    _milestone(
      Icons.receipt_long_outlined,
      l10n.orderDetailMilestonePlaced,
      order.placedAt ?? order.createdAt,
    ),
    _milestone(
      Icons.credit_card_outlined,
      l10n.orderDetailMilestonePaid,
      order.paidAt,
    ),
    _milestone(
      Icons.handyman_outlined,
      l10n.orderDetailMilestoneProduction,
      productionAt,
    ),
    _milestone(
      Icons.local_shipping_outlined,
      l10n.orderDetailMilestoneShipped,
      order.shippedAt,
    ),
    _milestone(
      Icons.inventory_2_outlined,
      l10n.orderDetailMilestoneDelivered,
      order.deliveredAt,
    ),
    if (order.canceledAt != null)
      _milestone(
        Icons.cancel_outlined,
        l10n.orderDetailMilestoneCanceled,
        order.canceledAt,
      ),
  ];
}
