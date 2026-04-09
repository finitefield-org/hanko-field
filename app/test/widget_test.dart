import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'package:hankofield/app/app.dart';
import 'package:hankofield/app/config/app_runtime_config.dart';
import 'package:hankofield/app/localization/app_locale_view_model.dart';
import 'package:hankofield/features/payment/presentation/payment_failure_page.dart';

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

  testWidgets('legal notice page returns to top', (tester) async {
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

    await tester.ensureVisible(find.text('Legal Notice'));
    await tester.tap(find.text('Legal Notice'));
    await tester.pumpAndSettle();

    expect(find.text('Specified Commercial Transactions Act'), findsOneWidget);

    await tester.ensureVisible(find.text('Back to TOP'));
    await tester.tap(find.text('Back to TOP'));
    await tester.pumpAndSettle();

    expect(find.text('A gemstone seal made just for you.'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('terms page returns to top', (tester) async {
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

    await tester.ensureVisible(find.text('Terms of Service'));
    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);

    await tester.ensureVisible(find.text('Back to TOP'));
    await tester.tap(find.text('Back to TOP'));
    await tester.pumpAndSettle();

    expect(find.text('A gemstone seal made just for you.'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('payment failure page back button returns to top', (
    tester,
  ) async {
    var backToTopCalled = false;

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
        child: MaterialApp(
          home: PaymentFailurePage(
            locale: AppLocale.en,
            onSelectLocale: (_) {},
            onBackToTop: () {
              backToTopCalled = true;
            },
            onOpenLegalNotice: () {},
            onOpenTerms: () {},
            orderId: 'ord_123',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Back to TOP'));
    await tester.tap(find.text('Back to TOP'));
    await tester.pumpAndSettle();

    expect(backToTopCalled, isTrue);
  });
}
