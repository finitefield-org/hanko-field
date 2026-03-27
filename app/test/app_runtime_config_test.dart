import 'package:flutter_test/flutter_test.dart';
import 'package:hankofield/app/config/app_runtime_config.dart';

void main() {
  test('AppMode parses environment values', () {
    expect(AppMode.fromEnvironment('mock'), AppMode.mock);
    expect(AppMode.fromEnvironment(' DEV '), AppMode.dev);
    expect(AppMode.fromEnvironment('prod'), AppMode.prod);
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
}
