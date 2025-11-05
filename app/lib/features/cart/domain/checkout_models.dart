import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/foundation.dart';

@immutable
class CheckoutState {
  const CheckoutState({
    this.selectedShippingAddress,
    this.selectedShippingOption,
    this.updatedAt,
  });

  final UserAddress? selectedShippingAddress;
  final CheckoutShippingOption? selectedShippingOption;
  final DateTime? updatedAt;

  String? get selectedAddressId => selectedShippingAddress?.id;

  String? get selectedShippingOptionId => selectedShippingOption?.id;

  bool get hasSelectedAddress => selectedShippingAddress != null;

  bool get hasSelectedShippingOption => selectedShippingOption != null;

  CheckoutState copyWith({
    UserAddress? selectedShippingAddress,
    CheckoutShippingOption? selectedShippingOption,
    bool clearSelectedAddress = false,
    bool clearSelectedShippingOption = false,
    DateTime? updatedAt,
  }) {
    return CheckoutState(
      selectedShippingAddress: clearSelectedAddress
          ? null
          : (selectedShippingAddress ?? this.selectedShippingAddress),
      selectedShippingOption: clearSelectedShippingOption
          ? null
          : (selectedShippingOption ?? this.selectedShippingOption),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension CheckoutStateX on CheckoutState {
  CheckoutState clearSelection() => copyWith(
    clearSelectedAddress: true,
    clearSelectedShippingOption: true,
    updatedAt: DateTime.now(),
  );
}

const CheckoutState kInitialCheckoutState = CheckoutState();
