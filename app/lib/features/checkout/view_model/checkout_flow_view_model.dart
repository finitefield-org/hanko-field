// ignore_for_file: public_member_api_docs

import 'package:miniriverpod/miniriverpod.dart';

class CheckoutFlowState {
  const CheckoutFlowState({
    this.addressId,
    this.shippingMethodId,
    this.paymentMethodId,
    this.isInternational = false,
  });

  final String? addressId;
  final String? shippingMethodId;
  final String? paymentMethodId;
  final bool isInternational;

  CheckoutFlowState copyWith({
    String? addressId,
    String? shippingMethodId,
    String? paymentMethodId,
    bool? isInternational,
    bool clearShipping = false,
    bool clearPayment = false,
  }) {
    return CheckoutFlowState(
      addressId: addressId ?? this.addressId,
      shippingMethodId: clearShipping
          ? null
          : (shippingMethodId ?? this.shippingMethodId),
      paymentMethodId: clearPayment
          ? null
          : (paymentMethodId ?? this.paymentMethodId),
      isInternational: isInternational ?? this.isInternational,
    );
  }
}

class CheckoutFlowViewModel extends Provider<CheckoutFlowState> {
  CheckoutFlowViewModel() : super.args(null, autoDispose: false);

  late final setAddressMut = mutation<void>(#setAddress);

  @override
  CheckoutFlowState build(Ref ref) => const CheckoutFlowState();

  Call<void> setAddress({
    required String? addressId,
    required bool isInternational,
  }) => mutate(setAddressMut, (ref) async {
    final current = ref.watch(this);
    ref.state = current.copyWith(
      addressId: addressId,
      isInternational: isInternational,
      clearShipping: true,
      clearPayment: true,
    );
  }, concurrency: Concurrency.dropLatest);
}

final checkoutFlowProvider = CheckoutFlowViewModel();
