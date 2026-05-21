import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'package:hankofield/app/app.dart';
import 'package:hankofield/app/localization/app_localization.dart';
import 'package:hankofield/app/theme/app_theme.dart';
import 'package:hankofield/core/widgets/core_widgets.dart';
import 'package:hankofield/features/common/common.dart';
import 'package:hankofield/features/design/design.dart';
import 'package:hankofield/features/my_seals/my_seals.dart';
import 'package:hankofield/features/order/order.dart';
import 'package:hankofield/features/order_lookup/order_lookup.dart';
import 'package:hankofield/features/settings/settings.dart';
import 'package:hankofield/features/stones/stones.dart';

void main() {
  Future<void> pumpLaunchedApp(
    WidgetTester tester, {
    Locale? locale,
    bool hasSeenOnboarding = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          locale: locale,
          hasSeenOnboardingResolver: () async => hasSeenOnboarding,
          markOnboardingSeen: () async {},
          splashMinimumDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
  }

  testWidgets('COM-001 routes returning users to the shell', (tester) async {
    final launchCheck = Completer<bool>();

    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          hasSeenOnboardingResolver: () => launchCheck.future,
          markOnboardingSeen: () async {},
          splashMinimumDuration: Duration.zero,
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Preparing your design experience.'), findsOneWidget);

    launchCheck.complete(true);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(BottomNavigationShell), findsOneWidget);
    expect(find.byType(DesignHomeScreen, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('COM-001 routes first-time users to onboarding', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var savedOnboardingState = false;
    final saveCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          hasSeenOnboardingResolver: () async => false,
          markOnboardingSeen: () {
            savedOnboardingState = true;
            return saveCompleter.future;
          },
          splashMinimumDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Create your\nseal in minutes'), findsOneWidget);
    expect(find.text('Choose kanji from your name'), findsOneWidget);
    expect(find.text('Generate a seal design with AI'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(savedOnboardingState, isTrue);
    expect(find.byType(BottomNavigationShell), findsNothing);

    saveCompleter.complete();
    await tester.pump();

    expect(find.byType(BottomNavigationShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('COM-001 treats launch read failures as first run', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          hasSeenOnboardingResolver: () async => throw StateError('no storage'),
          markOnboardingSeen: () async {},
          splashMinimumDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boots the COM-003 bottom navigation shell', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLaunchedApp(tester);

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DesignHomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MySealsHomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(StonesHomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(HankoSurfaceCard, skipOffstage: false), findsWidgets);
    expect(find.byType(HankoPrimaryButton, skipOffstage: false), findsWidgets);
    expect(find.byType(HankoStateView, skipOffstage: false), findsWidgets);
    expect(find.text('Design'), findsNWidgets(2));
    expect(find.text('Create your\ncustom seal'), findsOneWidget);
    expect(find.text('Start Designing'), findsOneWidget);
    expect(find.text('Saved Seals'), findsOneWidget);
    expect(find.text('Browse Stones'), findsOneWidget);
    expect(find.text('My Seals'), findsOneWidget);
    expect(find.text('Stones'), findsOneWidget);
    expect(find.byType(Navigator, skipOffstage: false), findsNWidgets(4));

    await tester.tap(find.text('Stones').last);
    await tester.pumpAndSettle();

    expect(find.text('Stones'), findsNWidgets(2));

    await tester.tap(find.text('My Seals').last);
    await tester.pumpAndSettle();

    expect(find.text('My Seals'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches major labels with the app locale', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          locale: const Locale('ja'),
          hasSeenOnboardingResolver: () async => true,
          markOnboardingSeen: () async {},
          splashMinimumDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('デザイン'), findsNWidgets(2));
    expect(find.text('あなた専用の\n印影を作成'), findsOneWidget);
    expect(find.text('作成をはじめる'), findsOneWidget);
    expect(find.text('保存済み印影'), findsOneWidget);
    expect(find.text('石を探す'), findsOneWidget);
    expect(find.text('マイ印影'), findsOneWidget);
    expect(find.text('石'), findsOneWidget);
    expect(find.text('Design'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders non-tab feature entry screens independently', (
    tester,
  ) async {
    Future<void> expectEntryScreen(
      Widget screen,
      String title,
      Type expectedCommonWidget,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: HankoLocalizations.supportedLocales,
          localizationsDelegates: HankoLocalizations.localizationsDelegates,
          theme: HankoTheme.light(),
          home: screen,
        ),
      );

      expect(find.text(title), findsOneWidget);
      expect(find.byType(expectedCommonWidget), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    await expectEntryScreen(
      const OrderFlowEntryScreen(),
      'Order',
      HankoStateView,
    );
    await expectEntryScreen(
      const OrderLookupEntryScreen(),
      'Order Lookup',
      HankoTextField,
    );
    expect(find.byType(HankoTextField), findsNWidgets(2));
    await expectEntryScreen(
      const SettingsHomeScreen(),
      'Settings',
      HankoSurfaceCard,
    );
  });

  testWidgets('localizes non-tab feature entry screens', (tester) async {
    Future<void> pumpLocalizedEntry(Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          supportedLocales: HankoLocalizations.supportedLocales,
          localizationsDelegates: HankoLocalizations.localizationsDelegates,
          theme: HankoTheme.light(),
          home: screen,
        ),
      );
    }

    await pumpLocalizedEntry(const OrderLookupEntryScreen());

    expect(find.text('注文照会'), findsOneWidget);
    expect(find.text('注文番号'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('注文を照会'), findsOneWidget);

    await pumpLocalizedEntry(const SettingsHomeScreen());

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('言語'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
