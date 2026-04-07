import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppPageKey {
  static const top = 'top';
  static const order = 'order';
  static const paymentSuccess = 'payment_success';
  static const paymentFailure = 'payment_failure';
}

@immutable
class PaymentPageData {
  final String? orderId;
  final String? sessionId;

  const PaymentPageData({this.orderId, this.sessionId});
}

@immutable
class AppNavState {
  final List<PageEntry> pages;
  final int serial;

  const AppNavState({required this.pages, required this.serial});

  AppNavState copyWith({List<PageEntry>? pages, int? serial}) {
    return AppNavState(
      pages: pages ?? this.pages,
      serial: serial ?? this.serial,
    );
  }
}
