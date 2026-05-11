import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hankofield/app/app.dart';
import 'package:hankofield/app/config/app_runtime_config.dart';
import 'package:hankofield/app/localization/app_locale_view_model.dart';
import 'package:hankofield/features/order/data/order_api_repository.dart';
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

Future<void> tapInkWellWithText(WidgetTester tester, String text) async {
  final target = find
      .ancestor(of: find.text(text), matching: find.byType(InkWell))
      .last;
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _PendingCatalogRepository extends OrderApiRepository {
  _PendingCatalogRepository(AppRuntimeConfig runtimeConfig)
    : super(runtimeConfig: runtimeConfig, httpClient: http.Client());

  @override
  Future<PublicConfigData> fetchPublicConfig() {
    return Completer<PublicConfigData>().future;
  }
}

class _FailingCatalogRepository extends OrderApiRepository {
  _FailingCatalogRepository(AppRuntimeConfig runtimeConfig)
    : super(runtimeConfig: runtimeConfig, httpClient: http.Client());

  @override
  Future<PublicConfigData> fetchPublicConfig() async {
    throw Exception('catalog unavailable');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app starts on design page with preview and controls', (
    tester,
  ) async {
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
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    expect(find.text('A gemstone seal made just for you.'), findsOneWidget);
    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    expect(find.text('Font style'), findsOneWidget);
    expect(find.text('Japanese style'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('印'), findsWidgets);
    expect(find.text('Shape'), findsOneWidget);
    expect(find.text('Square seal'), findsOneWidget);
    expect(find.text('Round seal'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('design page saves, reapplies, and continues local seal ideas', (
    tester,
  ) async {
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
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    expect(
      find.text(
        'Saved only on this device. It is not transferred if you delete the app, use another device, or change phones.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(OutlinedButton, 'Save current');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved the seal idea.'), findsOneWidget);
    expect(find.text('A'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'B');
    await tester.pumpAndSettle();

    final editButton = find.widgetWithText(TextButton, 'Edit again');
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    final firstTextField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(firstTextField.controller?.text, 'A');

    final deleteButton = find
        .widgetWithIcon(IconButton, Icons.delete_outline_rounded)
        .first;
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.text('Saved seal ideas will appear here.'),
    );

    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final continueButton = find.widgetWithText(
      OutlinedButton,
      'Continue order',
    );
    await tester.ensureVisible(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Choose listing'), findsOneWidget);
  });

  testWidgets('design page compares selected saved seal ideas', (tester) async {
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
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    final saveButton = find.widgetWithText(OutlinedButton, 'Save current');

    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'B');
    await tester.pumpAndSettle();
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final favoriteButton = find.byTooltip('Add favorite').first;
    await tester.ensureVisible(favoriteButton);
    await tester.pumpAndSettle();
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    final firstCheckbox = find.byType(Checkbox).first;
    await tester.ensureVisible(firstCheckbox);
    await tester.pumpAndSettle();
    await tester.tap(firstCheckbox);
    await tester.pumpAndSettle();

    final secondCheckbox = find.byType(Checkbox).at(1);
    await tester.ensureVisible(secondCheckbox);
    await tester.pumpAndSettle();
    await tester.tap(secondCheckbox);
    await tester.pumpAndSettle();

    final compareButton = find.widgetWithText(FilledButton, 'Compare selected');
    await tester.ensureVisible(compareButton);
    await tester.pumpAndSettle();
    await tester.tap(compareButton);
    await tester.pumpAndSettle();

    expect(find.text('Compare seal ideas'), findsOneWidget);
    expect(find.text('Seal text'), findsOneWidget);
    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Shape'), findsOneWidget);
    expect(find.text('Reading / meaning'), findsOneWidget);
    expect(find.text('Favorite'), findsWidgets);
    expect(find.text('Not favorite'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('legal notice page returns to design', (tester) async {
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

    await tester.ensureVisible(find.text('LEGAL NOTICE'));
    await tester.tap(find.text('LEGAL NOTICE'));
    await tester.pumpAndSettle();

    expect(find.text('Specified Commercial Transactions Act'), findsOneWidget);

    await tapInkWellWithText(tester, 'Back to TOP');

    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('terms page returns to design', (tester) async {
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

    await tester.ensureVisible(find.text('TERMS OF SERVICE'));
    await tester.tap(find.text('TERMS OF SERVICE'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsOneWidget);

    await tapInkWellWithText(tester, 'Back to TOP');

    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('about page shows English service copy', (tester) async {
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

    await tester.ensureVisible(find.text('ABOUT STONE SIGNATURE'));
    await tester.tap(find.text('ABOUT STONE SIGNATURE'));
    await tester.pumpAndSettle();

    expect(find.text('About STONE SIGNATURE'), findsOneWidget);
    expect(find.text('Your seal, made from gemstone'), findsOneWidget);
    expect(
      find.text(
        'Choose a stone, design the seal impression, and place your order',
      ),
      findsOneWidget,
    );
    expect(find.text('Design'), findsOneWidget);
    expect(
      find.text('An easier way to choose a gemstone seal.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('choosing a gemstone seal online'),
      findsOneWidget,
    );
    expect(find.text('Gemstone'), findsOneWidget);
    expect(find.text('Seal design'), findsOneWidget);
    expect(find.text('One of a kind'), findsOneWidget);
    expect(
      find.textContaining('colors and patterns unique to natural stone'),
      findsOneWidget,
    );
    expect(find.textContaining('carved text and the mood'), findsOneWidget);
    expect(
      find.textContaining('Choose the piece you like and order it'),
      findsOneWidget,
    );
    expect(find.image(const AssetImage('assets/top-hero.png')), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);
  });

  testWidgets('about design action returns to the design step', (tester) async {
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
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    await tester.enterText(find.byType(TextField).first, 'Alex');
    await tester.pumpAndSettle();
    final nextButton = find.widgetWithText(FilledButton, 'Next: Listing');
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('Choose listing'), findsOneWidget);

    await tapInkWellWithText(tester, 'ABOUT STONE SIGNATURE');
    await pumpUntilFound(tester, find.text('About STONE SIGNATURE'));
    await tapInkWellWithText(tester, 'Design');

    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.text('Choose listing'), findsNothing);
  });

  testWidgets('about page shows Japanese service copy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeConfigProvider.overrideWithValue(
            const AppRuntimeConfig(
              apiBaseUrl: 'http://localhost:3050',
              preferredLocale: 'ja',
              mode: AppMode.mock,
            ),
          ),
        ],
        child: const HankoApp(),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('STONE SIGNATUREとは'));
    await tester.tap(find.text('STONE SIGNATUREとは'));
    await tester.pumpAndSettle();

    expect(find.text('About STONE SIGNATURE'), findsOneWidget);
    expect(find.text('宝石でつくる、あなたの印鑑'), findsOneWidget);
    expect(find.text('石を選び、印影をデザインして注文できます'), findsOneWidget);
    expect(find.text('デザインする'), findsOneWidget);
    expect(find.text('宝石印鑑を、もっと選びやすく。'), findsOneWidget);
    expect(find.textContaining('宝石を使った印鑑をオンラインで選び'), findsOneWidget);
    expect(find.text('宝石'), findsOneWidget);
    expect(find.text('印影デザイン'), findsOneWidget);
    expect(find.text('一点物'), findsOneWidget);
    expect(find.textContaining('天然石ならではの色や模様'), findsOneWidget);
    expect(find.textContaining('彫る文字や印影の雰囲気'), findsOneWidget);
    expect(find.textContaining('気に入った一本を選んで注文できます'), findsOneWidget);
  });

  testWidgets('design inputs and preview remain visible while catalog loads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    const runtimeConfig = AppRuntimeConfig(
      apiBaseUrl: 'http://localhost:3050',
      preferredLocale: 'en',
      mode: AppMode.prod,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeConfigProvider.overrideWithValue(runtimeConfig),
          orderApiRepositoryProvider.overrideWithValue(
            _PendingCatalogRepository(runtimeConfig),
          ),
        ],
        child: const HankoApp(),
      ),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.text('Name for the seal text'));

    expect(
      find.text(
        'Loading catalog. You can start editing the seal text and preview now.',
      ),
      findsOneWidget,
    );
    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('印'), findsWidgets);
  });

  testWidgets('design inputs and preview remain visible after catalog error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    const runtimeConfig = AppRuntimeConfig(
      apiBaseUrl: 'http://localhost:3050',
      preferredLocale: 'en',
      mode: AppMode.prod,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimeConfigProvider.overrideWithValue(runtimeConfig),
          orderApiRepositoryProvider.overrideWithValue(
            _FailingCatalogRepository(runtimeConfig),
          ),
        ],
        child: const HankoApp(),
      ),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.textContaining('catalog unavailable'));

    expect(find.textContaining('catalog unavailable'), findsOneWidget);
    expect(find.text('Name for the seal text'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('印'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);
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
            onOpenAbout: () {},
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
