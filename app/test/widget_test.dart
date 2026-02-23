import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'package:hankofield/app/app.dart';

void main() {
  testWidgets('order page renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HankoApp()));
    await tester.pump();

    expect(find.text('Stone Signature'), findsOneWidget);
  });
}
