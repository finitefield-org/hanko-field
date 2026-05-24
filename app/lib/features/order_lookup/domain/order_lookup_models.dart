import '../../../core/domain/money.dart';

class OrderLookupRequest {
  const OrderLookupRequest({required this.orderNo, required this.email});

  final String orderNo;
  final String email;
}

typedef OrderLookupFetcher =
    Future<OrderStatus> Function(OrderLookupRequest request);

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
    this.createdAt,
    this.updatedAt,
    this.trackingNumber,
    this.fulfillmentCarrier,
    this.shippedAt,
    this.sealText,
    this.sealPreviewImageUrl,
    this.listingId,
    this.listingTitle,
  });

  final String orderId;
  final String orderNo;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String productionStatus;
  final String shippingStatus;
  final Money pricing;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? trackingNumber;
  final String? fulfillmentCarrier;
  final DateTime? shippedAt;
  final String? sealText;
  final String? sealPreviewImageUrl;
  final String? listingId;
  final String? listingTitle;
}
