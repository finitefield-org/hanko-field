// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/view_model/orders_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(ordersViewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(prefersEnglish ? 'Orders' : '注文'),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Search' : '検索',
            icon: const Icon(Icons.search),
            onPressed: () {
              unawaited(
                ref.container
                    .read(navigationControllerProvider)
                    .push(AppRoutePaths.search),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.sm,
              ),
              child: _FilterBar(
                status: state.valueOrNull?.status,
                time: state.valueOrNull?.time ?? OrderTimeFilter.all,
                prefersEnglish: prefersEnglish,
                onStatusSelected: (status) =>
                    ref.invoke(ordersViewModel.setStatus(status)),
                onTimeSelected: (time) =>
                    ref.invoke(ordersViewModel.setTime(time)),
              ),
            ),
            Expanded(
              child: RefreshIndicator.adaptive(
                displacement: tokens.spacing.xl,
                edgeOffset: tokens.spacing.md,
                onRefresh: _refresh,
                child: _buildContent(
                  context: context,
                  state: state,
                  prefersEnglish: prefersEnglish,
                  tokens: tokens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AsyncValue<OrdersState> state,
    required bool prefersEnglish,
    required DesignTokens tokens,
  }) {
    final loading = state is AsyncLoading<OrdersState>;
    final error = state is AsyncError<OrdersState>;
    final data = state.valueOrNull;

    if (loading && data == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: const AppListSkeleton(items: 5, itemHeight: 96),
      );
    }

    if (error && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () => unawaited(_refresh()),
        ),
      );
    }

    final items = data?.items ?? const <Order>[];
    final hasMore = data?.nextPageToken != null;
    final isLoadingMore = data?.isLoadingMore == true;

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: tokens.spacing.xl),
          AppEmptyState(
            title: prefersEnglish ? 'No orders' : '注文はありません',
            message: prefersEnglish
                ? 'Orders will appear here after checkout.'
                : '注文後、ここに履歴が表示されます。',
            icon: Icons.receipt_long_outlined,
            actionLabel: prefersEnglish ? 'Refresh' : '更新する',
            onAction: () => unawaited(_refresh()),
          ),
        ],
      );
    }

    final groups = _groupByDay(items);

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.xs,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      itemCount: groups.length + (hasMore || isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= groups.length) {
          return Padding(
            padding: EdgeInsets.only(top: tokens.spacing.md),
            child: isLoadingMore
                ? const LinearProgressIndicator()
                : Center(
                    child: Text(
                      prefersEnglish ? 'Scroll to load more' : 'スクロールして続きを読み込む',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
          );
        }

        final group = groups[index];
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.md),
          child: _DayGroupCard(
            date: group.date,
            orders: group.orders,
            prefersEnglish: prefersEnglish,
            onTapOrder: _openOrder,
          ),
        );
      },
    );
  }

  Future<void> _refresh() {
    return ref.invoke(ordersViewModel.refresh());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.container.read(ordersViewModel).valueOrNull;
    if (state == null || state.nextPageToken == null || state.isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 260) {
      ref.invoke(ordersViewModel.loadMore());
    }
  }

  void _openOrder(Order order) {
    final id = order.id;
    if (id == null) return;
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push('${AppRoutePaths.orders}/$id'),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.time,
    required this.prefersEnglish,
    required this.onStatusSelected,
    required this.onTimeSelected,
  });

  final OrderStatus? status;
  final OrderTimeFilter time;
  final bool prefersEnglish;
  final ValueChanged<OrderStatus?> onStatusSelected;
  final ValueChanged<OrderTimeFilter> onTimeSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(prefersEnglish ? 'All' : 'すべて'),
                selected: status == null,
                onSelected: (_) => onStatusSelected(null),
              ),
              SizedBox(width: tokens.spacing.sm),
              ...OrderStatus.values.map((s) {
                final selected = status == s;
                return Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.sm),
                  child: FilterChip(
                    label: Text(
                      _statusLabel(s, prefersEnglish: prefersEnglish),
                    ),
                    selected: selected,
                    onSelected: (_) => onStatusSelected(s),
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...OrderTimeFilter.values.map((t) {
                final selected = time == t;
                return Padding(
                  padding: EdgeInsets.only(right: tokens.spacing.sm),
                  child: FilterChip(
                    label: Text(_timeLabel(t, prefersEnglish: prefersEnglish)),
                    selected: selected,
                    onSelected: (_) => onTimeSelected(t),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({
    required this.date,
    required this.orders,
    required this.prefersEnglish,
    required this.onTapOrder,
  });

  final DateTime date;
  final List<Order> orders;
  final bool prefersEnglish;
  final ValueChanged<Order> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.md,
                tokens.spacing.sm,
                tokens.spacing.md,
                tokens.spacing.xs,
              ),
              child: Text(
                _formatDayHeader(date, prefersEnglish: prefersEnglish),
                style: textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            ...orders.map((order) {
              final title = order.orderNumber;
              final lineName = order.lineItems.firstOrNull?.name;
              final amount = _formatJpy(
                order.totals.total,
                currency: order.currency,
              );

              return Column(
                children: [
                  ListTile(
                    leading: _OrderSnapshot(order: order),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (lineName != null && lineName.isNotEmpty)
                              lineName,
                            amount,
                          ].join(' · '),
                        ),
                        Text(
                          _timelineSnippet(
                            order,
                            prefersEnglish: prefersEnglish,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: _StatusPill(
                      status: order.status,
                      prefersEnglish: prefersEnglish,
                    ),
                    onTap: () => onTapOrder(order),
                  ),
                  if (order != orders.last) const Divider(height: 1),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OrderSnapshot extends StatelessWidget {
  const _OrderSnapshot({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final icon = switch (order.status) {
      OrderStatus.delivered => Icons.inventory_2_outlined,
      OrderStatus.shipped => Icons.local_shipping_outlined,
      OrderStatus.inProduction ||
      OrderStatus.readyToShip => Icons.handyman_outlined,
      OrderStatus.canceled => Icons.cancel_outlined,
      _ => Icons.receipt_long_outlined,
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Icon(icon, size: 22),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.prefersEnglish});

  final OrderStatus status;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (:bg, :fg) = _statusColors(status, scheme: scheme, tokens: tokens);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
      ),
      child: Text(
        _statusLabel(status, prefersEnglish: prefersEnglish),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

List<_DayGroup> _groupByDay(List<Order> items) {
  final normalized = items
      .map(
        (o) =>
            (o, DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day)),
      )
      .toList();

  final map = <DateTime, List<Order>>{};
  for (final entry in normalized) {
    map.putIfAbsent(entry.$2, () => <Order>[]).add(entry.$1);
  }

  final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return days
      .map(
        (d) => _DayGroup(
          date: d,
          orders: map[d]!..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
      )
      .toList();
}

class _DayGroup {
  const _DayGroup({required this.date, required this.orders});

  final DateTime date;
  final List<Order> orders;
}

String _statusLabel(OrderStatus status, {required bool prefersEnglish}) {
  return switch (status) {
    OrderStatus.draft => prefersEnglish ? 'Draft' : '下書き',
    OrderStatus.pendingPayment => prefersEnglish ? 'Pending payment' : '支払い待ち',
    OrderStatus.paid => prefersEnglish ? 'Paid' : '支払済み',
    OrderStatus.inProduction => prefersEnglish ? 'In production' : '制作中',
    OrderStatus.readyToShip => prefersEnglish ? 'Ready to ship' : '発送準備',
    OrderStatus.shipped => prefersEnglish ? 'Shipped' : '発送済み',
    OrderStatus.delivered => prefersEnglish ? 'Delivered' : '配達完了',
    OrderStatus.canceled => prefersEnglish ? 'Canceled' : 'キャンセル',
  };
}

String _timeLabel(OrderTimeFilter filter, {required bool prefersEnglish}) {
  return switch (filter) {
    OrderTimeFilter.all => prefersEnglish ? 'All time' : 'すべて',
    OrderTimeFilter.last30Days => prefersEnglish ? 'Last 30 days' : '30日',
    OrderTimeFilter.last90Days => prefersEnglish ? 'Last 90 days' : '90日',
    OrderTimeFilter.last365Days => prefersEnglish ? 'Last year' : '1年',
  };
}

String _timelineSnippet(Order order, {required bool prefersEnglish}) {
  final parts = <String>[];

  if (order.paidAt != null) {
    parts.add(prefersEnglish ? 'Paid' : '支払済');
  } else if (order.status == OrderStatus.pendingPayment) {
    parts.add(prefersEnglish ? 'Awaiting payment' : '支払い待ち');
  }

  if (order.status == OrderStatus.inProduction ||
      order.status == OrderStatus.readyToShip) {
    parts.add(prefersEnglish ? 'Making' : '制作');
  }

  if (order.shippedAt != null || order.status == OrderStatus.shipped) {
    parts.add(prefersEnglish ? 'Shipped' : '発送');
  }

  if (order.deliveredAt != null || order.status == OrderStatus.delivered) {
    parts.add(prefersEnglish ? 'Delivered' : '配達');
  }

  if (order.status == OrderStatus.canceled) {
    parts.add(prefersEnglish ? 'Canceled' : 'キャンセル');
  }

  if (parts.isEmpty) {
    return prefersEnglish ? 'Processing' : '処理中';
  }

  return parts.join(prefersEnglish ? ' · ' : '・');
}

String _formatDayHeader(DateTime date, {required bool prefersEnglish}) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return prefersEnglish ? '$y-$m-$d' : '$y/$m/$d';
}

String _formatJpy(int amount, {required String currency}) {
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
