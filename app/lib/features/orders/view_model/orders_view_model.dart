// ignore_for_file: public_member_api_docs

import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/repositories/order_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum OrderTimeFilter { all, last30Days, last90Days, last365Days }

extension OrderTimeFilterX on OrderTimeFilter {
  DateTime? start(DateTime now) {
    return switch (this) {
      OrderTimeFilter.all => null,
      OrderTimeFilter.last30Days => now.subtract(const Duration(days: 30)),
      OrderTimeFilter.last90Days => now.subtract(const Duration(days: 90)),
      OrderTimeFilter.last365Days => now.subtract(const Duration(days: 365)),
    };
  }
}

class OrdersState {
  const OrdersState({
    required this.items,
    required this.status,
    required this.time,
    required this.nextPageToken,
    required this.isLoadingMore,
    required this.isRefreshing,
  });

  final List<Order> items;
  final OrderStatus? status;
  final OrderTimeFilter time;
  final String? nextPageToken;
  final bool isLoadingMore;
  final bool isRefreshing;

  OrdersState copyWith({
    List<Order>? items,
    OrderStatus? status,
    OrderTimeFilter? time,
    String? nextPageToken,
    bool? isLoadingMore,
    bool? isRefreshing,
  }) {
    return OrdersState(
      items: items ?? this.items,
      status: status ?? this.status,
      time: time ?? this.time,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class OrdersViewModel extends AsyncProvider<OrdersState> {
  OrdersViewModel() : super.args(null, autoDispose: true);

  late final loadMoreMut = mutation<void>(#loadMore);
  late final setStatusMut = mutation<OrderStatus?>(#setStatus);
  late final setTimeMut = mutation<OrderTimeFilter>(#setTime);
  late final refreshMut = mutation<void>(#refresh);

  @override
  Future<OrdersState> build(Ref<AsyncValue<OrdersState>> ref) async {
    final repository = ref.watch(orderRepositoryProvider);
    final page = await repository.listOrders();

    return OrdersState(
      items: page.items,
      status: null,
      time: OrderTimeFilter.all,
      nextPageToken: page.nextPageToken,
      isLoadingMore: false,
      isRefreshing: false,
    );
  }

  Call<void, AsyncValue<OrdersState>> loadMore() =>
      mutate(loadMoreMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;
        if (current.isLoadingMore) return;
        final next = current.nextPageToken;
        if (next == null) return;

        ref.state = AsyncData(current.copyWith(isLoadingMore: true));

        try {
          final repository = ref.watch(orderRepositoryProvider);
          final page = await repository.listOrders(
            status: current.status,
            pageToken: next,
          );
          final cutoff = current.time.start(DateTime.now());

          final filtered = _applyTimeFilter(page.items, cutoff: cutoff);
          final willExhaustRange =
              cutoff != null &&
              page.items.isNotEmpty &&
              page.items.last.createdAt.isBefore(cutoff);

          ref.state = AsyncData(
            current.copyWith(
              items: [...current.items, ...filtered],
              nextPageToken: willExhaustRange ? null : page.nextPageToken,
              isLoadingMore: false,
            ),
          );
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: current.copyWith(isLoadingMore: false),
          );
        }
      }, concurrency: Concurrency.dropLatest);

  Call<OrderStatus?, AsyncValue<OrdersState>> setStatus(OrderStatus? status) =>
      mutate(setStatusMut, (ref) async {
        final current = ref.watch(this).valueOrNull;

        if (current != null) {
          ref.state = AsyncData(
            current.copyWith(
              status: status,
              isRefreshing: true,
              nextPageToken: null,
              items: const <Order>[],
            ),
          );
        } else {
          ref.state = const AsyncLoading<OrdersState>();
        }

        try {
          final repository = ref.watch(orderRepositoryProvider);
          final page = await repository.listOrders(status: status);
          final cutoff = (current?.time ?? OrderTimeFilter.all).start(
            DateTime.now(),
          );

          final filtered = _applyTimeFilter(page.items, cutoff: cutoff);
          final willExhaustRange =
              cutoff != null &&
              page.items.isNotEmpty &&
              page.items.last.createdAt.isBefore(cutoff);

          ref.state = AsyncData(
            OrdersState(
              items: filtered,
              status: status,
              time: current?.time ?? OrderTimeFilter.all,
              nextPageToken: willExhaustRange ? null : page.nextPageToken,
              isLoadingMore: false,
              isRefreshing: false,
            ),
          );
          return status;
        } catch (e, stack) {
          ref.state = AsyncError(e, stack, previous: current);
          rethrow;
        }
      }, concurrency: Concurrency.restart);

  Call<OrderTimeFilter, AsyncValue<OrdersState>> setTime(
    OrderTimeFilter time,
  ) => mutate(setTimeMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final status = current?.status;

    if (current != null) {
      ref.state = AsyncData(
        current.copyWith(
          time: time,
          isRefreshing: true,
          nextPageToken: null,
          items: const <Order>[],
        ),
      );
    } else {
      ref.state = const AsyncLoading<OrdersState>();
    }

    try {
      final repository = ref.watch(orderRepositoryProvider);
      final page = await repository.listOrders(status: status);
      final cutoff = time.start(DateTime.now());

      final filtered = _applyTimeFilter(page.items, cutoff: cutoff);
      final willExhaustRange =
          cutoff != null &&
          page.items.isNotEmpty &&
          page.items.last.createdAt.isBefore(cutoff);

      ref.state = AsyncData(
        OrdersState(
          items: filtered,
          status: status,
          time: time,
          nextPageToken: willExhaustRange ? null : page.nextPageToken,
          isLoadingMore: false,
          isRefreshing: false,
        ),
      );
      return time;
    } catch (e, stack) {
      ref.state = AsyncError(e, stack, previous: current);
      rethrow;
    }
  }, concurrency: Concurrency.restart);

  Call<void, AsyncValue<OrdersState>> refresh() =>
      mutate(refreshMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final status = current?.status;
        final time = current?.time ?? OrderTimeFilter.all;

        if (current != null) {
          ref.state = AsyncData(current.copyWith(isRefreshing: true));
        } else {
          ref.state = const AsyncLoading<OrdersState>();
        }

        try {
          final repository = ref.watch(orderRepositoryProvider);
          final page = await repository.listOrders(status: status);
          final cutoff = time.start(DateTime.now());

          final filtered = _applyTimeFilter(page.items, cutoff: cutoff);
          final willExhaustRange =
              cutoff != null &&
              page.items.isNotEmpty &&
              page.items.last.createdAt.isBefore(cutoff);

          ref.state = AsyncData(
            OrdersState(
              items: filtered,
              status: status,
              time: time,
              nextPageToken: willExhaustRange ? null : page.nextPageToken,
              isLoadingMore: false,
              isRefreshing: false,
            ),
          );
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: current?.copyWith(isRefreshing: false),
          );
        }
      }, concurrency: Concurrency.restart);
}

final ordersViewModel = OrdersViewModel();

List<Order> _applyTimeFilter(List<Order> items, {required DateTime? cutoff}) {
  if (cutoff == null) return items;
  return items.where((o) => !o.createdAt.isBefore(cutoff)).toList();
}
