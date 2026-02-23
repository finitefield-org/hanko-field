import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppPageKey {
  static const order = 'order';
  static const paymentSuccess = 'payment_success';
  static const paymentFailure = 'payment_failure';
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
