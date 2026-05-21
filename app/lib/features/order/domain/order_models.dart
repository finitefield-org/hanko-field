import '../../../core/domain/money.dart';

class SealOrderDraft {
  const SealOrderDraft({
    required this.channel,
    required this.locale,
    required this.idempotencyKey,
    required this.termsAgreed,
    required this.seal,
    required this.shipping,
    required this.contact,
    this.listingId,
  });

  final String channel;
  final String locale;
  final String idempotencyKey;
  final bool termsAgreed;
  final SealOrderSeal seal;
  final String? listingId;
  final SealOrderShipping shipping;
  final SealOrderContact contact;
}

class SealOrderSeal {
  const SealOrderSeal({
    required this.line1,
    required this.line2,
    required this.shape,
    required this.fontKey,
  });

  final String line1;
  final String line2;
  final String shape;
  final String fontKey;
}

class SealOrderShipping {
  const SealOrderShipping({
    required this.countryCode,
    required this.recipientName,
    required this.phone,
    required this.postalCode,
    required this.state,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
  });

  final String countryCode;
  final String recipientName;
  final String phone;
  final String postalCode;
  final String state;
  final String city;
  final String addressLine1;
  final String addressLine2;
}

class SealOrderContact {
  const SealOrderContact({required this.email, required this.preferredLocale});

  final String email;
  final String preferredLocale;
}

class CreatedOrder {
  const CreatedOrder({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.pricing,
    required this.idempotentReplay,
  });

  final String orderId;
  final String orderNo;
  final String status;
  final String paymentStatus;
  final String fulfillmentStatus;
  final Money pricing;
  final bool idempotentReplay;
}

class CheckoutSessionRequest {
  const CheckoutSessionRequest({required this.orderId, this.customerEmail});

  final String orderId;
  final String? customerEmail;
}

class CheckoutSession {
  const CheckoutSession({
    required this.orderId,
    required this.sessionId,
    required this.checkoutUrl,
    required this.paymentIntentId,
  });

  final String orderId;
  final String sessionId;
  final String checkoutUrl;
  final String paymentIntentId;
}
