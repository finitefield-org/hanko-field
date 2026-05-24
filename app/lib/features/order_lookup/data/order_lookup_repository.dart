import '../../../core/api/core_api.dart';
import '../../../core/domain/money.dart';
import '../domain/order_lookup_models.dart';

typedef OrderStatusFetcher = Future<OrderStatus> Function(String orderId);

Future<OrderStatus> fetchOrderStatusWithDefaultApi(String orderId) {
  return OrderLookupRepository(
    HankoApiClient(baseUri: Uri.parse(defaultHankoApiBaseUrl)),
  ).fetchOrderStatus(orderId);
}

Future<OrderStatus> lookupOrderWithDefaultApi(OrderLookupRequest request) {
  return OrderLookupRepository(
    HankoApiClient(baseUri: Uri.parse(defaultHankoApiBaseUrl)),
  ).lookupOrder(request);
}

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

  factory OrderStatusDto.fromJson(JsonMap json) {
    final payment = json['payment'] == null
        ? const <String, Object?>{}
        : asJsonMap(json['payment'], 'payment');
    final fulfillment = json['fulfillment'] == null
        ? const <String, Object?>{}
        : asJsonMap(json['fulfillment'], 'fulfillment');
    final seal = json['seal'] == null
        ? const <String, Object?>{}
        : asJsonMap(json['seal'], 'seal');
    final listing = json['listing'] == null
        ? const <String, Object?>{}
        : asJsonMap(json['listing'], 'listing');

    return OrderStatusDto(
      orderId: readString(json, 'order_id'),
      orderNo: readString(json, 'order_no'),
      createdAt: readOptionalDateTime(json, 'created_at'),
      orderStatus: readString(json, 'order_status', fallbackKey: 'status'),
      paymentStatus: readString(
        json,
        'payment_status',
        defaultValue: readString(payment, 'status'),
      ),
      fulfillmentStatus: readString(
        json,
        'fulfillment_status',
        defaultValue: readString(fulfillment, 'status'),
      ),
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
      trackingNumber:
          readOptionalString(json, 'tracking_number') ??
          readOptionalString(fulfillment, 'tracking_no'),
      fulfillmentCarrier: readOptionalString(fulfillment, 'carrier'),
      shippedAt: readOptionalDateTime(fulfillment, 'shipped_at'),
      sealText: readOptionalString(seal, 'confirmed_seal_text'),
      sealPreviewImageUrl: readOptionalString(seal, 'preview_image_url'),
      listingId: readOptionalString(listing, 'id'),
      listingTitle: readOptionalString(listing, 'title'),
      updatedAt: readOptionalDateTime(json, 'updated_at'),
    );
  }

  final String orderId;
  final String orderNo;
  final DateTime? createdAt;
  final String orderStatus;
  final String paymentStatus;
  final String fulfillmentStatus;
  final String productionStatus;
  final String shippingStatus;
  final OrderLookupPricingDto pricing;
  final String? trackingNumber;
  final String? fulfillmentCarrier;
  final DateTime? shippedAt;
  final String? sealText;
  final String? sealPreviewImageUrl;
  final String? listingId;
  final String? listingTitle;
  final DateTime? updatedAt;

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
      createdAt: createdAt,
      updatedAt: updatedAt,
      trackingNumber: trackingNumber,
      fulfillmentCarrier: fulfillmentCarrier,
      shippedAt: shippedAt,
      sealText: sealText,
      sealPreviewImageUrl: sealPreviewImageUrl,
      listingId: listingId,
      listingTitle: listingTitle,
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

DateTime? readOptionalDateTime(JsonMap json, String key) {
  final value = readOptionalString(json, key);
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}
