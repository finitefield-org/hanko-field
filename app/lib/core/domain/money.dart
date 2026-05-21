class Money {
  const Money({required this.amount, required this.currency, this.display});

  final int amount;
  final String currency;
  final String? display;
}
