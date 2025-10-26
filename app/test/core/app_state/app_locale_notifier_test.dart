import 'dart:ui';

import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
    );
  }

  test('setLocale persists override and updates provider', () async {
    final container = createContainer();
    addTearDown(container.dispose);

    await container.read(appLocaleProvider.future);
    final notifier = container.read(appLocaleProvider.notifier);

    await notifier.setLocale(const Locale('ja'));
    final state = container.read(appLocaleProvider).asData!.value;

    expect(state.locale.languageCode, 'ja');
    expect(state.source, AppLocaleSource.user);
    expect(prefs.getString('app.locale.override'), 'ja');
  });

  test(
    'useSystemLocale resets override and tracks system locale changes',
    () async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(appLocaleProvider.future);
      final notifier = container.read(appLocaleProvider.notifier);
      await notifier.setLocale(const Locale('ja'));
      await notifier.useSystemLocale();

      var state = container.read(appLocaleProvider).asData!.value;
      expect(state.source, AppLocaleSource.system);
      expect(prefs.getString('app.locale.override'), isNull);

      await notifier.handleSystemLocaleChanged(const Locale('fr'));
      state = container.read(appLocaleProvider).asData!.value;
      expect(state.locale.languageCode, 'fr');
      expect(state.systemLocale.languageCode, 'fr');
    },
  );
}
