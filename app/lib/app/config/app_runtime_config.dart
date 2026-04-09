import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum AppMode {
  mock('mock'),
  dev('dev'),
  prod('prod');

  const AppMode(this.value);

  final String value;

  bool get showConfirmationLinks => this != AppMode.prod;

  static AppMode fromEnvironment(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    return switch (normalized) {
      'mock' => AppMode.mock,
      'dev' => AppMode.dev,
      'prod' => AppMode.prod,
      // Debug builds default to mock so the app renders without a backend.
      _ => kReleaseMode ? AppMode.prod : AppMode.mock,
    };
  }
}

@immutable
class AppRuntimeConfig {
  final String apiBaseUrl;
  final String preferredLocale;
  final AppMode mode;

  const AppRuntimeConfig({
    required this.apiBaseUrl,
    required this.preferredLocale,
    required this.mode,
  });

  bool get showConfirmationLinks => mode.showConfirmationLinks;
}

final appRuntimeConfigProvider = Provider<AppRuntimeConfig>((ref) {
  final configuredBaseUrl = const String.fromEnvironment(
    'HANKO_APP_API_BASE_URL',
  ).trim();
  final configuredProdBaseUrl = const String.fromEnvironment(
    'HANKO_APP_PROD_API_BASE_URL',
  ).trim();
  final configuredLocale = const String.fromEnvironment(
    'HANKO_APP_LOCALE',
  ).trim().toLowerCase();
  final configuredMode = const String.fromEnvironment('HANKO_APP_MODE');

  final locale = configuredLocale.isNotEmpty
      ? configuredLocale
      : WidgetsBinding.instance.platformDispatcher.locale.languageCode
            .toLowerCase();

  final mode = AppMode.fromEnvironment(configuredMode);
  final apiBaseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : defaultApiBaseUrl(
          useProdBackend: kReleaseMode || mode == AppMode.prod,
          targetPlatform: defaultTargetPlatform,
          prodApiBaseUrl: configuredProdBaseUrl,
        );

  return AppRuntimeConfig(
    apiBaseUrl: apiBaseUrl,
    preferredLocale: locale,
    mode: mode,
  );
});

@visibleForTesting
String defaultApiBaseUrl({
  required bool useProdBackend,
  required TargetPlatform targetPlatform,
  String? prodApiBaseUrl,
}) {
  if (useProdBackend) {
    final configuredProdApiBaseUrl = prodApiBaseUrl?.trim();
    if (configuredProdApiBaseUrl != null &&
        configuredProdApiBaseUrl.isNotEmpty) {
      return configuredProdApiBaseUrl;
    }
    return 'https://hanko-field-api-26orkkye6a-an.a.run.app';
  }

  if (targetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3050';
  }
  // iOS simulator and desktop dev should use IPv4 loopback so we do not
  // depend on localhost resolving to IPv6 ::1.
  return 'http://127.0.0.1:3050';
}
