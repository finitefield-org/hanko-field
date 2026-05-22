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
    KanjiCandidatesGenerator? generateKanjiCandidates,
    SealDesignsGenerator? generateSealDesigns,
    LocalSealDesignRepository? localSealDesignRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: HankoApp(
          locale: locale,
          hasSeenOnboardingResolver: () async => hasSeenOnboarding,
          markOnboardingSeen: () async {},
          splashMinimumDuration: Duration.zero,
          generateKanjiCandidates:
              generateKanjiCandidates ?? _successfulKanjiGenerator,
          generateSealDesigns:
              generateSealDesigns ?? generateSealDesignsWithDefaultApi,
          localSealDesignRepository: localSealDesignRepository,
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
    expect(find.byType(Navigator, skipOffstage: false), findsNWidgets(5));

    await tester.tap(find.text('Stones').last);
    await tester.pumpAndSettle();

    expect(find.text('Stones'), findsNWidgets(2));

    await tester.tap(find.text('My Seals').last);
    await tester.pumpAndSettle();

    expect(find.text('My Seals'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-004 calls kanji API and displays candidates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiCall = Completer<KanjiCandidatesResult>();
    final sealCall = Completer<SealGenerationResult>();
    KanjiCandidatesRequest? capturedRequest;
    SealGenerationRequest? capturedSealRequest;

    await pumpLaunchedApp(
      tester,
      generateKanjiCandidates: (request) {
        capturedRequest = request;
        return apiCall.future;
      },
      generateSealDesigns: (request) {
        capturedSealRequest = request;
        return sealCall.future;
      },
    );

    await tester.tap(find.text('Start Designing'));
    await tester.pumpAndSettle();

    expect(find.byType(NameInputScreen), findsOneWidget);
    expect(find.text('Enter Your Name'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Gender preference'), findsOneWidget);
    expect(find.text('Kanji style'), findsOneWidget);

    final submitButton = find.widgetWithText(TextButton, 'Suggest Kanji');
    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(find.text('Suggest Kanji'));
    await tester.pump();
    await tester.tap(find.text('Suggest Kanji'));
    await tester.pump();

    expect(find.text('Enter your name to continue.'), findsOneWidget);
    expect(
      find.text('Please enter a valid first name or short name.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).first, 'Michael Smith');
    await tester.pump();

    expect(tester.widget<TextButton>(submitButton).onPressed, isNotNull);

    await tester.ensureVisible(find.text('Suggest Kanji'));
    await tester.pump();
    await tester.tap(find.text('Suggest Kanji'));
    await tester.pump();

    expect(find.byType(KanjiSuggestionLoadingScreen), findsOneWidget);
    expect(find.text('Finding Kanji'), findsOneWidget);
    expect(
      find.text('Creating engraving-friendly kanji suggestions...'),
      findsOneWidget,
    );
    expect(find.text('Michael Smith'), findsWidgets);
    expect(find.text('Japanese style'), findsWidgets);
    expect(capturedRequest?.realName, 'Michael Smith');
    expect(capturedRequest?.reasonLanguage, 'en');
    expect(capturedRequest?.kanjiStyle, KanjiNameStyle.japanese);

    apiCall.complete(_kanjiResult(capturedRequest!));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(KanjiSuggestionsScreen), findsOneWidget);
    expect(find.text('Kanji Suggestions'), findsOneWidget);
    expect(find.text('美空'), findsOneWidget);
    expect(find.text('Misora'), findsOneWidget);
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('Elegant'), findsOneWidget);
    expect(find.text('Gentle'), findsOneWidget);
    expect(find.text('A graceful two-character option.'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Stroke complexity'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Engraving suitability'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);

    await tester.tap(find.text('美空'));
    await tester.pumpAndSettle();

    expect(find.byType(KanjiCandidateDetailScreen), findsOneWidget);
    expect(find.text('Kanji Detail'), findsOneWidget);
    expect(
      find.text(
        'Review the meaning and engraving fit before choosing this kanji.',
      ),
      findsOneWidget,
    );
    expect(find.text('美空'), findsOneWidget);
    expect(find.text('Misora'), findsOneWidget);
    expect(find.text('Beautiful sky'), findsOneWidget);

    await tester.ensureVisible(find.text('Select Kanji'));
    await tester.pump();
    await tester.tap(find.text('Select Kanji'));
    await tester.pumpAndSettle();

    expect(find.byType(SealStyleSelectionScreen), findsOneWidget);
    expect(find.text('Seal Style'), findsOneWidget);
    expect(
      find.text('Choose a fixed style set for AI seal generation.'),
      findsOneWidget,
    );
    expect(find.text('Selected kanji'), findsOneWidget);
    expect(find.text('Shape'), findsWidgets);
    expect(find.text('Square'), findsWidgets);
    expect(find.text('Round'), findsOneWidget);
    expect(find.text('Style'), findsWidgets);
    expect(find.text('Traditional'), findsOneWidget);
    expect(find.text('Elegant'), findsWidgets);
    expect(find.text('Soft'), findsOneWidget);
    expect(find.text('Stroke Weight'), findsWidgets);
    expect(find.text('Standard'), findsWidgets);
    expect(find.text('Balance'), findsWidgets);
    expect(find.text('Balanced'), findsWidgets);

    await tester.tap(find.text('Round'));
    await tester.pump();
    await tester.tap(find.text('Traditional'));
    await tester.pump();
    await tester.ensureVisible(find.text('Airy'));
    await tester.pump();
    await tester.tap(find.text('Airy'));
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm Style'));
    await tester.pump();
    await tester.tap(find.text('Confirm Style'));
    await tester.pumpAndSettle();

    expect(find.text('Style selected'), findsOneWidget);
    expect(
      find.text('These style choices are ready for AI seal generation.'),
      findsOneWidget,
    );
    expect(find.text('Generate Seal'), findsOneWidget);

    await tester.ensureVisible(find.text('Generate Seal'));
    await tester.pump();
    await tester.tap(find.text('Generate Seal'));
    await tester.pump();

    expect(find.byType(SealGenerationLoadingScreen), findsOneWidget);
    expect(capturedSealRequest?.inputName, 'Michael Smith');
    expect(capturedSealRequest?.candidate.kanji, '美空');
    expect(capturedSealRequest?.style.shape, SealShape.round);
    expect(capturedSealRequest?.style.style, SealStyleName.traditional);
    expect(capturedSealRequest?.style.balance, SealBalance.airy);

    sealCall.complete(_sealGenerationResult(request: capturedSealRequest!));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SealVariantSelectionScreen), findsOneWidget);
    expect(find.text('Seal Options'), findsOneWidget);
    expect(find.text('Elegant and balanced'), findsOneWidget);
    expect(find.text('Soft spacing'), findsOneWidget);
    expect(find.text('Bold readable seal'), findsOneWidget);

    await tester.ensureVisible(find.text('Soft spacing'));
    await tester.pump();
    await tester.tap(find.text('Soft spacing'));
    await tester.pumpAndSettle();

    expect(find.byType(SealPreviewDetailScreen), findsOneWidget);
    expect(find.text('Seal Preview'), findsOneWidget);
    expect(
      find.text('Review your selected seal design before saving.'),
      findsOneWidget,
    );
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('AI Variant'), findsOneWidget);
    expect(find.text('Soft spacing'), findsOneWidget);
    expect(find.text('Save Seal'), findsOneWidget);
    expect(find.text('Choose a Stone'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Seal'));
    await tester.pump();
    await tester.tap(find.text('Save Seal'));
    await tester.pumpAndSettle();

    expect(find.byType(SealSaveConfirmationScreen), findsOneWidget);
    expect(find.text('Seal Saved'), findsOneWidget);
    expect(find.text('Seal saved to My Seals'), findsOneWidget);
    expect(find.text('Go to My Seals'), findsOneWidget);
    expect(find.text('Create Another Seal'), findsOneWidget);

    await tester.ensureVisible(find.text('Choose a Stone'));
    await tester.pump();
    await tester.tap(find.text('Choose a Stone'));
    await tester.pumpAndSettle();

    expect(find.text('No stones loaded'), findsOneWidget);

    await tester.tap(find.text('Design').last);
    await tester.pumpAndSettle();

    expect(find.byType(SealSaveConfirmationScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Go to My Seals'));
    await tester.pump();
    await tester.tap(find.text('Go to My Seals'));
    await tester.pumpAndSettle();

    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('美空'), findsWidgets);
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);

    await tester.tap(find.text('Design').last);
    await tester.pumpAndSettle();

    expect(find.byType(SealSaveConfirmationScreen), findsOneWidget);

    await tester.ensureVisible(find.text('Create Another Seal'));
    await tester.pump();
    await tester.tap(find.text('Create Another Seal'));
    await tester.pumpAndSettle();

    expect(find.byType(DesignHomeScreen), findsOneWidget);
    expect(find.text('Start Designing'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-007 shows seal generation progress details', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final generation = Completer<SealGenerationResult>();
    var started = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealGenerationLoadingScreen(
          request: _sealGenerationRequest(),
          generateSealDesigns: (request) {
            started = true;
            expect(request.attemptNumber, 1);
            return generation.future;
          },
          onGenerated: (_) {},
          onError: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    expect(started, isTrue);
    expect(find.text('Generating Seal'), findsOneWidget);
    expect(
      find.text('Creating three AI seal design directions...'),
      findsOneWidget,
    );
    expect(find.text('Generation details'), findsOneWidget);
    expect(find.text('美空'), findsOneWidget);
    expect(find.text('Attempts'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    generation.complete(_sealGenerationResult());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-008 lets the user select one generated seal variant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SealDesignVariant? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealVariantSelectionScreen(
          result: _sealGenerationResult(),
          onSelected: (variant) => selected = variant,
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Seal Options'), findsOneWidget);
    expect(find.text('Choose one AI seal design.'), findsOneWidget);
    expect(find.text('Elegant and balanced'), findsOneWidget);
    expect(find.text('Soft spacing'), findsOneWidget);
    expect(find.text('Bold readable seal'), findsOneWidget);
    expect(find.text('Selected'), findsNothing);

    await tester.ensureVisible(find.text('Soft spacing'));
    await tester.pump();
    await tester.tap(find.text('Soft spacing'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'seal_variant_002');
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Seal design selected'), findsOneWidget);
    expect(
      find.text('This AI seal design is ready for preview and saving.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-009 previews selected seal and exposes next actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var saveCount = 0;
    var chooseStoneCount = 0;
    final result = _sealGenerationResult();
    final variant = result.variants[1];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealPreviewDetailScreen(
          result: result,
          variant: variant,
          onSave: () => saveCount += 1,
          onChooseStone: () => chooseStoneCount += 1,
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Seal Preview'), findsOneWidget);
    expect(
      find.text('Review your selected seal design before saving.'),
      findsOneWidget,
    );
    expect(
      find.text('Created within engraving-friendly design rules.'),
      findsOneWidget,
    );
    expect(find.text('美空'), findsOneWidget);
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('AI Variant'), findsOneWidget);
    expect(find.text('Soft spacing'), findsOneWidget);
    expect(
      find.text('seal_designs/seal_request_001/seal_variant_002.png'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Save Seal'));
    await tester.pump();
    await tester.tap(find.text('Save Seal'));
    await tester.pump();
    await tester.ensureVisible(find.text('Choose a Stone'));
    await tester.pump();
    await tester.tap(find.text('Choose a Stone'));
    await tester.pump();

    expect(saveCount, 1);
    expect(chooseStoneCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-010 lets the user choose the next saved seal action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openMySealsCount = 0;
    var chooseStoneCount = 0;
    var createAnotherCount = 0;
    var backCount = 0;
    final result = _sealGenerationResult();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealSaveConfirmationScreen(
          result: result,
          variant: result.variants[1],
          onOpenMySeals: () => openMySealsCount += 1,
          onChooseStone: () => chooseStoneCount += 1,
          onCreateAnother: () => createAnotherCount += 1,
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text('Seal Saved'), findsOneWidget);
    expect(find.text('Seal saved to My Seals'), findsOneWidget);
    expect(
      find.text(
        'Your custom seal design is ready for comparison and ordering.',
      ),
      findsOneWidget,
    );
    expect(find.text('美空'), findsOneWidget);
    expect(find.text('Soft spacing'), findsOneWidget);
    expect(find.text('Choose a Stone'), findsOneWidget);
    expect(find.text('Go to My Seals'), findsOneWidget);
    expect(find.text('Create Another Seal'), findsOneWidget);

    await tester.ensureVisible(find.text('Choose a Stone'));
    await tester.pump();
    await tester.tap(find.text('Choose a Stone'));
    await tester.pump();
    await tester.ensureVisible(find.text('Go to My Seals'));
    await tester.pump();
    await tester.tap(find.text('Go to My Seals'));
    await tester.pump();
    await tester.ensureVisible(find.text('Create Another Seal'));
    await tester.pump();
    await tester.tap(find.text('Create Another Seal'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(chooseStoneCount, 1);
    expect(openMySealsCount, 1);
    expect(createAnotherCount, 1);
    expect(backCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MYS-001 displays saved seal cards', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    LocalSealDesign? opened;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: MySealsHomeScreen(
          designs: [
            _localSealDesign(),
            _localSealDesign(
              id: 'local_seal_002',
              selectedKanji: '永愛',
              meaning: 'Eternal love',
              style: 'soft',
              isFavorite: true,
            ),
          ],
          onChooseSeal: (design) => opened = design,
        ),
      ),
    );

    expect(find.text('My Seals'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('美空'), findsWidgets);
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('永愛'), findsWidgets);
    expect(find.text('Eternal love'), findsOneWidget);
    expect(find.text('Elegant'), findsOneWidget);
    expect(find.text('Soft'), findsOneWidget);
    expect(find.text('Standard'), findsWidgets);
    expect(find.text('Balanced'), findsWidgets);

    await tester.ensureVisible(find.text('View Details').first);
    await tester.pump();
    await tester.tap(find.text('View Details').first);
    await tester.pump();

    expect(opened?.id, 'local_seal_001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('MYS-002 shows empty saved seal actions', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var startDesignCount = 0;
    var exploreStonesCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: MySealsHomeScreen(
          onStartDesigning: () => startDesignCount += 1,
          onExploreStones: () => exploreStonesCount += 1,
        ),
      ),
    );

    expect(find.text('No saved seals'), findsOneWidget);
    expect(
      find.text('Saved seal designs will appear here after you create one.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start Designing'));
    await tester.pump();
    await tester.tap(find.text('Browse Stones'));
    await tester.pump();

    expect(startDesignCount, 1);
    expect(exploreStonesCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MYS-003 displays saved seal detail fields', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var backCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealDetailScreen(
          design: _localSealDesign(),
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text('Seal Detail'), findsOneWidget);
    expect(find.text('Kanji'), findsOneWidget);
    expect(find.text('美空'), findsWidgets);
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Misora'), findsOneWidget);
    expect(find.text('Meaning'), findsOneWidget);
    expect(find.text('Beautiful sky'), findsOneWidget);
    expect(find.text('Shape'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Elegant'), findsOneWidget);
    expect(find.text('Stroke Weight'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('2026-05-21 11:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(backCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MYS-003 opens from the My Seals stack', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLaunchedApp(
      tester,
      localSealDesignRepository: InMemoryLocalSealDesignRepository([
        _localSealDesign(),
      ]),
    );

    await tester.tap(find.text('My Seals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();

    expect(find.byType(SealDetailScreen), findsOneWidget);
    expect(find.text('Seal Detail'), findsOneWidget);
    expect(find.text('2026-05-21 11:00'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(MySealsHomeScreen), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-012 and DES-015 expose retry and limit actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var retryCount = 0;
    var backCount = 0;
    var adjustCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealGenerationErrorScreen(
          request: _sealGenerationRequest(),
          onRetry: () => retryCount += 1,
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text("We couldn't generate seal designs"), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    await tester.ensureVisible(find.text('Try Again'));
    await tester.pump();
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.ensureVisible(find.text('Back'));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(retryCount, 1);
    expect(backCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: SealGenerationLimitScreen(
          request: _sealGenerationRequest(attemptNumber: 3),
          onAdjustStyle: () => adjustCount += 1,
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text('Generation limit reached'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('Adjust Style'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tester.ensureVisible(find.text('Adjust Style'));
    await tester.pump();
    await tester.tap(find.text('Adjust Style'));
    await tester.pump();
    await tester.ensureVisible(find.text('Back'));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(adjustCount, 1);
    expect(backCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-011 and DES-014 expose retry and edit actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const request = KanjiCandidatesRequest(realName: 'Michael Smith');
    var retryCount = 0;
    var backCount = 0;
    var editCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: KanjiSuggestionErrorScreen(
          request: request,
          onRetry: () => retryCount += 1,
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text("We couldn't suggest kanji"), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);

    await tester.ensureVisible(find.text('Try Again'));
    await tester.pump();
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.ensureVisible(find.text('Back'));
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(retryCount, 1);
    expect(backCount, 1);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: UnsupportedKanjiResultScreen(
          request: request,
          onRetry: () => retryCount += 1,
          onEditName: () => editCount += 1,
          onBack: () => backCount += 1,
        ),
      ),
    );

    expect(find.text("We couldn't find a suitable kanji"), findsOneWidget);
    expect(find.text('1-2 characters only'), findsOneWidget);
    expect(find.text('Simple, common kanji'), findsOneWidget);
    expect(find.text('Edit Name'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.ensureVisible(find.text('Edit Name'));
    await tester.pump();
    await tester.tap(find.text('Edit Name'));
    await tester.pump();
    await tester.ensureVisible(find.text('Try Again'));
    await tester.pump();
    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(editCount, 1);
    expect(retryCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('COM-004 opens settings from the design header', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpLaunchedApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('How It Works'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(BottomNavigationShell), findsOneWidget);
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

  testWidgets('COM-004 settings rows navigate to destination screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: HankoLocalizations.supportedLocales,
        localizationsDelegates: HankoLocalizations.localizationsDelegates,
        theme: HankoTheme.light(),
        home: const SettingsHomeScreen(),
      ),
    );

    Future<void> openAndReturn(
      String rowLabel,
      Finder expectedFinder, {
      bool useSystemBack = false,
    }) async {
      await tester.ensureVisible(find.text(rowLabel));
      await tester.pump();
      await tester.tap(find.text(rowLabel));
      await tester.pumpAndSettle();

      expect(expectedFinder, findsOneWidget);

      if (useSystemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    }

    await openAndReturn(
      'Language',
      find.text('App language'),
      useSystemBack: true,
    );
    await openAndReturn('About', find.text('Your seal, made from gemstone'));
    await openAndReturn(
      'How It Works',
      find.text('Choose your name and kanji'),
    );
    await openAndReturn('FAQ', find.text('How is kanji selected?'));
    await openAndReturn(
      'Privacy',
      find.textContaining('https://finitefield.org/en/privacy/'),
    );
    await openAndReturn('Terms', find.text('Orders and contract formation'));
    await openAndReturn(
      'Contact',
      find.textContaining('https://finitefield.org/en/contact/'),
    );
    await openAndReturn('Version', find.text('Version 1.0.4+10'));

    expect(tester.takeException(), isNull);
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
    expect(find.text('使い方'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);

    await tester.tap(find.text('このアプリについて'));
    await tester.pumpAndSettle();

    expect(find.text('宝石でつくる、あなたの印鑑'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}

Future<KanjiCandidatesResult> _successfulKanjiGenerator(
  KanjiCandidatesRequest request,
) async {
  return _kanjiResult(request);
}

LocalSealDesign _localSealDesign({
  String id = 'local_seal_001',
  String selectedKanji = '美空',
  String? meaning = 'Beautiful sky',
  String style = 'elegant',
  bool isFavorite = false,
}) {
  return LocalSealDesign(
    id: id,
    inputName: 'Michael Smith',
    selectedKanji: selectedKanji,
    reading: 'Misora',
    meaning: meaning,
    impression: const ['Elegant', 'Gentle'],
    characterCount: selectedKanji.runes.length,
    strokeComplexity: 'medium',
    engravingSuitability: 'high',
    shape: 'square',
    style: style,
    strokeWeight: 'standard',
    balance: 'balanced',
    aiGenerationId: 'seal_request_001',
    aiVariantId: 'seal_variant_001',
    previewImageStoragePath:
        'seal_designs/seal_request_001/seal_variant_001.png',
    previewImageDownloadUrl: '',
    localImagePath: '',
    isFavorite: isFavorite,
    createdAt: DateTime(2026, 5, 21, 11),
    updatedAt: DateTime(2026, 5, 21, 11, 10),
  );
}

SealGenerationRequest _sealGenerationRequest({int attemptNumber = 1}) {
  return SealGenerationRequest(
    inputName: 'Michael Smith',
    candidate: const KanjiCandidate(
      kanji: '美空',
      reading: 'Misora',
      meaning: 'Beautiful sky',
      reason: 'A graceful two-character option.',
    ),
    style: const SealStyleSelection(),
    attemptNumber: attemptNumber,
  );
}

SealGenerationResult _sealGenerationResult({SealGenerationRequest? request}) {
  return SealGenerationResult(
    request: request ?? _sealGenerationRequest(),
    requestId: 'seal_request_001',
    variants: const [
      SealDesignVariant(
        id: 'seal_variant_001',
        storagePath: 'seal_designs/seal_request_001/seal_variant_001.png',
        downloadUrl: '',
        label: 'Elegant and balanced',
        width: 1024,
        height: 1024,
      ),
      SealDesignVariant(
        id: 'seal_variant_002',
        storagePath: 'seal_designs/seal_request_001/seal_variant_002.png',
        downloadUrl: '',
        label: 'Soft spacing',
        width: 1024,
        height: 1024,
      ),
      SealDesignVariant(
        id: 'seal_variant_003',
        storagePath: 'seal_designs/seal_request_001/seal_variant_003.png',
        downloadUrl: '',
        label: 'Bold readable seal',
        width: 1024,
        height: 1024,
      ),
    ],
  );
}

KanjiCandidatesResult _kanjiResult(KanjiCandidatesRequest request) {
  return KanjiCandidatesResult(
    realName: request.realName,
    reasonLanguage: request.reasonLanguage,
    gender: request.gender,
    kanjiStyle: request.kanjiStyle,
    candidates: const [
      KanjiCandidate(
        kanji: '美空',
        reading: 'Misora',
        meaning: 'Beautiful sky',
        impression: ['Elegant', 'Gentle'],
        reason: 'A graceful two-character option.',
        characterCount: 2,
        strokeComplexity: 'medium',
        engravingSuitability: 'high',
      ),
    ],
  );
}
