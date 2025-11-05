import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkoutStateProvider =
    NotifierProvider<CheckoutStateNotifier, CheckoutState>(
      CheckoutStateNotifier.new,
      name: 'checkoutStateProvider',
    );

class CheckoutStateNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => kInitialCheckoutState;

  void setSelectedAddress(UserAddress address) {
    state = state.copyWith(
      selectedShippingAddress: address,
      updatedAt: DateTime.now(),
    );
  }

  void clearSelectedAddress() {
    if (!state.hasSelectedAddress) {
      return;
    }
    state = state.clearSelection();
  }

  void setShippingOption(CheckoutShippingOption option) {
    state = state.copyWith(
      selectedShippingOption: option,
      updatedAt: DateTime.now(),
    );
  }

  void clearShippingOption() {
    if (!state.hasSelectedShippingOption) {
      return;
    }
    state = state.copyWith(
      clearSelectedShippingOption: true,
      updatedAt: DateTime.now(),
    );
  }

  void setPaymentMethod(CheckoutPaymentMethodSummary method) {
    state = state.copyWith(
      selectedPaymentMethod: method,
      updatedAt: DateTime.now(),
    );
  }

  void clearPaymentMethod() {
    if (!state.hasSelectedPaymentMethod) {
      return;
    }
    state = state.copyWith(
      clearSelectedPaymentMethod: true,
      updatedAt: DateTime.now(),
    );
  }
}
