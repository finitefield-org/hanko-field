// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

class Money {
  const Money({required this.amount, required this.currency});

  final int amount;
  final String currency;

  Money copyWith({int? amount, String? currency}) {
    return Money(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'amount': amount,
    'currency': currency,
  };

  static Money fromJson(Map<String, Object?> json) {
    return Money(
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Money &&
            other.amount == amount &&
            other.currency == currency);
  }

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => 'Money($amount $currency)';
}

class Page<T> {
  const Page({required this.items, this.nextPageToken});

  final List<T> items;
  final String? nextPageToken;

  Page<T> copyWith({List<T>? items, String? nextPageToken}) {
    return Page(
      items: items ?? this.items,
      nextPageToken: nextPageToken ?? this.nextPageToken,
    );
  }

  @override
  bool operator ==(Object other) {
    final listEq = ListEquality<T>();
    return identical(this, other) ||
        (other is Page<T> &&
            listEq.equals(other.items, items) &&
            other.nextPageToken == nextPageToken);
  }

  @override
  int get hashCode {
    final listEq = ListEquality<T>();
    return Object.hash(listEq.hash(items), nextPageToken);
  }

  @override
  String toString() => 'Page(items: ${items.length}, next: $nextPageToken)';
}
