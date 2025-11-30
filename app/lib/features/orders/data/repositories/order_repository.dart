// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class OrderRepository {
  static const fallback = Scope<OrderRepository>.required('order.repository');

  Future<Page<Order>> listOrders({OrderStatus? status, String? pageToken});

  Future<Order> getOrder(String orderId);

  Future<Order> cancelOrder(String orderId, {String? reason});

  Future<void> requestInvoice(String orderId);

  Future<Order> reorder(String orderId);

  Future<List<OrderPayment>> listPayments(String orderId);

  Future<List<OrderShipment>> listShipments(String orderId);

  Future<List<ProductionEvent>> listProductionEvents(String orderId);
}
