import 'package:app/core/domain/entities/order.dart';
import 'package:flutter/foundation.dart';

enum OrderStatusGroup { all, inProgress, shipped, delivered, canceled }

enum OrderTimeRange { past30Days, past90Days, past6Months, pastYear, all }

@immutable
class OrderListFilter {
  const OrderListFilter({
    this.status = OrderStatusGroup.all,
    this.time = OrderTimeRange.past90Days,
  });

  factory OrderListFilter.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const OrderListFilter();
    }
    return OrderListFilter(
      status: _parseStatus(map['status'] as String?),
      time: _parseTime(map['time'] as String?),
    );
  }

  final OrderStatusGroup status;
  final OrderTimeRange time;

  OrderListFilter copyWith({OrderStatusGroup? status, OrderTimeRange? time}) {
    return OrderListFilter(
      status: status ?? this.status,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'status': status.name, 'time': time.name};
  }

  String get cacheKey => 'status:${status.name}|time:${time.name}';

  bool matches(Order order, DateTime now) {
    return _matchesStatus(order.status) && _matchesTime(order.createdAt, now);
  }

  bool _matchesStatus(OrderStatus orderStatus) {
    switch (status) {
      case OrderStatusGroup.all:
        return true;
      case OrderStatusGroup.inProgress:
        return switch (orderStatus) {
          OrderStatus.pendingPayment ||
          OrderStatus.paid ||
          OrderStatus.inProduction ||
          OrderStatus.readyToShip => true,
          _ => false,
        };
      case OrderStatusGroup.shipped:
        return orderStatus == OrderStatus.shipped;
      case OrderStatusGroup.delivered:
        return orderStatus == OrderStatus.delivered;
      case OrderStatusGroup.canceled:
        return orderStatus == OrderStatus.canceled ||
            orderStatus == OrderStatus.draft;
    }
  }

  bool _matchesTime(DateTime createdAt, DateTime now) {
    final cutoff = earliestDate(now);
    if (cutoff == null) {
      return true;
    }
    return !createdAt.isBefore(cutoff);
  }

  DateTime? earliestDate(DateTime now) {
    switch (time) {
      case OrderTimeRange.all:
        return null;
      case OrderTimeRange.past30Days:
        return now.subtract(const Duration(days: 30));
      case OrderTimeRange.past90Days:
        return now.subtract(const Duration(days: 90));
      case OrderTimeRange.past6Months:
        return now.subtract(const Duration(days: 180));
      case OrderTimeRange.pastYear:
        return now.subtract(const Duration(days: 365));
    }
  }

  static OrderStatusGroup _parseStatus(String? value) {
    return OrderStatusGroup.values.firstWhere(
      (element) => element.name == value,
      orElse: () => OrderStatusGroup.all,
    );
  }

  static OrderTimeRange _parseTime(String? value) {
    return OrderTimeRange.values.firstWhere(
      (element) => element.name == value,
      orElse: () => OrderTimeRange.past90Days,
    );
  }
}
