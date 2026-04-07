import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hankofield/features/order/data/order_draft_storage.dart';
import 'package:hankofield/features/order/domain/order_models.dart';

OrderDraftData _sampleDraft() {
  return const OrderDraftData(
    stepValue: 3,
    sealLine1: '山',
    sealLine2: '田',
    kanjiStyleCode: 'japanese',
    selectedFontKey: 'zen_maru_gothic',
    shapeCode: 'square',
    selectedMaterialKey: 'rose_quartz',
    selectedCountryCode: 'JP',
    realName: '山田太郎',
    candidateGenderCode: 'unspecified',
    recipientName: '山田 太郎',
    email: 'taro@example.com',
    phone: '09000001111',
    postalCode: '100-0001',
    stateName: '東京都',
    city: '千代田区',
    addressLine1: '千代田1-1',
    addressLine2: '',
    termsAgreed: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves drafts with a timestamp and loads them back', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = OrderDraftStorage();
    final draft = _sampleDraft();

    await storage.save(draft);
    final loaded = await storage.load();

    expect(loaded, isNotNull);
    expect(loaded!.email, draft.email);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hanko_field_order_draft_v1');
    expect(raw, isNotNull);

    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['saved_at_ms'], isA<int>());
  });

  test('expires drafts after 30 minutes', () async {
    final expiredAt = DateTime.now()
        .subtract(const Duration(minutes: 31))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'hanko_field_order_draft_v1': jsonEncode({
        'saved_at_ms': expiredAt,
        ..._sampleDraft().toJson(),
      }),
    });

    final storage = OrderDraftStorage();
    final loaded = await storage.load();

    expect(loaded, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('hanko_field_order_draft_v1'), isFalse);
  });
}
