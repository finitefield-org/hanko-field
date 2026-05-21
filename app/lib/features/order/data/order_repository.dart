import '../../../core/api/core_api.dart';
import '../../../core/domain/money.dart';
import '../domain/order_models.dart';

class OrderRepository {
  const OrderRepository(this._apiClient);

  final HankoApiClient _apiClient;

  Future<CreatedOrder> createOrder(SealOrderDraft draft) async {
    final json = await _apiClient.postJson(
      '/v1/orders',
      CreateOrderRequestDto.fromDomain(draft).toJson(),
    );
    return CreateOrderResponseDto.fromJson(json).toDomain();
  }

  Future<CheckoutSession> createCheckoutSession(
    CheckoutSessionRequest request,
  ) async {
    final json = await _apiClient.postJson(
      '/v1/payments/stripe/checkout-session',
      CreateCheckoutSessionRequestDto.fromDomain(request).toJson(),
    );
    return CreateCheckoutSessionResponseDto.fromJson(json).toDomain();
  }
}

class CreateOrderRequestDto {
  const CreateOrderRequestDto({
    required this.channel,
    required this.locale,
    required this.idempotencyKey,
    required this.termsAgreed,
    required this.seal,
    required this.listingId,
    required this.shipping,
    required this.contact,
  });

  factory CreateOrderRequestDto.fromDomain(SealOrderDraft draft) {
    return CreateOrderRequestDto(
      channel: draft.channel,
      locale: draft.locale,
      idempotencyKey: draft.idempotencyKey,
      termsAgreed: draft.termsAgreed,
      seal: CreateOrderSealDto.fromDomain(draft.seal),
      listingId: draft.listingId,
      shipping: CreateOrderShippingDto.fromDomain(draft.shipping),
      contact: CreateOrderContactDto.fromDomain(draft.contact),
    );
  }

  final String channel;
  final String locale;
  final String idempotencyKey;
  final bool termsAgreed;
  final CreateOrderSealDto seal;
  final String? listingId;
  final CreateOrderShippingDto shipping;
  final CreateOrderContactDto contact;

  JsonMap toJson() {
    return {
      'channel': channel,
      'locale': locale,
      'idempotency_key': idempotencyKey,
      'terms_agreed': termsAgreed,
      'seal': seal.toJson(),
      if (listingId != null) 'listing_id': listingId,
      'shipping': shipping.toJson(),
      'contact': contact.toJson(),
    };
  }
}

class CreateOrderSealDto {
  const CreateOrderSealDto({
    required this.line1,
    required this.line2,
    required this.shape,
    required this.fontKey,
  });

  factory CreateOrderSealDto.fromDomain(SealOrderSeal seal) {
    return CreateOrderSealDto(
      line1: seal.line1,
      line2: seal.line2,
      shape: seal.shape,
      fontKey: seal.fontKey,
    );
  }

  final String line1;
  final String line2;
  final String shape;
  final String fontKey;

  JsonMap toJson() {
    return {
      'line1': line1,
      'line2': line2,
      'shape': shape,
      'font_key': fontKey,
    };
  }
}

class CreateOrderShippingDto {
  const CreateOrderShippingDto({
    required this.countryCode,
    required this.recipientName,
    required this.phone,
    required this.postalCode,
    required this.state,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
  });

  factory CreateOrderShippingDto.fromDomain(SealOrderShipping shipping) {
    return CreateOrderShippingDto(
      countryCode: shipping.countryCode,
      recipientName: shipping.recipientName,
      phone: shipping.phone,
      postalCode: shipping.postalCode,
      state: shipping.state,
      city: shipping.city,
      addressLine1: shipping.addressLine1,
      addressLine2: shipping.addressLine2,
    );
  }

  final String countryCode;
  final String recipientName;
  final String phone;
  final String postalCode;
  final String state;
  final String city;
  final String addressLine1;
  final String addressLine2;

  JsonMap toJson() {
    return {
      'country_code': countryCode,
      'recipient_name': recipientName,
      'phone': phone,
      'postal_code': postalCode,
      'state': state,
      'city': city,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
    };
  }
}

class CreateOrderContactDto {
  const CreateOrderContactDto({
    required this.email,
    required this.preferredLocale,
  });

  factory CreateOrderContactDto.fromDomain(SealOrderContact contact) {
    return CreateOrderContactDto(
      email: contact.email,
      preferredLocale: contact.preferredLocale,
    );
  }

  final String email;
  final String preferredLocale;

  JsonMap toJson() {
    return {'email': email, 'preferred_locale': preferredLocale};
  }
}

class CreateOrderResponseDto {
  const CreateOrderResponseDto({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.pricing,
    required this.idempotentReplay,
  });

  factory CreateOrderResponseDto.fromJson(JsonMap json) {
    return CreateOrderResponseDto(
      orderId: readString(json, 'order_id'),
      orderNo: readString(json, 'order_no'),
      status: readString(json, 'status'),
      paymentStatus: readString(json, 'payment_status'),
      fulfillmentStatus: readString(json, 'fulfillment_status'),
      pricing: OrderPricingDto.fromJson(asJsonMap(json['pricing'], 'pricing')),
      idempotentReplay: readBool(json, 'idempotent_replay'),
    );
  }

  final String orderId;
  final String orderNo;
  final String status;
  final String paymentStatus;
  final String fulfillmentStatus;
  final OrderPricingDto pricing;
  final bool idempotentReplay;

  CreatedOrder toDomain() {
    return CreatedOrder(
      orderId: orderId,
      orderNo: orderNo,
      status: status,
      paymentStatus: paymentStatus,
      fulfillmentStatus: fulfillmentStatus,
      pricing: pricing.toDomain(),
      idempotentReplay: idempotentReplay,
    );
  }
}

class OrderPricingDto {
  const OrderPricingDto({required this.total, required this.currency});

  factory OrderPricingDto.fromJson(JsonMap json) {
    return OrderPricingDto(
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

class CreateCheckoutSessionRequestDto {
  const CreateCheckoutSessionRequestDto({
    required this.orderId,
    this.customerEmail,
  });

  factory CreateCheckoutSessionRequestDto.fromDomain(
    CheckoutSessionRequest request,
  ) {
    return CreateCheckoutSessionRequestDto(
      orderId: request.orderId,
      customerEmail: request.customerEmail,
    );
  }

  final String orderId;
  final String? customerEmail;

  JsonMap toJson() {
    return {
      'order_id': orderId,
      if (customerEmail != null) 'customer_email': customerEmail,
    };
  }
}

class CreateCheckoutSessionResponseDto {
  const CreateCheckoutSessionResponseDto({
    required this.orderId,
    required this.sessionId,
    required this.checkoutUrl,
    required this.paymentIntentId,
  });

  factory CreateCheckoutSessionResponseDto.fromJson(JsonMap json) {
    return CreateCheckoutSessionResponseDto(
      orderId: readString(json, 'order_id'),
      sessionId: readString(json, 'session_id'),
      checkoutUrl: readString(json, 'checkout_url'),
      paymentIntentId: readString(json, 'payment_intent_id'),
    );
  }

  final String orderId;
  final String sessionId;
  final String checkoutUrl;
  final String paymentIntentId;

  CheckoutSession toDomain() {
    return CheckoutSession(
      orderId: orderId,
      sessionId: sessionId,
      checkoutUrl: checkoutUrl,
      paymentIntentId: paymentIntentId,
    );
  }
}
