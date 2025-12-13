// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/view_model/order_detail_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final orderAsync = ref.watch(OrderDetailViewModel(orderId: widget.orderId));
    final order = orderAsync.valueOrNull;

    final title = order?.orderNumber ?? (prefersEnglish ? 'Order' : '注文');

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
                      tooltip: prefersEnglish ? 'Reorder' : '再注文',
                      icon: const Icon(Icons.replay_outlined),
                      onPressed: order == null
                          ? null
                          : () => _openReorderFlow(),
                    ),
                    IconButton(
                      tooltip: prefersEnglish ? 'Share' : '共有',
                      icon: const Icon(Icons.ios_share_outlined),
                      onPressed: order == null
                          ? null
                          : () => _share(order, prefersEnglish),
                    ),
                    PopupMenuButton<_OrderMenuAction>(
                      tooltip: prefersEnglish ? 'More' : 'その他',
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                            value: _OrderMenuAction.contactSupport,
                            child: Text(
                              prefersEnglish ? 'Contact support' : '問い合わせ',
                            ),
                          ),
                          if (order != null &&
                              order.status != OrderStatus.canceled)
                            PopupMenuItem(
                              value: _OrderMenuAction.cancel,
                              child: Text(
                                prefersEnglish ? 'Cancel order' : '注文をキャンセル',
                              ),
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
                            unawaited(_confirmCancel(current, prefersEnglish));
                        }
                      },
                    ),
                  ],
                  bottom: TabBar(
                    tabs: [
                      Tab(text: prefersEnglish ? 'Summary' : '概要'),
                      Tab(text: prefersEnglish ? 'Timeline' : '履歴'),
                      Tab(text: prefersEnglish ? 'Files' : 'ファイル'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _TabScaffold(
                  tokens: tokens,
                  prefersEnglish: prefersEnglish,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _SummaryTab(
                          order: order,
                          prefersEnglish: prefersEnglish,
                          onTapDesign: _showDesignPreview,
                          onOpenProduction: () => _pushSubRoute('production'),
                          onOpenTracking: () => _pushSubRoute('tracking'),
                          onRequestInvoice: () =>
                              unawaited(_requestInvoice(prefersEnglish)),
                          onContactSupport: _contactSupport,
                        ),
                ),
                _TabScaffold(
                  tokens: tokens,
                  prefersEnglish: prefersEnglish,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _TimelineTab(
                          order: order,
                          prefersEnglish: prefersEnglish,
                        ),
                ),
                _TabScaffold(
                  tokens: tokens,
                  prefersEnglish: prefersEnglish,
                  state: orderAsync,
                  onRetry: _refresh,
                  child: order == null
                      ? null
                      : _FilesTab(
                          order: order,
                          prefersEnglish: prefersEnglish,
                          onTapDesign: _showDesignPreview,
                          onRequestInvoice: () =>
                              unawaited(_requestInvoice(prefersEnglish)),
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

  void _share(Order order, bool prefersEnglish) {
    final text = prefersEnglish
        ? 'Order ${order.orderNumber}'
        : '注文番号：${order.orderNumber}';
    Share.share(text, subject: order.orderNumber);
  }

  void _openReorderFlow() {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push<Object?>('${AppRoutePaths.orders}/${widget.orderId}/reorder'),
    );
  }

  Future<void> _requestInvoice(bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.invoke(
        OrderDetailViewModel(orderId: widget.orderId).requestInvoice(),
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish
                ? 'Invoice request sent (mock)'
                : '領収書のリクエストを送信しました（モック）',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish ? 'Could not request invoice' : '領収書のリクエストに失敗しました',
          ),
        ),
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

  Future<void> _confirmCancel(Order order, bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppModal<bool>(
      context: context,
      title: prefersEnglish ? 'Cancel this order?' : 'この注文をキャンセルしますか？',
      body: Text(
        prefersEnglish
            ? 'If production already started, cancellation may not be possible.'
            : '制作が開始している場合、キャンセルできないことがあります。',
      ),
      primaryAction: prefersEnglish ? 'Cancel order' : 'キャンセルする',
      secondaryAction: prefersEnglish ? 'Keep' : '戻る',
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true) return;

    try {
      await ref.invoke(OrderDetailViewModel(orderId: widget.orderId).cancel());
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Order canceled' : '注文をキャンセルしました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Could not cancel' : 'キャンセルに失敗しました'),
        ),
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
                    label: 'OK',
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
    required this.prefersEnglish,
    required this.state,
    required this.onRetry,
    required this.child,
  });

  final DesignTokens tokens;
  final bool prefersEnglish;
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
                  title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
                  message: error.toString(),
                  icon: Icons.error_outline,
                  actionLabel: prefersEnglish ? 'Retry' : '再試行',
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
    required this.prefersEnglish,
    required this.onTapDesign,
    required this.onOpenProduction,
    required this.onOpenTracking,
    required this.onRequestInvoice,
    required this.onContactSupport,
  });

  final Order order;
  final bool prefersEnglish;
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
              content: Text(
                prefersEnglish
                    ? 'Your order is in progress. You can check production and tracking here.'
                    : '注文は進行中です。制作状況や配送状況を確認できます。',
              ),
              actions: [
                ActionChip(
                  label: Text(prefersEnglish ? 'Production' : '制作'),
                  onPressed: onOpenProduction,
                ),
                ActionChip(
                  label: Text(prefersEnglish ? 'Tracking' : '配送'),
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
                      prefersEnglish ? 'Order' : '注文',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      order.orderNumber,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      _orderMeta(order, prefersEnglish: prefersEnglish),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                status: order.status,
                prefersEnglish: prefersEnglish,
                scheme: scheme,
                tokens: tokens,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: prefersEnglish ? 'Items' : '明細',
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
                            prefersEnglish
                                ? 'Qty ${item.quantity}'
                                : '数量 ${item.quantity}',
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
          title: prefersEnglish ? 'Total' : '合計',
          child: Column(
            children: [
              _TotalRow(
                label: prefersEnglish ? 'Subtotal' : '小計',
                value: _formatCurrency(
                  order.totals.subtotal,
                  currency: order.currency,
                ),
              ),
              if (order.totals.discount != 0)
                _TotalRow(
                  label: prefersEnglish ? 'Discount' : '割引',
                  value:
                      '-${_formatCurrency(order.totals.discount, currency: order.currency)}',
                ),
              _TotalRow(
                label: prefersEnglish ? 'Shipping' : '送料',
                value: order.totals.shipping == 0
                    ? (prefersEnglish ? 'Free' : '無料')
                    : _formatCurrency(
                        order.totals.shipping,
                        currency: order.currency,
                      ),
              ),
              _TotalRow(
                label: prefersEnglish ? 'Tax' : '税',
                value: _formatCurrency(
                  order.totals.tax,
                  currency: order.currency,
                ),
              ),
              Divider(height: tokens.spacing.lg),
              _TotalRow(
                label: prefersEnglish ? 'Total' : '合計',
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
          title: prefersEnglish ? 'Shipping address' : '配送先',
          child: _AddressBlock(address: order.shippingAddress),
        ),
        if (order.billingAddress != null) ...[
          SizedBox(height: tokens.spacing.md),
          _SectionCard(
            title: prefersEnglish ? 'Billing address' : '請求先',
            child: _AddressBlock(address: order.billingAddress!),
          ),
        ],
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: prefersEnglish ? 'Payment' : '支払い',
          child: _PaymentSummary(order: order, prefersEnglish: prefersEnglish),
        ),
        SizedBox(height: tokens.spacing.md),
        _ElevatedSectionCard(
          title: prefersEnglish ? 'Design snapshots' : 'デザインスナップショット',
          child: _DesignGallery(
            snapshots: _collectSnapshots(order),
            onTap: onTapDesign,
            tokens: tokens,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: prefersEnglish ? 'Quick actions' : '操作',
          child: Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: [
              ActionChip(
                label: Text(prefersEnglish ? 'Request invoice' : '領収書を依頼'),
                onPressed: onRequestInvoice,
              ),
              ActionChip(
                label: Text(prefersEnglish ? 'Contact support' : '問い合わせ'),
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
  const _TimelineTab({required this.order, required this.prefersEnglish});

  final Order order;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final milestones = _milestones(order, prefersEnglish: prefersEnglish);

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
                prefersEnglish ? 'Timeline' : '履歴',
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
                              m.timeLabel ?? (prefersEnglish ? '—' : '—'),
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
                  prefersEnglish ? 'Production events' : '制作イベント',
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
    required this.prefersEnglish,
    required this.onTapDesign,
    required this.onRequestInvoice,
    required this.onOpenInvoice,
  });

  final Order order;
  final bool prefersEnglish;
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
          title: prefersEnglish ? 'Design snapshots' : 'デザインスナップショット',
          child: _DesignGallery(
            snapshots: _collectSnapshots(order),
            onTap: onTapDesign,
            tokens: tokens,
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        _SectionCard(
          title: prefersEnglish ? 'Invoice' : '領収書',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prefersEnglish
                    ? 'You can request and view invoices here.'
                    : '領収書の依頼・表示ができます。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: tokens.spacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: prefersEnglish ? 'Request' : '依頼する',
                      variant: AppButtonVariant.secondary,
                      leading: const Icon(Icons.receipt_long_outlined),
                      expand: true,
                      onPressed: onRequestInvoice,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: AppButton(
                      label: prefersEnglish ? 'View' : '表示する',
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
    required this.prefersEnglish,
    required this.scheme,
    required this.tokens,
  });

  final OrderStatus status;
  final bool prefersEnglish;
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
        _statusLabel(status, prefersEnglish: prefersEnglish),
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
  const _PaymentSummary({required this.order, required this.prefersEnglish});

  final Order order;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final payment = order.payments.isNotEmpty ? order.payments.first : null;
    final paidAt = order.paidAt;
    final status = order.status;

    final headline = switch (status) {
      OrderStatus.pendingPayment => prefersEnglish ? 'Pending' : '未払い',
      OrderStatus.paid ||
      OrderStatus.inProduction ||
      OrderStatus.readyToShip => prefersEnglish ? 'Paid' : '支払い済み',
      OrderStatus.shipped ||
      OrderStatus.delivered => prefersEnglish ? 'Paid' : '支払い済み',
      OrderStatus.canceled => prefersEnglish ? 'Canceled' : 'キャンセル',
      _ => prefersEnglish ? 'Processing' : '処理中',
    };

    final detail = payment == null
        ? (paidAt == null
              ? (prefersEnglish ? 'No payment information' : '支払い情報はありません')
              : (prefersEnglish
                    ? 'Paid at ${_formatDateTime(paidAt)}'
                    : '${_formatDateTime(paidAt)} に支払い'))
        : _paymentDetail(payment, prefersEnglish: prefersEnglish);

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

String _paymentDetail(OrderPayment payment, {required bool prefersEnglish}) {
  final method = payment.method;
  final base = prefersEnglish
      ? '${payment.provider.toJson()} · ${payment.status.toJson()}'
      : '${payment.provider.toJson()}・${payment.status.toJson()}';
  if (method == null) return base;

  final methodLabel = switch (method.type) {
    PaymentMethodType.card => prefersEnglish ? 'Card' : 'カード',
    PaymentMethodType.wallet => prefersEnglish ? 'Wallet' : 'ウォレット',
    PaymentMethodType.bank => prefersEnglish ? 'Bank' : '銀行',
    PaymentMethodType.other => prefersEnglish ? 'Other' : 'その他',
  };

  final suffix = [
    method.brand,
    if (method.last4 != null) '•••• ${method.last4}',
    if (method.expMonth != null && method.expYear != null)
      '${method.expMonth}/${method.expYear}',
  ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');

  return suffix.isEmpty
      ? '$base · $methodLabel'
      : '$base · $methodLabel $suffix';
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
      return Text('—', style: Theme.of(context).textTheme.bodySmall);
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

String _orderMeta(Order order, {required bool prefersEnglish}) {
  final id = order.id;
  final created = _formatDateTime(order.createdAt);
  if (id == null) return created;
  return prefersEnglish ? 'ID $id · $created' : 'ID $id・$created';
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

String _statusLabel(OrderStatus status, {required bool prefersEnglish}) {
  return switch (status) {
    OrderStatus.pendingPayment => prefersEnglish ? 'Pending' : '未払い',
    OrderStatus.paid => prefersEnglish ? 'Paid' : '支払い済み',
    OrderStatus.inProduction => prefersEnglish ? 'In production' : '制作中',
    OrderStatus.readyToShip => prefersEnglish ? 'Ready to ship' : '発送準備中',
    OrderStatus.shipped => prefersEnglish ? 'Shipped' : '発送済み',
    OrderStatus.delivered => prefersEnglish ? 'Delivered' : '配達済み',
    OrderStatus.canceled => prefersEnglish ? 'Canceled' : 'キャンセル',
    _ => prefersEnglish ? 'Processing' : '処理中',
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
  required bool prefersEnglish,
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
      prefersEnglish ? 'Placed' : '注文',
      order.placedAt ?? order.createdAt,
    ),
    _milestone(
      Icons.credit_card_outlined,
      prefersEnglish ? 'Paid' : '支払い',
      order.paidAt,
    ),
    _milestone(
      Icons.handyman_outlined,
      prefersEnglish ? 'Production' : '制作',
      productionAt,
    ),
    _milestone(
      Icons.local_shipping_outlined,
      prefersEnglish ? 'Shipped' : '発送',
      order.shippedAt,
    ),
    _milestone(
      Icons.inventory_2_outlined,
      prefersEnglish ? 'Delivered' : '配達',
      order.deliveredAt,
    ),
    if (order.canceledAt != null)
      _milestone(
        Icons.cancel_outlined,
        prefersEnglish ? 'Canceled' : 'キャンセル',
        order.canceledAt,
      ),
  ];
}
