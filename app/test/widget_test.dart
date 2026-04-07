import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'package:hankofield/app/app.dart';
import 'package:hankofield/app/config/app_runtime_config.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  expect(finder, findsOneWidget);
}

void main() {
  testWidgets('top page renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeConfigProvider.overrideWithValue(
            const AppRuntimeConfig(
              apiBaseUrl: 'http://localhost:3050',
              preferredLocale: 'en',
              mode: AppMode.mock,
            ),
          ),
        ],
        child: const HankoApp(),
      ),
    );
    await tester.pump();

    expect(find.text('A gemstone seal made just for you.'), findsOneWidget);
    expect(find.text('Start designing'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);

    final designLabel = find.text('Start designing');
    expect(designLabel, findsOneWidget);

    await tester.tapAt(tester.getCenter(designLabel));
    await tester.pump(const Duration(seconds: 1));
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });
}
