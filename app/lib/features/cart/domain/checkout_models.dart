import 'package:app/core/domain/entities/user.dart';
import 'package:flutter/foundation.dart';

@immutable
class CheckoutState {
  const CheckoutState({this.selectedShippingAddress, this.updatedAt});

  final UserAddress? selectedShippingAddress;
  final DateTime? updatedAt;

  String? get selectedAddressId => selectedShippingAddress?.id;

  bool get hasSelectedAddress => selectedShippingAddress != null;

  CheckoutState copyWith({
    UserAddress? selectedShippingAddress,
    bool clearSelectedAddress = false,
    DateTime? updatedAt,
  }) {
    return CheckoutState(
      selectedShippingAddress: clearSelectedAddress
          ? null
          : (selectedShippingAddress ?? this.selectedShippingAddress),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension CheckoutStateX on CheckoutState {
  CheckoutState clearSelection() =>
      copyWith(clearSelectedAddress: true, updatedAt: DateTime.now());
}

const CheckoutState kInitialCheckoutState = CheckoutState();
