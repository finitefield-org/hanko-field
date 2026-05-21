import '../../../core/api/core_api.dart';
import '../../../core/domain/money.dart';
import '../domain/order_lookup_models.dart';

class OrderLookupRepository {
  const OrderLookupRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<OrderStatus> fetchOrderStatus(String orderId) async {
    final encodedOrderId = Uri.encodeComponent(orderId);
    final json = await _apiClient.getJson('/v1/orders/$encodedOrderId/status');
    return OrderStatusDto.fromJson(json).toDomain();
  }

  Future<OrderStatus> lookupOrder(OrderLookupRequest request) async {
    final json = await _apiClient.postJson(
      '/v1/orders/lookup',
      OrderLookupRequestDto.fromDomain(request).toJson(),
    );
    return OrderStatusDto.fromJson(json).toDomain();
  }
}

class OrderLookupRequestDto {
  const OrderLookupRequestDto({required this.orderNo, required this.email});

  factory OrderLookupRequestDto.fromDomain(OrderLookupRequest request) {
    return OrderLookupRequestDto(
      orderNo: request.orderNo,
      email: request.email,
    );
  }

  final String orderNo;
  final String email;

  JsonMap toJson() {
    return {'order_no': orderNo, 'email': email};
  }
}

class OrderStatusDto {
  const OrderStatusDto({
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

  factory OrderStatusDto.fromJson(JsonMap json) {
    return OrderStatusDto(
      orderId: readString(json, 'order_id'),
      orderNo: readString(json, 'order_no'),
      orderStatus: readString(json, 'order_status', fallbackKey: 'status'),
      paymentStatus: readString(json, 'payment_status'),
      fulfillmentStatus: readString(json, 'fulfillment_status'),
      productionStatus: readString(
        json,
        'production_status',
        defaultValue: 'not_started',
      ),
      shippingStatus: readString(
        json,
        'shipping_status',
        defaultValue: 'not_shipped',
      ),
      pricing: OrderLookupPricingDto.fromJson(
        asJsonMap(json['pricing'], 'pricing'),
      ),
      trackingNumber: readOptionalString(json, 'tracking_number'),
    );
  }

  final String orderId;
  final String orderNo;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String productionStatus;
  final String shippingStatus;
  final OrderLookupPricingDto pricing;
  final String? trackingNumber;

  OrderStatus toDomain() {
    return OrderStatus(
      orderId: orderId,
      orderNo: orderNo,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      fulfillmentStatus: fulfillmentStatus,
      productionStatus: productionStatus,
      shippingStatus: shippingStatus,
      pricing: pricing.toDomain(),
      trackingNumber: trackingNumber,
    );
  }
}

class OrderLookupPricingDto {
  const OrderLookupPricingDto({required this.total, required this.currency});

  factory OrderLookupPricingDto.fromJson(JsonMap json) {
    return OrderLookupPricingDto(
      total: readInt(json, 'total'),
      currency: readString(json, 'currency'),
    );
  }

  final int total;
  final String currency;

  Money toDomain() {
    return Money(amount: total, currency: currency);
  }
}
