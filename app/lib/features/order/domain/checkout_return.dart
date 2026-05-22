enum CheckoutReturnOutcome { success, canceled, failed }

class CheckoutReturnResult {
  const CheckoutReturnResult({
    required this.outcome,
    required this.sourceUri,
    this.orderId,
    this.sessionId,
    this.locale,
  });

  final CheckoutReturnOutcome outcome;
  final Uri sourceUri;
  final String? orderId;
  final String? sessionId;
  final String? locale;
}

CheckoutReturnResult? parseCheckoutReturnRoute(String route) {
  final trimmed = route.trim();
  if (trimmed.isEmpty || trimmed == '/') {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }
  return parseCheckoutReturnUri(uri);
}

CheckoutReturnResult? parseCheckoutReturnUri(Uri uri) {
  final outcome = _checkoutReturnOutcome(uri);
  if (outcome == null) {
    return null;
  }

  return CheckoutReturnResult(
    outcome: outcome,
    sourceUri: uri,
    orderId: _firstPresentQueryValue(uri, const ['order_id', 'orderId']),
    sessionId: _firstPresentQueryValue(uri, const [
      'session_id',
      'checkout_session_id',
      'sessionId',
    ]),
    locale: _firstPresentQueryValue(uri, const ['lang', 'locale']),
  );
}

CheckoutReturnOutcome? _checkoutReturnOutcome(Uri uri) {
  final segments = _checkoutReturnSegments(uri);
  final checkout = uri.queryParameters['checkout']?.trim().toLowerCase();
  final byQuery = _outcomeFromToken(checkout);
  if (byQuery != null && _hasCheckoutReturnNamespace(segments)) {
    return byQuery;
  }

  for (var index = 0; index < segments.length - 1; index += 1) {
    final segment = segments[index];
    if (segment != 'payment' && segment != 'checkout') {
      continue;
    }
    final byPath = _outcomeFromToken(segments[index + 1]);
    if (byPath != null) {
      return byPath;
    }
  }

  return null;
}

bool _hasCheckoutReturnNamespace(List<String> segments) {
  return segments.contains('payment') || segments.contains('checkout');
}

List<String> _checkoutReturnSegments(Uri uri) {
  final segments =
      <String>[
            if (uri.scheme == 'hankofield' && uri.host.isNotEmpty) uri.host,
            ...uri.pathSegments,
          ]
          .map((segment) => segment.trim().toLowerCase())
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);

  if (segments.isNotEmpty &&
      (segments.first == 'en' || segments.first == 'ja')) {
    return segments.skip(1).toList(growable: false);
  }
  return segments;
}

CheckoutReturnOutcome? _outcomeFromToken(String? token) {
  return switch (token) {
    'success' || 'succeeded' || 'paid' => CheckoutReturnOutcome.success,
    'cancel' || 'canceled' || 'cancelled' => CheckoutReturnOutcome.canceled,
    'failed' || 'failure' || 'error' => CheckoutReturnOutcome.failed,
    _ => null,
  };
}

String? _firstPresentQueryValue(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
