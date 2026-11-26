import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hankofield/app/localization/app_localization.dart';
import 'package:hankofield/app/theme/app_theme.dart';
import 'package:hankofield/features/order/order.dart';
import 'package:hankofield/features/order_lookup/order_lookup.dart';
import 'package:hankofield/features/settings/settings.dart';
import 'package:hankofield/features/stones/stones.dart';

void main() {
  testWidgets('M2-T07 settings tolerate RTL and larger text', (tester) async {
    await _withFlutterErrorCapture(tester, () async {
      await _pumpRtlProbe(tester, const SettingsHomeScreen());
      await tester.ensureVisible(find.text('Language'));
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.text('Settings'))),
        TextDirection.rtl,
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });
  });

  testWidgets('M2-T07 checkout input tolerates RTL and larger text', (
    tester,
  ) async {
    await _withFlutterErrorCapture(tester, () async {
      await _pumpRtlProbe(
        tester,
        CheckoutInputScreen(input: _longCheckoutInput()),
      );
      await tester.ensureVisible(find.text('Save Checkout Information'));
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.text('Checkout Information'))),
        TextDirection.rtl,
      );
      expect(find.text('Checkout Information'), findsOneWidget);
      expect(find.text('Save Checkout Information'), findsOneWidget);
    });
  });

  testWidgets('M2-T07 order lookup tolerates RTL and larger text', (
    tester,
  ) async {
    await _withFlutterErrorCapture(tester, () async {
      await _pumpRtlProbe(
        tester,
        const OrderLookupEntryScreen(
          initialOrderNo: 'SS-20260618-00000000000000000001',
          initialEmail: 'customer.with.a.long.name@example.test',
        ),
      );

      expect(
        Directionality.of(tester.element(find.text('Order Lookup'))),
        TextDirection.rtl,
      );
      expect(find.text('Order Lookup'), findsOneWidget);
      expect(find.text('Lookup Order'), findsOneWidget);
    });
  });

  testWidgets('M2-T07 order review tolerates RTL and larger text', (
    tester,
  ) async {
    await _withFlutterErrorCapture(tester, () async {
      await _pumpRtlProbe(
        tester,
        OrderFlowEntryScreen(draft: _longOrderDraft()),
      );
      await tester.ensureVisible(find.text('Continue to Shipping'));
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.text('Order Review'))),
        TextDirection.rtl,
      );
      expect(find.text('Order Review'), findsOneWidget);
      expect(find.text('Continue to Shipping'), findsOneWidget);
    });
  });
  testWidgets('STN-004 sort sheet scrolls to every option in landscape', (
    tester,
  ) async {
    await _withFlutterErrorCapture(tester, () async {
      await _pumpStonesProbe(
        tester,
        locale: const Locale('en'),
        size: const Size(780, 360),
        textScale: 1.3,
      );

      await tester.tap(find.byKey(const Key('stone-sort-open')));
      await tester.pumpAndSettle();
      final lastOption = find.byKey(const Key('stone-sort-price-high-to-low'));
      await tester.ensureVisible(lastOption);
      await tester.pumpAndSettle();
      await tester.tap(lastOption);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('stone-sort-open')),
          matching: find.text('Price: High to Low'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('STN-001 stones list tolerates narrow widths and larger text', (
    tester,
  ) async {
    await _withFlutterErrorCapture(tester, () async {
      for (final locale in const [Locale('en'), Locale('ja')]) {
        for (final (width, scale) in const [
          (432.0, 1.6),
          (320.0, 1.0),
          (320.0, 1.6),
        ]) {
          await _pumpStonesProbe(
            tester,
            locale: locale,
            size: Size(width, 720),
            textScale: scale,
          );
          await tester.ensureVisible(
            find.byKey(const Key('stone-card-open')).last,
          );
          await tester.pump();
        }

        await tester.ensureVisible(find.byKey(const Key('stone-filters-open')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('stone-filters-open')));
        await tester.pumpAndSettle();
        // At 1.6x text the sheet scrolls, so bring each chip into view first.
        for (final chip in const [
          Key('stone-filter-color-green'),
          Key('stone-filter-availability-available'),
        ]) {
          await tester.ensureVisible(find.byKey(chip));
          await tester.pump();
          await tester.tap(find.byKey(chip));
          await tester.pump();
        }
        await tester.ensureVisible(
          find.byKey(const Key('stone-filters-apply')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('stone-filters-apply')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('stone-filters-clear')), findsOneWidget);
        expect(
          find.byKey(const Key('stone-active-filter-color')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('stone-active-filter-availability')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('stone-filters-clear')));
        await tester.pump();
      }
    });
  });
}

Future<void> _pumpRtlProbe(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: GeneratedHankoLocalizations.supportedLocales,
      localizationsDelegates:
          GeneratedHankoLocalizations.localizationsDelegates,
      theme: HankoTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 720),
          textScaler: TextScaler.linear(1.3),
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _withFlutterErrorCapture(
  WidgetTester tester,
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
    reason: details.map((detail) => detail.exceptionAsString()).join('\n'),
  );
  expect(tester.takeException(), isNull);
}

OrderDraftInput _longCheckoutInput() {
  return const OrderDraftInput(
    contact: OrderDraftContactInput(
      email: 'customer.with.a.long.name@example.test',
      preferredLocale: 'en',
    ),
    shipping: OrderDraftShippingInput(
      countryCode: 'US',
      recipientName: 'Alexandria Montgomery-Sakuraba',
      phone: '+1 555 0000 0000',
      postalCode: '12345-6789',
      state: 'California',
      city: 'San Francisco',
      addressLine1: '1234 Very Long International Shipping Address Avenue',
      addressLine2: 'Apartment 9876, Building With A Long Name',
    ),
    orderNote:
        'Please deliver during weekday business hours and keep the custom seal packaging intact.',
    termsAgreed: true,
    customerConfirmation: OrderDraftCustomerConfirmationInput(
      kanjiAndDesign: true,
      customMadePolicy: true,
    ),
  );
}

OrderDraft _longOrderDraft() {
  return OrderDraft.empty()
      .withSealSelection(
        const OrderDraftSealSelection(
          localSealDesignId: 'local_seal_001',
          selectedKanji: '美空',
          reading: 'Misora',
          shape: 'square',
          style: 'elegant',
          strokeWeight: 'standard',
          balance: 'balanced',
          aiGenerationId: 'seal_request_001',
          aiVariantId: 'seal_variant_001',
          previewImageStoragePath:
              'seal_designs/seal_request_001/seal_variant_001.png',
          previewImageDownloadUrl: '',
          localImagePath: '',
        ),
      )
      .withStoneSelection(
        const OrderDraftStoneSelection(
          listingId: 'stone_listing_001',
          code: 'RQZ-0001-LONG-CODE',
          materialKey: 'rose_quartz',
          materialLabel: 'Rose Quartz With A Very Long Material Label',
          sizeLabel: '24x24x60 mm',
          title: 'Soft Pink Rose Quartz Seal Stone With Long Listing Name',
          price: Money(amount: 18000, currency: 'JPY'),
          status: 'published',
          isOrderable: true,
          primaryPhotoUrl: 'https://example.test/stone.png',
        ),
      );
}

Future<void> _pumpStonesProbe(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
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
      // Applied through the builder so routes pushed on the navigator (the
      // filter sheet) get the same text scale as the page itself.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: StonesHomeScreen(
        result: StoneListingsResult(
          locale: locale.languageCode,
          currency: 'JPY',
          listings: [
            _longStoneListing(
              id: 'stone_listing_001',
              colorFamily: 'green',
              patternPrimary: 'mottled',
              priceAmount: 1280000,
            ),
            _longStoneListing(
              id: 'stone_listing_002',
              colorFamily: 'pink',
              patternPrimary: 'speckled',
            ),
            _longStoneListing(
              id: 'stone_listing_003',
              colorFamily: 'black',
              patternPrimary: 'banded',
              status: 'sold',
              isOrderable: false,
            ),
          ],
        ),
        selectedStoneId: 'stone_listing_002',
        onOpenStoneDetail: (_) {},
        onSelectStone: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StoneListing _longStoneListing({
  required String id,
  required String colorFamily,
  required String patternPrimary,
  int priceAmount = 18000,
  String status = 'published',
  bool? isOrderable,
}) {
  return StoneListing(
    id: id,
    code: 'RQZ-0001-LONG-CODE',
    materialKey: 'rose_quartz',
    materialLabel: 'Rose Quartz With A Very Long Material Label',
    sizeLabel: '24x24x60 mm',
    title: 'Soft Pink Rose Quartz Seal Stone With Long Listing Name',
    description: 'A soft pink rose quartz seal stone.',
    story: 'A one-of-a-kind piece.',
    facets: StoneListingFacets(
      colorFamily: colorFamily,
      colorTags: [colorFamily],
      patternPrimary: patternPrimary,
      patternTags: [patternPrimary],
      stoneShape: 'square',
      translucency: 'translucent',
    ),
    price: Money(amount: priceAmount, currency: 'JPY'),
    status: status,
    isActive: true,
    isOrderable: isOrderable,
    photos: const [],
  );
}
