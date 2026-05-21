import '../../../core/domain/money.dart';

class OrderLookupRequest {
  const OrderLookupRequest({required this.orderNo, required this.email});

  final String orderNo;
  final String email;
}

class OrderStatus {
  const OrderStatus({
    required this.orderId,
    required this.orderNo,
    required this.orderStatus,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.productionStatus,
    required this.shippingStatus,
    required this.pricing,
    this.trackingNumber,
  });

  final String orderId;
  final String orderNo;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String productionStatus;
  final String shippingStatus;
  final Money pricing;
  final String? trackingNumber;
}
