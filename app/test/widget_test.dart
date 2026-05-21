import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'package:hankofield/app/app.dart';
import 'package:hankofield/features/design/design.dart';
import 'package:hankofield/features/my_seals/my_seals.dart';
import 'package:hankofield/features/order/order.dart';
import 'package:hankofield/features/order_lookup/order_lookup.dart';
import 'package:hankofield/features/settings/settings.dart';
import 'package:hankofield/features/stones/stones.dart';

void main() {
  testWidgets('boots the COM-003 bottom navigation shell', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: HankoApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DesignHomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MySealsHomeScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(StonesHomeScreen, skipOffstage: false), findsOneWidget);
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

  testWidgets('renders non-tab feature entry screens independently', (
    tester,
  ) async {
    Future<void> expectEntryScreen(
      Widget screen,
      String title,
      String routeName,
    ) async {
      await tester.pumpWidget(MaterialApp(home: screen));

      expect(find.text(title), findsOneWidget);
      expect(find.text(routeName), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await expectEntryScreen(const OrderFlowEntryScreen(), 'Order', '/order');
    await expectEntryScreen(
      const OrderLookupEntryScreen(),
      'Order Lookup',
      '/order-lookup',
    );
    await expectEntryScreen(
      const SettingsHomeScreen(),
      'Settings',
      '/settings',
    );
  });
}
