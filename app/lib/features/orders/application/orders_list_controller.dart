import 'dart:async';

import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/domain/repositories/order_repository.dart';
import 'package:app/features/orders/data/order_repository_provider.dart';
import 'package:app/features/orders/domain/order_list_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final ordersFilterProvider = StateProvider<OrderListFilter>(
  (ref) => const OrderListFilter(),
);

final ordersListControllerProvider =
    AsyncNotifierProvider<OrdersListController, OrdersListState>(
      OrdersListController.new,
    );

class OrdersListState {
  const OrdersListState({
    required this.orders,
    required this.filter,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  final List<Order> orders;
  final OrderListFilter filter;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  static const _sentinel = Object();

  OrdersListState copyWith({
    List<Order>? orders,
    OrderListFilter? filter,
    Object? nextCursor = _sentinel,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    DateTime? lastUpdated,
  }) {
    return OrdersListState(
      orders: orders ?? this.orders,
      filter: filter ?? this.filter,
      nextCursor: nextCursor == _sentinel
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class OrdersListController extends AsyncNotifier<OrdersListState> {
  static const int pageSize = 10;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);

  @override
  FutureOr<OrdersListState> build() async {
    final filter = ref.watch(ordersFilterProvider);
    return _loadInitial(filter);
  }

  Future<OrdersListState> _loadInitial(OrderListFilter filter) async {
    final result = await _repository.fetchOrders(
      pageSize: pageSize + 1,
      filters: filter.toMap(),
    );
    final items = result.take(pageSize).toList(growable: false);
    final hasMore = result.length > pageSize;
    final nextCursor = hasMore && items.isNotEmpty ? items.last.id : null;
    return OrdersListState(
      orders: List<Order>.unmodifiable(items),
      filter: filter,
      hasMore: hasMore,
      nextCursor: nextCursor,
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isRefreshing: true));
    }
    try {
      final filter = ref.read(ordersFilterProvider);
      final next = await _loadInitial(filter);
      state = AsyncValue.data(next);
    } catch (error, stackTrace) {
      if (current != null) {
        state = AsyncValue.data(current.copyWith(isRefreshing: false));
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        state.isLoading) {
      return;
    }
    final pending = current.copyWith(isLoadingMore: true);
    state = AsyncValue.data(pending);
    try {
      final filter = ref.read(ordersFilterProvider);
      final result = await _repository.fetchOrders(
        pageSize: pageSize + 1,
        pageToken: current.nextCursor,
        filters: filter.toMap(),
      );
      if (result.isEmpty) {
        state = AsyncValue.data(
          pending.copyWith(
            hasMore: false,
            nextCursor: null,
            isLoadingMore: false,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }
      final newItems = result.take(pageSize).toList();
      final existingIds = <String>{
        for (final order in current.orders) order.id,
      };
      final appended = <Order>[];
      for (final order in newItems) {
        if (existingIds.add(order.id)) {
          appended.add(order);
        }
      }
      if (appended.isEmpty) {
        state = AsyncValue.data(
          pending.copyWith(
            isLoadingMore: false,
            hasMore: false,
            nextCursor: null,
            lastUpdated: DateTime.now(),
          ),
        );
        return;
      }
      final merged = [...current.orders, ...appended];
      final hasMore = result.length > pageSize;
      final nextCursor = hasMore && merged.isNotEmpty ? merged.last.id : null;
      state = AsyncValue.data(
        pending.copyWith(
          orders: List<Order>.unmodifiable(merged),
          hasMore: hasMore,
          nextCursor: nextCursor,
          isLoadingMore: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void changeStatus(OrderStatusGroup status) {
    final controller = ref.read(ordersFilterProvider.notifier);
    final current = controller.state;
    if (current.status == status) {
      return;
    }
    controller.state = current.copyWith(status: status);
    state = const AsyncValue.loading();
  }

  void changeTimeRange(OrderTimeRange timeRange) {
    final controller = ref.read(ordersFilterProvider.notifier);
    final current = controller.state;
    if (current.time == timeRange) {
      return;
    }
    controller.state = current.copyWith(time: timeRange);
    state = const AsyncValue.loading();
  }
}
