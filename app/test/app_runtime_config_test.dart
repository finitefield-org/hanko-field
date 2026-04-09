import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hankofield/app/config/app_runtime_config.dart';

void main() {
  test('AppMode parses environment values', () {
    expect(AppMode.fromEnvironment('mock'), AppMode.mock);
    expect(AppMode.fromEnvironment(' DEV '), AppMode.dev);
    expect(AppMode.fromEnvironment('prod'), AppMode.prod);
    expect(AppMode.fromEnvironment(''), AppMode.mock);
  });

  test('confirmation links are shown only in mock/dev modes', () {
    expect(
      const AppRuntimeConfig(
        apiBaseUrl: 'http://localhost:3050',
        preferredLocale: 'ja',
        mode: AppMode.mock,
      ).showConfirmationLinks,
      isTrue,
    );
    expect(
      const AppRuntimeConfig(
        apiBaseUrl: 'http://localhost:3050',
        preferredLocale: 'ja',
        mode: AppMode.dev,
      ).showConfirmationLinks,
      isTrue,
    );
    expect(
      const AppRuntimeConfig(
        apiBaseUrl: 'http://localhost:3050',
        preferredLocale: 'ja',
        mode: AppMode.prod,
      ).showConfirmationLinks,
      isFalse,
    );
  });

  test('defaultApiBaseUrl uses the configured prod url in release mode', () {
    expect(
      defaultApiBaseUrl(
        useProdBackend: true,
        targetPlatform: TargetPlatform.android,
        prodApiBaseUrl: 'https://prod.example.com',
      ),
      'https://prod.example.com',
    );
  });

  test(
    'defaultApiBaseUrl uses the release fallback when prod url is absent',
    () {
      expect(
        defaultApiBaseUrl(
          useProdBackend: true,
          targetPlatform: TargetPlatform.android,
        ),
        'https://hanko-field-api-26orkkye6a-an.a.run.app',
      );
    },
  );

  test('defaultApiBaseUrl uses the local emulator on Android debug builds', () {
    expect(
      defaultApiBaseUrl(
        useProdBackend: false,
        targetPlatform: TargetPlatform.android,
      ),
      'http://10.0.2.2:3050',
    );
  });
}
