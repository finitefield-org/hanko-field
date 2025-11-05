import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
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
}
