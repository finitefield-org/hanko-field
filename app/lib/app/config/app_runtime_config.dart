import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:miniriverpod/miniriverpod.dart';

@immutable
class AppRuntimeConfig {
  final String apiBaseUrl;
  final String preferredLocale;

  const AppRuntimeConfig({
    required this.apiBaseUrl,
    required this.preferredLocale,
  });
}

final appRuntimeConfigProvider = Provider<AppRuntimeConfig>((ref) {
  final configuredBaseUrl = const String.fromEnvironment(
    'HANKO_APP_API_BASE_URL',
  ).trim();
  final configuredLocale = const String.fromEnvironment(
    'HANKO_APP_LOCALE',
  ).trim().toLowerCase();

  final locale = configuredLocale.isNotEmpty
      ? configuredLocale
      : WidgetsBinding.instance.platformDispatcher.locale.languageCode
            .toLowerCase();

  final apiBaseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : _defaultApiBaseUrl();

  return AppRuntimeConfig(apiBaseUrl: apiBaseUrl, preferredLocale: locale);
});

String _defaultApiBaseUrl() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3050';
  }
  return 'http://localhost:3050';
}
