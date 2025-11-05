import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/orders/application/orders_list_controller.dart';
import 'package:app/features/orders/domain/order_list_filter.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  OrdersListController get _controller =>
      ref.read(ordersListControllerProvider.notifier);

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final metrics = _scrollController.position;
    if (metrics.extentAfter < 320) {
      _controller.loadMore();
    }
  }

  Future<void> _refresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message = AppLocalizations.of(context).ordersListRefreshError;
      _showSnackBar(message);
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openOrder(String orderNumber) {
    ref
        .read(appStateProvider.notifier)
        .push(OrderDetailsRoute(orderId: orderNumber));
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(ordersListControllerProvider);
    final filter = ref.watch(ordersFilterProvider);
    late final Widget body;
    body = asyncState.when(
      data: (state) {
        return _OrdersListBody(
          state: state,
          filter: filter,
          scrollController: _scrollController,
          onStatusSelected: _controller.changeStatus,
          onTimeSelected: _controller.changeTimeRange,
          onOrderTap: (order) => _openOrder(order.orderNumber),
        );
      },
      loading: () => _OrdersListLoading(controller: _scrollController),
      error: (error, stackTrace) => _OrdersListError(
        controller: _scrollController,
        onRetry: _controller.refresh,
      ),
    );

    return RefreshIndicator(onRefresh: _refresh, displacement: 72, child: body);
  }
}

class _OrdersListBody extends StatelessWidget {
  const _OrdersListBody({
    required this.state,
    required this.filter,
    required this.scrollController,
    required this.onStatusSelected,
    required this.onTimeSelected,
    required this.onOrderTap,
  });

  final OrdersListState state;
  final OrderListFilter filter;
  final ScrollController scrollController;
  final void Function(OrderStatusGroup group) onStatusSelected;
  final void Function(OrderTimeRange range) onTimeSelected;
  final void Function(Order order) onOrderTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = _groupOrders(state.orders);
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            child: _OrdersFilterSection(
              filter: filter,
              lastUpdated: state.lastUpdated,
              onStatusSelected: onStatusSelected,
              onTimeSelected: onTimeSelected,
            ),
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: AppEmptyState(
                title: l10n.ordersListEmptyTitle,
                message: l10n.ordersListEmptyMessage,
                icon: const Icon(Icons.receipt_long_outlined),
              ),
            ),
          )
        else ...[
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceL,
                  AppTokens.spaceS,
                ),
                child: Text(
                  _formatDate(context, group.date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
              sliver: SliverList.separated(
                itemCount: group.orders.length,
                itemBuilder: (context, index) {
                  final order = group.orders[index];
                  return _OrderCard(
                    order: order,
                    onTap: () => onOrderTap(order),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppTokens.spaceM),
              ),
            ),
          ],
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceXL,
            ),
            child: state.isLoadingMore
                ? const LinearProgressIndicator()
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  List<_OrdersDayGroup> _groupOrders(List<Order> orders) {
    if (orders.isEmpty) {
      return const <_OrdersDayGroup>[];
    }
    final buckets = <DateTime, List<Order>>{};
    for (final order in orders) {
      final key = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      buckets.putIfAbsent(key, () => <Order>[]).add(order);
    }
    final sortedKeys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in sortedKeys)
        _OrdersDayGroup(date: key, orders: buckets[key]!),
    ];
  }

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.yMMMMd(locale);
    return formatter.format(date);
  }
}

class _OrdersDayGroup {
  _OrdersDayGroup({required this.date, required this.orders});

  final DateTime date;
  final List<Order> orders;
}

class _OrdersFilterSection extends StatelessWidget {
  const _OrdersFilterSection({
    required this.filter,
    required this.onStatusSelected,
    required this.onTimeSelected,
    this.lastUpdated,
  });

  final OrderListFilter filter;
  final void Function(OrderStatusGroup group) onStatusSelected;
  final void Function(OrderTimeRange range) onTimeSelected;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ordersFilterStatusLabel, style: subtitleStyle),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final status in OrderStatusGroup.values)
              ChoiceChip(
                label: Text(_statusLabel(l10n, status)),
                selected: filter.status == status,
                onSelected: (_) => onStatusSelected(status),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),
        Text(l10n.ordersFilterTimeLabel, style: subtitleStyle),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final range in OrderTimeRange.values)
              ChoiceChip(
                label: Text(_timeLabel(l10n, range)),
                selected: filter.time == range,
                onSelected: (_) => onTimeSelected(range),
              ),
          ],
        ),
        if (lastUpdated != null) ...[
          const SizedBox(height: AppTokens.spaceM),
          Text(
            l10n.ordersLastUpdatedText(_formatTimestamp(context, lastUpdated!)),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  String _statusLabel(AppLocalizations l10n, OrderStatusGroup status) {
    return switch (status) {
      OrderStatusGroup.all => l10n.ordersStatusAll,
      OrderStatusGroup.inProgress => l10n.ordersStatusInProgress,
      OrderStatusGroup.shipped => l10n.ordersStatusShipped,
      OrderStatusGroup.delivered => l10n.ordersStatusDelivered,
      OrderStatusGroup.canceled => l10n.ordersStatusCanceled,
    };
  }

  String _timeLabel(AppLocalizations l10n, OrderTimeRange range) {
    return switch (range) {
      OrderTimeRange.past30Days => l10n.ordersTimeRange30Days,
      OrderTimeRange.past90Days => l10n.ordersTimeRange90Days,
      OrderTimeRange.past6Months => l10n.ordersTimeRange6Months,
      OrderTimeRange.pastYear => l10n.ordersTimeRangeYear,
      OrderTimeRange.all => l10n.ordersTimeRangeAll,
    };
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeFormatter = DateFormat.yMMMd(locale).add_Hm();
    return timeFormatter.format(timestamp);
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    final headline = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final totalText = _formatTotal(order, context);
    final design = order.lineItems.isNotEmpty
        ? order.lineItems.first.designSnapshot ?? const <String, dynamic>{}
        : const <String, dynamic>{};
    final emoji =
        design['emoji'] as String? ??
        order.metadata?['emoji'] as String? ??
        '印';
    final tileColor = _resolveTileColor(
      design['background'],
      order.metadata?['tileColor'],
      scheme,
    );

    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderThumbnail(emoji: emoji, background: tileColor),
              const SizedBox(width: AppTokens.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber, style: headline),
                    const SizedBox(height: AppTokens.spaceXS),
                    if (order.lineItems.isNotEmpty)
                      Text(
                        order.lineItems.first.name ?? l10n.ordersUnknownItem,
                        style: subtitleStyle,
                      ),
                    const SizedBox(height: AppTokens.spaceS),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: AppTokens.spaceXS),
                        Text(
                          totalText,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _OrderStatusChip(order: order),
                  const SizedBox(height: AppTokens.spaceS),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          _OrderTimeline(order: order),
        ],
      ),
    );
  }

  String _formatTotal(Order order, BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isJpy = order.currency == 'JPY';
    final format = NumberFormat.currency(
      locale: locale.toLanguageTag(),
      symbol: isJpy
          ? '¥'
          : NumberFormat.simpleCurrency(name: order.currency).currencySymbol,
      decimalDigits: isJpy ? 0 : 2,
    );
    return format.format(order.totals.total);
  }

  Color _resolveTileColor(
    dynamic designColor,
    dynamic metadataColor,
    ColorScheme scheme,
  ) {
    for (final candidate in [designColor, metadataColor]) {
      if (candidate is int) {
        return Color(candidate);
      }
      if (candidate is Color) {
        return candidate;
      }
    }
    return scheme.secondaryContainer;
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.emoji, required this.background});

  final String emoji;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.2),
        borderRadius: AppTokens.radiusL,
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}

class _OrderStatusChip extends StatelessWidget {
  const _OrderStatusChip({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = _statusColors(order.status, scheme);
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
        _statusLabel(l10n, order.status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _StatusColors _statusColors(OrderStatus status, ColorScheme scheme) {
    switch (status) {
      case OrderStatus.pendingPayment:
      case OrderStatus.paid:
        return _StatusColors(
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
        );
      case OrderStatus.inProduction:
      case OrderStatus.readyToShip:
        return _StatusColors(
          background: scheme.tertiaryContainer,
          foreground: scheme.onTertiaryContainer,
        );
      case OrderStatus.shipped:
        return _StatusColors(
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
        );
      case OrderStatus.delivered:
        return _StatusColors(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        );
      case OrderStatus.canceled:
      case OrderStatus.draft:
        return _StatusColors(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
        );
    }
  }

  String _statusLabel(AppLocalizations l10n, OrderStatus status) {
    return switch (status) {
      OrderStatus.pendingPayment => l10n.orderStatusPendingPayment,
      OrderStatus.paid => l10n.orderStatusPaid,
      OrderStatus.inProduction => l10n.orderStatusInProduction,
      OrderStatus.readyToShip => l10n.orderStatusReadyToShip,
      OrderStatus.shipped => l10n.orderStatusShipped,
      OrderStatus.delivered => l10n.orderStatusDelivered,
      OrderStatus.canceled || OrderStatus.draft => l10n.orderStatusCanceled,
    };
  }
}

class _StatusColors {
  const _StatusColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (order.status == OrderStatus.canceled ||
        order.status == OrderStatus.draft) {
      return Text(
        l10n.ordersTimelineCanceled,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final stops = [
      _TimelineStop(
        label: l10n.ordersTimelineOrdered,
        icon: Icons.shopping_bag_outlined,
      ),
      _TimelineStop(
        label: l10n.ordersTimelineProduction,
        icon: Icons.precision_manufacturing_outlined,
      ),
      _TimelineStop(
        label: l10n.ordersTimelineShipping,
        icon: Icons.local_shipping_outlined,
      ),
      _TimelineStop(
        label: l10n.ordersTimelineDelivered,
        icon: Icons.home_outlined,
      ),
    ];
    final progress = _progressIndex(order.status);

    return Wrap(
      spacing: AppTokens.spaceS,
      runSpacing: AppTokens.spaceXS,
      children: [
        for (var index = 0; index < stops.length; index++)
          Chip(
            avatar: Icon(
              stops[index].icon,
              size: 16,
              color: _chipIconColor(index, progress, scheme),
            ),
            label: Text(
              stops[index].label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _chipLabelColor(index, progress, scheme),
              ),
            ),
            backgroundColor: _chipBackground(index, progress, scheme),
            side: BorderSide(
              color: index <= progress
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.outlineVariant,
            ),
          ),
      ],
    );
  }

  int _progressIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.pendingPayment:
      case OrderStatus.paid:
        return 0;
      case OrderStatus.inProduction:
        return 1;
      case OrderStatus.readyToShip:
      case OrderStatus.shipped:
        return 2;
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.canceled:
      case OrderStatus.draft:
        return -1;
    }
  }

  Color _chipBackground(int index, int progress, ColorScheme scheme) {
    if (index < progress) {
      return scheme.primaryContainer.withValues(alpha: 0.45);
    }
    if (index == progress) {
      return scheme.primaryContainer.withValues(alpha: 0.75);
    }
    return scheme.surfaceContainerHighest.withValues(alpha: 0.7);
  }

  Color _chipLabelColor(int index, int progress, ColorScheme scheme) {
    if (index <= progress) {
      return scheme.onPrimaryContainer;
    }
    return scheme.onSurfaceVariant;
  }

  Color _chipIconColor(int index, int progress, ColorScheme scheme) {
    if (index <= progress) {
      return scheme.primary;
    }
    return scheme.onSurfaceVariant;
  }
}

class _TimelineStop {
  const _TimelineStop({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _OrdersListLoading extends StatelessWidget {
  const _OrdersListLoading({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceS,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ordersFilterStatusLabel, style: subtitleStyle),
                const SizedBox(height: AppTokens.spaceS),
                const _LoadingChips(),
                const SizedBox(height: AppTokens.spaceL),
                Text(l10n.ordersFilterTimeLabel, style: subtitleStyle),
                const SizedBox(height: AppTokens.spaceS),
                const _LoadingChips(),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            child: Column(
              children: [
                AppListSkeleton(items: 3),
                SizedBox(height: AppTokens.spaceL),
                AppListSkeleton(items: 2),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LoadingChips extends StatelessWidget {
  const _LoadingChips();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppTokens.spaceS,
      children: [
        AppSkeletonBlock(height: 32, width: 96),
        AppSkeletonBlock(height: 32, width: 88),
        AppSkeletonBlock(height: 32, width: 108),
      ],
    );
  }
}

class _OrdersListError extends StatelessWidget {
  const _OrdersListError({required this.controller, required this.onRetry});

  final ScrollController controller;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: AppEmptyState(
              title: l10n.ordersListErrorTitle,
              message: l10n.ordersListErrorMessage,
              icon: const Icon(Icons.wifi_off_outlined),
              primaryAction: AppButton(
                label: l10n.ordersListRetryLabel,
                onPressed: onRetry,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
