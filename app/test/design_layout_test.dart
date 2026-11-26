import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/app/localization/app_localization.dart';
import 'package:hankofield/app/theme/app_theme.dart';
import 'package:hankofield/features/common/common.dart';
import 'package:hankofield/features/design/design.dart';

const _widths = [320.0, 390.0, 432.0];
const _textScales = [1.0, 1.3, 1.6];
const _locales = [Locale('en'), Locale('ja')];

/// Height a tab page really gets on a 390x844 phone: the viewport minus the
/// status bar (59), the home indicator (34) and the tab bar (about 76). The
/// probes below render the page from y=0 without that chrome.
const _tabPageHeight = 844.0 - 59 - 34 - 76;

void main() {
  testWidgets('COM-003 design home lays out without overflow or overlap', (
    tester,
  ) async {
    for (final locale in _locales) {
      for (final width in _widths) {
        for (final textScale in _textScales) {
          final reason = '$locale width=$width textScale=$textScale';
          await _withFlutterErrorCapture(tester, reason, () async {
            await _pumpLayoutProbe(
              tester,
              locale: locale,
              viewport: Size(width, 844),
              textScale: textScale,
              child: DesignHomeScreen(
                onOpenSettings: () {},
                onStartDesign: () {},
                onOpenMySeals: () {},
                onOpenStones: () {},
              ),
            );

            // Photos are cropped, so measure the clip around each one.
            final images = _clippedImageRects(tester);
            final texts = _rects(tester, find.byType(Text));
            final chevrons = _rects(tester, find.byIcon(Icons.chevron_right));
            expect(images, hasLength(3), reason: reason);
            expect(chevrons, hasLength(2), reason: reason);
            for (final text in texts) {
              for (final other in [...images, ...chevrons]) {
                expect(
                  _overlaps(text, other),
                  isFalse,
                  reason: '$reason: text $text overlaps $other',
                );
              }
            }

            final settings = tester.getSize(find.byType(IconButton));
            expect(settings.width, greaterThanOrEqualTo(44), reason: reason);
            expect(settings.height, greaterThanOrEqualTo(44), reason: reason);
          });
        }
      }
    }
  });

  testWidgets('COM-002 onboarding headline stays clear of the copy below it', (
    tester,
  ) async {
    for (final locale in _locales) {
      for (final width in _widths) {
        for (final textScale in _textScales) {
          final reason = '$locale width=$width textScale=$textScale';
          await _withFlutterErrorCapture(tester, reason, () async {
            await _pumpLayoutProbe(
              tester,
              locale: locale,
              viewport: Size(width, 844),
              textScale: textScale,
              child: OnboardingScreen(onComplete: () async {}),
            );

            final l10n = lookupGeneratedHankoLocalizations(locale);
            final title = tester.getRect(find.text(l10n.onboardingHeroTitle));
            final tagline = tester.getRect(find.text(l10n.onboardingTagline));
            // The headline keeps its two authored lines inside the copy
            // column, and the tagline starts below it.
            expect(title.width, lessThanOrEqualTo(265.5), reason: reason);
            expect(
              title.bottom,
              lessThanOrEqualTo(tagline.top),
              reason: '$reason: headline $title overlaps tagline $tagline',
            );
          });
        }
      }
    }
  });

  test('COM-003 feature card copy joins every authored line break', () {
    expect(
      joinAuthoredLineBreaks('View and manage\nyour seals.'),
      'View and manage your seals.',
    );
    expect(joinAuthoredLineBreaks('one \n two\nthree'), 'one two three');
    expect(
      joinAuthoredLineBreaks('保存した印影を\n確認・管理\nできます。'),
      '保存した印影を確認・管理できます。',
    );
    expect(joinAuthoredLineBreaks('AIで\n作成'), 'AIで作成');
    expect(joinAuthoredLineBreaks('No breaks here.'), 'No breaks here.');
  });

  testWidgets('DES-008 shows every candidate on the first screen', (
    tester,
  ) async {
    for (final locale in _locales) {
      await _pumpLayoutProbe(
        tester,
        locale: locale,
        viewport: const Size(390, 844),
        textScale: 1,
        child: SealVariantSelectionScreen(
          result: _sealGenerationResult(),
          onSelected: (_) {},
          onBack: () {},
          onRegenerate: () {},
        ),
      );

      final optionTitle = locale.languageCode == 'ja' ? '候補 ' : 'Option ';
      final chooseLabel = locale.languageCode == 'ja' ? '選ぶ' : 'Choose';
      for (var number = 1; number <= 3; number++) {
        final title = find.text('$optionTitle$number');
        expect(title, findsOneWidget, reason: '$locale');
        expect(tester.getRect(title).bottom, lessThan(_tabPageHeight));
      }
      final chooseButtons = find.text(chooseLabel);
      expect(chooseButtons, findsNWidgets(3), reason: '$locale');
      for (final rect in _rects(tester, chooseButtons)) {
        expect(rect.bottom, lessThan(_tabPageHeight), reason: '$locale');
      }
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        final size = tester.getSize(find.byWidget(button));
        expect(size.height, greaterThanOrEqualTo(44));
      }

      expect(find.textContaining('seal_variant_'), findsNothing);
      expect(tester.takeException(), isNull);
    }

    expect(find.text('上品 / 明朝体'), findsOneWidget);
    expect(find.text('やわらかい / やわらかなゴシック体 / 余白多め'), findsOneWidget);
    expect(find.text('力強い / 筆文字 / 密度高め'), findsOneWidget);
    expect(find.text('Elegant Balanced Formal Serif'), findsNothing);
  });

  testWidgets('DES-008 falls back to the API label without a recipe', (
    tester,
  ) async {
    await _pumpLayoutProbe(
      tester,
      locale: const Locale('en'),
      viewport: const Size(390, 844),
      textScale: 1,
      child: SealVariantSelectionScreen(
        result: _sealGenerationResult(withRecipes: false),
        onSelected: (_) {},
        onBack: () {},
      ),
    );

    expect(find.text('Elegant Balanced Formal Serif'), findsOneWidget);
    expect(find.text('Soft Airy Soft Sans'), findsOneWidget);
    expect(find.text('Bold Dense Bold Brush'), findsOneWidget);
    expect(find.textContaining('seal_variant_'), findsNothing);
  });

  testWidgets('DES-008 selects a candidate from the card or its button', (
    tester,
  ) async {
    final selected = <String>[];

    await _pumpLayoutProbe(
      tester,
      locale: const Locale('en'),
      viewport: const Size(390, 844),
      textScale: 1,
      child: SealVariantSelectionScreen(
        result: _sealGenerationResult(),
        onSelected: (variant) => selected.add(variant.id),
        onBack: () {},
      ),
    );

    await tester.tap(find.text('Option 1'));
    await tester.pumpAndSettle();
    expect(selected, ['seal_variant_001']);
    expect(find.text('Selected'), findsOneWidget);

    final secondCard = find
        .ancestor(of: find.text('Option 2'), matching: find.byType(InkWell))
        .first;
    await tester.tap(
      find.descendant(of: secondCard, matching: find.text('Choose')),
    );
    await tester.pumpAndSettle();
    expect(selected, ['seal_variant_001', 'seal_variant_002']);
    expect(find.text('Selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DES-008 candidates lay out without overflow', (tester) async {
    for (final locale in _locales) {
      for (final width in _widths) {
        for (final textScale in _textScales) {
          final reason = '$locale width=$width textScale=$textScale';
          await _withFlutterErrorCapture(tester, reason, () async {
            await _pumpLayoutProbe(
              tester,
              locale: locale,
              viewport: Size(width, 844),
              textScale: textScale,
              child: SealVariantSelectionScreen(
                result: _sealGenerationResult(),
                onSelected: (_) {},
                onBack: () {},
                onRegenerate: () {},
              ),
            );

            final optionTitle = locale.languageCode == 'ja' ? '候補 ' : 'Option ';
            for (var number = 1; number <= 3; number++) {
              expect(
                find.text('$optionTitle$number'),
                findsOneWidget,
                reason: reason,
              );
            }
          });
        }
      }
    }
  });
}

Future<void> _pumpLayoutProbe(
  WidgetTester tester, {
  required Locale locale,
  required Size viewport,
  required double textScale,
  required Widget child,
}) async {
  tester.view.physicalSize = viewport;
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
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _withFlutterErrorCapture(
  WidgetTester tester,
  String reason,
  Future<void> Function() run,
) async {
  final previousOnError = FlutterError.onError;
  final details = <FlutterErrorDetails>[];
  FlutterError.onError = details.add;
  addTearDown(() => FlutterError.onError = previousOnError);

  try {
    await run();
  } finally {
    FlutterError.onError = previousOnError;
  }

  expect(
    details,
    isEmpty,
    reason:
        '$reason\n${details.map((detail) => detail.exceptionAsString()).join('\n')}',
  );
  expect(tester.takeException(), isNull, reason: reason);
}

List<Rect> _rects(WidgetTester tester, Finder finder) {
  return [
    for (final element in finder.evaluate())
      if (element.renderObject case final RenderBox box) _globalRect(box),
  ];
}

List<Rect> _clippedImageRects(WidgetTester tester) {
  final rects = <Rect>[];
  for (final image in find.byType(Image).evaluate()) {
    image.visitAncestorElements((ancestor) {
      if (ancestor.widget is! ClipRect) {
        return true;
      }
      final box = ancestor.renderObject! as RenderBox;
      rects.add(_globalRect(box));
      return false;
    });
  }
  return rects;
}

/// Global bounds of [box], including any scaling applied by its ancestors.
Rect _globalRect(RenderBox box) {
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

bool _overlaps(Rect a, Rect b) {
  final intersection = a.intersect(b);
  return intersection.width > 0.5 && intersection.height > 0.5;
}

SealGenerationResult _sealGenerationResult({bool withRecipes = true}) {
  SealDesignVariant variant(int number, String label, SealDesignRecipe recipe) {
    final id = 'seal_variant_00$number';
    return SealDesignVariant(
      id: id,
      storagePath: 'seal_designs/seal_request_001/$id.png',
      downloadUrl: '',
      label: label,
      width: 1024,
      height: 1024,
      recipe: withRecipes ? recipe : null,
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
