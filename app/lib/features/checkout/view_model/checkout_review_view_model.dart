// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_address_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_payment_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_shipping_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutReviewState {
  const CheckoutReviewState({
    required this.cart,
    required this.isInternational,
    required this.address,
    required this.shipping,
    required this.payment,
    required this.shippingCost,
    required this.tax,
    required this.total,
  });

  final CartState cart;
  final bool isInternational;
  final UserAddress? address;
  final ShippingOption? shipping;
  final PaymentMethod? payment;
  final Money shippingCost;
  final Money tax;
  final Money total;

  bool get hasItems => cart.lines.isNotEmpty;

  bool get isReadyForPlacement =>
      hasItems && address != null && shipping != null && payment != null;
}

class PlaceOrderResult {
  const PlaceOrderResult({
    required this.isSuccess,
    this.message,
    this.orderId,
    this.orderNumber,
  });

  final bool isSuccess;
  final String? message;
  final String? orderId;
  final String? orderNumber;
}

class CheckoutReviewViewModel extends AsyncProvider<CheckoutReviewState> {
  CheckoutReviewViewModel() : super.args(null, autoDispose: true);

  late final placeOrderMut = mutation<PlaceOrderResult>(#placeOrder);

  @override
  Future<CheckoutReviewState> build(
    Ref<AsyncValue<CheckoutReviewState>> ref,
  ) async {
    final flow = ref.watch(checkoutFlowProvider);
    final cartAsync = ref.watch(cartViewModel);
    final CartState cart =
        cartAsync.valueOrNull ?? await ref.watch(cartViewModel.future);

    final addressAsync = ref.watch(checkoutAddressViewModel);
    final addressState =
        addressAsync.valueOrNull ??
        (await ref.watch(checkoutAddressViewModel.future) ??
            (throw StateError('Missing address state')));

    final shippingAsync = ref.watch(checkoutShippingViewModel);
    final shippingState =
        shippingAsync.valueOrNull ??
        (await ref.watch(checkoutShippingViewModel.future) ??
            (throw StateError('Missing shipping state')));

    final paymentAsync = ref.watch(checkoutPaymentViewModel);
    final paymentState =
        paymentAsync.valueOrNull ??
        (await ref.watch(checkoutPaymentViewModel.future) ??
            (throw StateError('Missing payment state')));

    return CheckoutReviewState(
      cart: cart,
      isInternational: flow.isInternational,
      address: addressState.selectedAddress,
      shipping: shippingState.selectedOption,
      payment: paymentState.selectedMethod,
      shippingCost: shippingState.shippingCost,
      tax: shippingState.tax,
      total: shippingState.total,
    );
  }

  Call<PlaceOrderResult, AsyncValue<CheckoutReviewState>> placeOrder({
    String? notes,
  }) => mutate(placeOrderMut, (ref) async {
    final state = ref.watch(this).valueOrNull;
    if (state == null || !state.isReadyForPlacement) {
      final analytics = ref.watch(analyticsClientProvider);
      unawaited(
        analytics.track(
          CheckoutOrderPlacedEvent(
            success: false,
            totalAmount: state?.total.amount ?? 0,
            currency: state?.total.currency ?? 'JPY',
            itemCount: state?.cart.lines.length ?? 0,
            isInternational: state?.isInternational ?? false,
            hasPromo: state?.cart.appliedPromo != null,
            shippingMethodId: state?.shipping?.id ?? 'unknown',
            paymentMethodType: state?.payment?.methodType.name ?? 'unknown',
          ),
        ),
      );
      return const PlaceOrderResult(
        isSuccess: false,
        message: 'Missing checkout details.',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = (millis % 1000000).toString().padLeft(6, '0');

    final result = PlaceOrderResult(
      isSuccess: true,
      orderId: 'ord_$millis',
      orderNumber: 'HF-$suffix',
    );
    final analytics = ref.watch(analyticsClientProvider);
    unawaited(
      analytics.track(
        CheckoutOrderPlacedEvent(
          success: true,
          totalAmount: state.total.amount,
          currency: state.total.currency,
          itemCount: state.cart.lines.length,
          isInternational: state.isInternational,
          hasPromo: state.cart.appliedPromo != null,
          shippingMethodId: state.shipping?.id ?? 'unknown',
          paymentMethodType: state.payment?.methodType.name ?? 'unknown',
        ),
      ),
    );
    return result;
  }, concurrency: Concurrency.dropLatest);
}

final checkoutReviewViewModel = CheckoutReviewViewModel();
