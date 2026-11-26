import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/app/localization/app_localization.dart';
import 'package:hankofield/app/theme/app_theme.dart';
import 'package:hankofield/features/common/common.dart';
import 'package:hankofield/features/design/design.dart';
import 'package:hankofield/features/stones/stones.dart';

/// Layout checks that depend on how wide real text is.
///
/// The default test font draws every glyph as a full em square, roughly twice
/// as wide as the app's fonts, so it cannot tell whether a list really fits on
/// the first screen. This file loads the bundled fonts instead. It is kept
/// separate because loaded fonts stay registered for every test in a file.
const _phone = Size(390, 844);

/// Height a tab page gets on that phone: the viewport minus the status bar
/// (59), the home indicator (34) and the tab bar (about 76). The pages below
/// are pumped from y=0 without that chrome.
const _tabPageHeight = 844.0 - 59 - 34 - 76;

void main() {
  setUpAll(() async {
    for (final (family, path) in const [
      ('Manrope', 'assets/fonts/Manrope.ttf'),
      ('Noto Serif', 'assets/fonts/NotoSerif.ttf'),
      ('Noto Serif JP', 'assets/fonts/NotoSerifJP.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('STN-001 shows three stones on the first screen', (tester) async {
    for (final locale in const [Locale('en'), Locale('ja')]) {
      final japanese = locale.languageCode == 'ja';
      await _pumpPage(
        tester,
        locale: locale,
        child: StonesHomeScreen(
          result: StoneListingsResult(
            locale: locale.languageCode,
            currency: 'JPY',
            listings: [
              _stone(
                id: 'stone_001',
                title: japanese
                    ? '淡紅ローズクォーツの印材'
                    : 'Soft Pink Rose Quartz Seal Stone',
                materialLabel: japanese ? 'ローズクォーツ' : 'Rose Quartz',
                colorFamily: 'pink',
                patternPrimary: 'plain',
              ),
              _stone(
                id: 'stone_002',
                title: japanese
                    ? '深緑ネフライト翡翠の印材'
                    : 'Deep Green Nephrite Jade Seal Stone',
                materialLabel: japanese ? '翡翠' : 'Jade',
                colorFamily: 'green',
                patternPrimary: 'mottled',
              ),
              _stone(
                id: 'stone_003',
                title: japanese ? 'ラピスラズリの印材' : 'Lapis Lazuli Seal Stone',
                materialLabel: japanese ? 'ラピスラズリ' : 'Lapis Lazuli',
                colorFamily: 'blue',
                patternPrimary: 'speckled',
                isOrderable: false,
              ),
              _stone(
                id: 'stone_004',
                title: japanese ? '白大理石の印材' : 'White Marble Seal Stone',
                materialLabel: japanese ? '大理石' : 'Marble',
                colorFamily: 'white',
                patternPrimary: 'veined',
              ),
            ],
          ),
          selectedStoneId: 'stone_002',
          onOpenStoneDetail: (_) {},
          onSelectStone: (_) {},
        ),
      );

      final cards = find.byKey(const Key('stone-card-open'));
      expect(cards, findsNWidgets(4), reason: '$locale');
      final thirdCard = tester.getRect(cards.at(2));
      expect(
        thirdCard.bottom,
        lessThanOrEqualTo(_tabPageHeight),
        reason: '$locale: third card $thirdCard',
      );
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('DES-008 shows three candidates on the first screen', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('ja')]) {
      await _pumpPage(
        tester,
        locale: locale,
        child: SealVariantSelectionScreen(
          result: _sealGenerationResult(),
          onSelected: (_) {},
          onBack: () {},
          onRegenerate: () {},
        ),
      );

      final l10n = lookupGeneratedHankoLocalizations(locale);
      final chooseButtons = find.text(l10n.sealVariantChooseAction);
      expect(chooseButtons, findsNWidgets(3), reason: '$locale');
      for (var index = 0; index < 3; index++) {
        expect(
          tester.getRect(chooseButtons.at(index)).bottom,
          lessThan(_tabPageHeight),
          reason: '$locale: candidate ${index + 1}',
        );
      }
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('COM-002 onboarding headline keeps two lines above the tagline', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('ja')]) {
      await _pumpPage(
        tester,
        locale: locale,
        child: OnboardingScreen(onComplete: () async {}),
      );

      final l10n = lookupGeneratedHankoLocalizations(locale);
      final headline = find.text(l10n.onboardingHeroTitle);
      // Laid-out height over the style's line height gives the line count.
      final style = tester.widget<Text>(headline).style!;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: headline, matching: find.byType(RichText)),
      );
      final lineCount =
          (paragraph.size.height / (style.fontSize! * style.height!)).round();
      expect(lineCount, 2, reason: '$locale');
      expect(
        tester.getRect(headline).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.text(l10n.onboardingTagline)).top,
        ),
        reason: '$locale',
      );
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Locale locale,
  required Widget child,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: GeneratedHankoLocalizations.supportedLocales,
      localizationsDelegates:
          GeneratedHankoLocalizations.localizationsDelegates,
      theme: HankoTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

StoneListing _stone({
  required String id,
  required String title,
  required String materialLabel,
  required String colorFamily,
  required String patternPrimary,
  bool? isOrderable,
}) {
  return StoneListing(
    id: id,
    code: id.toUpperCase(),
    materialKey: materialLabel.toLowerCase().replaceAll(' ', '_'),
    materialLabel: materialLabel,
    sizeLabel: '24x24x60 mm',
    title: title,
    description: 'A one-of-a-kind seal stone.',
    story: 'Selected for its calm colour.',
    facets: StoneListingFacets(
      colorFamily: colorFamily,
      colorTags: [colorFamily],
      patternPrimary: patternPrimary,
      patternTags: [patternPrimary],
      stoneShape: 'square',
      translucency: 'semi_translucent',
    ),
    price: const Money(amount: 128000, currency: 'JPY'),
    status: isOrderable == false ? 'sold' : 'published',
    isActive: true,
    isOrderable: isOrderable,
    photos: const [],
  );
}

SealGenerationResult _sealGenerationResult() {
  SealDesignVariant variant(int number, String label, SealDesignRecipe recipe) {
    final id = 'seal_variant_00$number';
    return SealDesignVariant(
      id: id,
      storagePath: 'seal_designs/seal_request_001/$id.png',
      downloadUrl: '',
      label: label,
      width: 1024,
      height: 1024,
      recipe: recipe,
    );
  }

  return SealGenerationResult(
    request: const SealGenerationRequest(
      inputName: 'Michael Smith',
      candidate: KanjiCandidate(
        kanji: '美空',
        reading: 'Misora',
        meaning: 'Beautiful sky',
        reason: 'A graceful two-character option.',
      ),
      style: SealStyleSelection(),
    ),
    requestId: 'seal_request_001',
    variants: [
      variant(
        1,
        'Elegant Balanced Formal Serif',
        const SealDesignRecipe(
          fontProfile: 'formal_serif',
          impression: 'elegant',
          weight: 'standard',
          spacing: 'balanced',
          texture: 'none',
          frame: 'square_standard',
        ),
      ),
      variant(
        2,
        'Soft Airy Soft Sans',
        const SealDesignRecipe(
          fontProfile: 'soft_sans',
          impression: 'soft',
          weight: 'standard',
          spacing: 'airy',
          texture: 'subtle_ink',
          frame: 'square_standard',
        ),
      ),
      variant(
        3,
        'Bold Dense Bold Brush',
        const SealDesignRecipe(
          fontProfile: 'bold_brush',
          impression: 'bold',
          weight: 'bold',
          spacing: 'dense',
          texture: 'soft_bleed',
          frame: 'square_standard',
        ),
      ),
    ],
  );
}
