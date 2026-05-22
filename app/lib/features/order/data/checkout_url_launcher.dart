import 'package:url_launcher/url_launcher.dart' as launcher;

import '../domain/order_models.dart';

typedef CheckoutUrlLauncher = Future<void> Function(CheckoutSession session);

class CheckoutUrlLaunchException implements Exception {
  const CheckoutUrlLaunchException(this.message);

  final String message;

  @override
  String toString() => 'CheckoutUrlLaunchException: $message';
}

Future<void> openCheckoutUrlWithDefaultLauncher(CheckoutSession session) async {
  final checkoutUrl = session.checkoutUrl.trim();
  final uri = Uri.tryParse(checkoutUrl);
  if (uri == null || !uri.hasScheme) {
    throw const CheckoutUrlLaunchException('checkout URL is invalid');
  }

  final didLaunch = await launcher.launchUrl(
    uri,
    mode: launcher.LaunchMode.externalApplication,
  );
  if (!didLaunch) {
    throw const CheckoutUrlLaunchException('checkout URL could not be opened');
  }
}
