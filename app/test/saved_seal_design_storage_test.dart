import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hankofield/features/order/data/saved_seal_design_storage.dart';
import 'package:hankofield/features/order/domain/order_models.dart';

SavedSealDesignData _sampleDesign({
  String id = 'seal_1',
  String line1 = '山',
  String line2 = '田',
  String fontKey = 'zen_maru_gothic',
  bool isFavorite = false,
  int createdAtMillis = 1000,
  int updatedAtMillis = 1000,
}) {
  return SavedSealDesignData(
    id: id,
    sealLine1: line1,
    sealLine2: line2,
    kanjiStyleCode: KanjiStyle.japanese.code,
    selectedFontKey: fontKey,
    fontLabel: 'Zen Maru Gothic',
    fontFamily: "'Zen Maru Gothic', sans-serif",
    shapeCode: SealShape.square.code,
    reading: 'yamada',
    meaning: 'A balanced suggestion.',
    isFavorite: isFavorite,
    createdAtMillis: createdAtMillis,
    updatedAtMillis: updatedAtMillis,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('serializes only non-personal seal design state', () {
    final payload = _sampleDesign().copyWith(isFavorite: true).toJson();

    expect(
      payload.keys,
      unorderedEquals(SavedSealDesignData.persistedJsonKeys),
    );
    expect(payload['seal_line1'], '山');
    expect(payload['seal_line2'], '田');
    expect(payload['selected_font_key'], 'zen_maru_gothic');
    expect(payload['kanji_style'], KanjiStyle.japanese.code);
    expect(payload['shape'], SealShape.square.code);
    expect(payload['reading'], 'yamada');
    expect(payload['meaning'], 'A balanced suggestion.');
    expect(payload['is_favorite'], isTrue);
    expect(payload.keys, isNot(contains('real_name')));
    expect(payload.keys, isNot(contains('recipient_name')));
    expect(payload.keys, isNot(contains('email')));
    expect(payload.keys, isNot(contains('phone')));
    expect(payload.keys, isNot(contains('postal_code')));
    expect(payload.keys, isNot(contains('address_line1')));
    expect(payload.keys, isNot(contains('font_label')));
    expect(payload.keys, isNot(contains('font_family')));
  });

  test('saves and loads saved seal designs', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SavedSealDesignStorage();

    final saved = await storage.save(_sampleDesign());
    final loaded = await storage.load();

    expect(saved, hasLength(1));
    expect(loaded, hasLength(1));
    expect(loaded.single.sealDisplay, '山 / 田');
    expect(loaded.single.reading, 'yamada');

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hanko_field_saved_seal_designs_v1');
    expect(raw, isNotNull);
    expect(jsonDecode(raw!) as List<dynamic>, hasLength(1));
  });

  test(
    'deduplicates the same visual design and keeps the newest first',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SavedSealDesignStorage();

      await storage.save(_sampleDesign(id: 'seal_old', createdAtMillis: 100));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await storage.save(
        _sampleDesign(
          id: 'seal_new',
          createdAtMillis: 200,
          line1: '山',
          line2: '田',
          isFavorite: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await storage.save(
        _sampleDesign(id: 'seal_other', line1: '海', line2: '', fontKey: 'kiwi'),
      );

      final loaded = await storage.load();

      expect(loaded, hasLength(2));
      expect(loaded.first.id, 'seal_other');
      expect(loaded.last.id, 'seal_new');
      expect(loaded.last.isFavorite, isFalse);
    },
  );

  test('updates favorite state on a saved seal design', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SavedSealDesignStorage();

    await storage.save(_sampleDesign(id: 'seal_1'));
    await storage.save(_sampleDesign(id: 'seal_2', line1: '海', line2: ''));

    final favorited = await storage.setFavorite('seal_1', true);
    expect(
      favorited.where((design) => design.id == 'seal_1').single.isFavorite,
      isTrue,
    );

    final reloaded = await storage.load();
    expect(
      reloaded.where((design) => design.id == 'seal_1').single.isFavorite,
      isTrue,
    );

    final unchanged = await storage.setFavorite('missing', true);
    expect(unchanged, hasLength(2));
  });

  test('deletes a saved seal design by id', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SavedSealDesignStorage();

    await storage.save(_sampleDesign(id: 'seal_1'));
    await storage.save(_sampleDesign(id: 'seal_2', line1: '海', line2: ''));

    final loaded = await storage.delete('seal_1');

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'seal_2');
  });

  test('overwrites malformed saved design storage on save', () async {
    SharedPreferences.setMockInitialValues({
      'hanko_field_saved_seal_designs_v1': '{malformed',
    });
    final storage = SavedSealDesignStorage();

    final saved = await storage.save(_sampleDesign());
    final loaded = await storage.load();

    expect(saved, hasLength(1));
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'seal_1');
  });

  test('normalizes loaded storage by dropping non-design keys', () async {
    final pollutedPayload = <String, Object?>{
      ..._sampleDesign().toJson(),
      'real_name': 'Taro Yamada',
      'recipient_name': 'Taro Yamada',
      'email': 'taro@example.com',
      'phone': '09000000000',
      'postal_code': '1000001',
      'address_line1': '1-1',
      'font_label': 'Zen Maru Gothic',
      'font_family': "'Zen Maru Gothic', sans-serif",
    };
    SharedPreferences.setMockInitialValues({
      'hanko_field_saved_seal_designs_v1': jsonEncode([pollutedPayload]),
    });
    final storage = SavedSealDesignStorage();

    final loaded = await storage.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.sealDisplay, '山 / 田');
    expect(loaded.single.fontLabel, isEmpty);
    expect(loaded.single.fontFamily, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hanko_field_saved_seal_designs_v1');
    final sanitizedItems = jsonDecode(raw!) as List<dynamic>;
    final sanitizedPayload = sanitizedItems.single as Map<String, dynamic>;
    expect(
      sanitizedPayload.keys,
      unorderedEquals(SavedSealDesignData.persistedJsonKeys),
    );
    expect(sanitizedPayload.keys, isNot(contains('real_name')));
    expect(sanitizedPayload.keys, isNot(contains('email')));
    expect(sanitizedPayload.keys, isNot(contains('font_label')));
    expect(sanitizedPayload.keys, isNot(contains('font_family')));
  });
}
