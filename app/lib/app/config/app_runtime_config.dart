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
      _ => kReleaseMode ? AppMode.prod : AppMode.dev,
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
  final configuredLocale = const String.fromEnvironment(
    'HANKO_APP_LOCALE',
  ).trim().toLowerCase();
  final configuredMode = const String.fromEnvironment('HANKO_APP_MODE');

  final locale = configuredLocale.isNotEmpty
      ? configuredLocale
      : WidgetsBinding.instance.platformDispatcher.locale.languageCode
            .toLowerCase();

  final apiBaseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : _defaultApiBaseUrl();
  final mode = AppMode.fromEnvironment(configuredMode);

  return AppRuntimeConfig(
    apiBaseUrl: apiBaseUrl,
    preferredLocale: locale,
    mode: mode,
  );
});

String _defaultApiBaseUrl() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3050';
  }
  return 'http://localhost:3050';
}
