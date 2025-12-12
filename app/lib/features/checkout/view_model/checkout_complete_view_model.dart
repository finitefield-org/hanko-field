// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum CheckoutNotificationStatus { unknown, denied, authorized }

class CheckoutCompleteState {
  const CheckoutCompleteState({
    required this.orderNumber,
    required this.cart,
    required this.total,
    required this.estimatedDeliveryLabel,
    required this.notificationStatus,
  });

  final String orderNumber;
  final CartState cart;
  final Money total;
  final String? estimatedDeliveryLabel;
  final CheckoutNotificationStatus notificationStatus;
}

class CheckoutCompleteViewModel extends AsyncProvider<CheckoutCompleteState> {
  CheckoutCompleteViewModel({required this.orderId, required this.orderNumber})
    : super.args((orderId, orderNumber), autoDispose: true);

  final String? orderId;
  final String? orderNumber;

  late final requestNotificationsMut = mutation<CheckoutNotificationStatus>(
    #requestNotifications,
  );

  @override
  Future<CheckoutCompleteState> build(Ref ref) async {
    final flow = ref.watch(checkoutFlowProvider);
    final cartAsync = ref.watch(cartViewModel);
    final CartState cart =
        cartAsync.valueOrNull ?? await ref.watch(cartViewModel.future);

    final messaging = ref.watch(firebaseMessagingProvider);
    final settings = await messaging.getNotificationSettings();

    final computedOrderNumber =
        _normalizeOrderNumber(orderNumber) ??
        _fallbackOrderNumber(now: DateTime.now(), seed: orderId);

    final estimatedDeliveryLabel = _formatEtaLabel(
      minDays: flow.shippingEtaMinDays,
      maxDays: flow.shippingEtaMaxDays,
    );

    return CheckoutCompleteState(
      orderNumber: computedOrderNumber,
      cart: cart,
      total: cart.total,
      estimatedDeliveryLabel: estimatedDeliveryLabel,
      notificationStatus: _notificationStatus(settings.authorizationStatus),
    );
  }

  Call<CheckoutNotificationStatus> requestNotifications() =>
      mutate(requestNotificationsMut, (ref) async {
        final messaging = ref.watch(firebaseMessagingProvider);
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );
        await ref.refreshValue(this, keepPrevious: true);
        return _notificationStatus(settings.authorizationStatus);
      }, concurrency: Concurrency.dropLatest);
}

CheckoutNotificationStatus _notificationStatus(
  AuthorizationStatus authorizationStatus,
) {
  return switch (authorizationStatus) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => CheckoutNotificationStatus.authorized,
    AuthorizationStatus.denied => CheckoutNotificationStatus.denied,
    _ => CheckoutNotificationStatus.unknown,
  };
}

String? _normalizeOrderNumber(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _fallbackOrderNumber({required DateTime now, String? seed}) {
  final seedValue = seed?.hashCode ?? now.millisecondsSinceEpoch;
  final random = Random(seedValue);
  final digits = List<int>.generate(6, (_) => random.nextInt(10)).join();
  return 'HF-$digits';
}

String? _formatEtaLabel({required int? minDays, required int? maxDays}) {
  if (minDays == null || maxDays == null) return null;
  if (minDays == maxDays) return '$minDays days';
  return '$minDays–$maxDays days';
}
