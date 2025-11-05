import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/foundation.dart';

@immutable
class CheckoutState {
  const CheckoutState({
    this.selectedShippingAddress,
    this.selectedShippingOption,
    this.selectedPaymentMethod,
    this.updatedAt,
  });

  final UserAddress? selectedShippingAddress;
  final CheckoutShippingOption? selectedShippingOption;
  final CheckoutPaymentMethodSummary? selectedPaymentMethod;
  final DateTime? updatedAt;

  String? get selectedAddressId => selectedShippingAddress?.id;

  String? get selectedShippingOptionId => selectedShippingOption?.id;

  String? get selectedPaymentMethodId => selectedPaymentMethod?.id;

  bool get hasSelectedAddress => selectedShippingAddress != null;

  bool get hasSelectedShippingOption => selectedShippingOption != null;

  bool get hasSelectedPaymentMethod => selectedPaymentMethod != null;

  CheckoutState copyWith({
    UserAddress? selectedShippingAddress,
    CheckoutShippingOption? selectedShippingOption,
    CheckoutPaymentMethodSummary? selectedPaymentMethod,
    bool clearSelectedAddress = false,
    bool clearSelectedShippingOption = false,
    bool clearSelectedPaymentMethod = false,
    DateTime? updatedAt,
  }) {
    return CheckoutState(
      selectedShippingAddress: clearSelectedAddress
          ? null
          : (selectedShippingAddress ?? this.selectedShippingAddress),
      selectedShippingOption: clearSelectedShippingOption
          ? null
          : (selectedShippingOption ?? this.selectedShippingOption),
      selectedPaymentMethod: clearSelectedPaymentMethod
          ? null
          : (selectedPaymentMethod ?? this.selectedPaymentMethod),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension CheckoutStateX on CheckoutState {
  CheckoutState clearSelection() => copyWith(
    clearSelectedAddress: true,
    clearSelectedShippingOption: true,
    clearSelectedPaymentMethod: true,
    updatedAt: DateTime.now(),
  );
}

const CheckoutState kInitialCheckoutState = CheckoutState();
