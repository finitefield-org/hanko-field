// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:miniriverpod/miniriverpod.dart';

class CheckoutFlowState {
  const CheckoutFlowState({
    this.addressId,
    this.shippingMethodId,
    this.paymentMethodId,
    this.paymentProviderRef,
    this.isInternational = false,
    this.shippingCost,
    this.shippingEtaMinDays,
    this.shippingEtaMaxDays,
  });

  final String? addressId;
  final String? shippingMethodId;
  final String? paymentMethodId;
  final String? paymentProviderRef;
  final bool isInternational;
  final Money? shippingCost;
  final int? shippingEtaMinDays;
  final int? shippingEtaMaxDays;

  CheckoutFlowState copyWith({
    String? addressId,
    String? shippingMethodId,
    String? paymentMethodId,
    String? paymentProviderRef,
    bool? isInternational,
    Money? shippingCost,
    int? shippingEtaMinDays,
    int? shippingEtaMaxDays,
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
      paymentProviderRef: clearPayment
          ? null
          : (paymentProviderRef ?? this.paymentProviderRef),
      isInternational: isInternational ?? this.isInternational,
      shippingCost: clearShipping ? null : (shippingCost ?? this.shippingCost),
      shippingEtaMinDays: clearShipping
          ? null
          : (shippingEtaMinDays ?? this.shippingEtaMinDays),
      shippingEtaMaxDays: clearShipping
          ? null
          : (shippingEtaMaxDays ?? this.shippingEtaMaxDays),
    );
  }
}

class CheckoutFlowViewModel extends Provider<CheckoutFlowState> {
  CheckoutFlowViewModel() : super.args(null, autoDispose: false);

  late final setAddressMut = mutation<void>(#setAddress);
  late final setShippingMut = mutation<void>(#setShipping);
  late final setPaymentMut = mutation<void>(#setPayment);

  @override
  CheckoutFlowState build(Ref<CheckoutFlowState> ref) =>
      const CheckoutFlowState();

  Call<void, CheckoutFlowState> setAddress({
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

  Call<void, CheckoutFlowState> setShipping({
    required String shippingMethodId,
    required Money shippingCost,
    required int etaMinDays,
    required int etaMaxDays,
  }) => mutate(setShippingMut, (ref) async {
    final current = ref.watch(this);
    ref.state = current.copyWith(
      shippingMethodId: shippingMethodId,
      shippingCost: shippingCost,
      shippingEtaMinDays: etaMinDays,
      shippingEtaMaxDays: etaMaxDays,
      clearPayment: true,
    );
  }, concurrency: Concurrency.dropLatest);

  Call<void, CheckoutFlowState> setPayment({
    required String? paymentMethodId,
    required String? paymentProviderRef,
  }) => mutate(setPaymentMut, (ref) async {
    final current = ref.watch(this);
    ref.state = current.copyWith(
      paymentMethodId: paymentMethodId,
      paymentProviderRef: paymentProviderRef,
    );
  }, concurrency: Concurrency.dropLatest);
}

final checkoutFlowProvider = CheckoutFlowViewModel();
