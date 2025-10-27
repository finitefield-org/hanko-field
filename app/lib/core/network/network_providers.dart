import 'package:app/core/app/app_flavor.dart';
import 'package:app/core/app/app_version.dart';
import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/network/connectivity_service.dart';
import 'package:app/core/network/interceptors/auth_interceptor.dart';
import 'package:app/core/network/interceptors/connectivity_interceptor.dart';
import 'package:app/core/network/interceptors/http_interceptor.dart';
import 'package:app/core/network/interceptors/logging_interceptor.dart';
import 'package:app/core/network/network_client.dart';
import 'package:app/core/network/network_config.dart';
import 'package:app/core/network/retry_policy.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final networkLoggerProvider = Provider<Logger>((ref) {
  return Logger('network');
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(null);
});

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  final appConfig = ref.watch(appConfigProvider);
  final appVersion = ref.watch(appVersionProvider);
  final localeTag = ref
      .watch(appLocaleProvider)
      .when(
        data: (state) => state.locale.toLanguageTag(),
        loading: () => PlatformDispatcher.instance.locale.toLanguageTag(),
        error: (_, __) => PlatformDispatcher.instance.locale.toLanguageTag(),
      );
  final platform = _platformName();

  return NetworkConfig(
    baseUrl: appConfig.baseUrl,
    userAgent:
        'HankoField/${appConfig.displayName}; v=${appVersion.raw}; $platform',
    localeTag: localeTag,
  );
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  return const RetryPolicy();
});

final networkClientProvider = Provider<NetworkClient>((ref) {
  final client = ref.watch(httpClientProvider);
  final config = ref.watch(networkConfigProvider);
  final logger = ref.watch(networkLoggerProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final tokenStorage = ref.watch(authTokenStorageProvider);
  final retryPolicy = ref.watch(retryPolicyProvider);

  final interceptors = <HttpInterceptor>[
    LoggingInterceptor(logger: logger),
    ConnectivityInterceptor(connectivity),
    AuthInterceptor(tokenStorage),
  ];

  return NetworkClient(
    client: client,
    config: config,
    interceptors: interceptors,
    retryPolicy: retryPolicy,
  );
});

String _platformName() {
  try {
    return defaultTargetPlatform.name;
  } catch (_) {
    return 'unknown';
  }
}
