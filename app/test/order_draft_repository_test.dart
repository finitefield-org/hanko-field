import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hankofield/features/order/order.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDirectory;
  late String databasePath;
  late SqfliteLocalOrderDraftRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('hanko_draft_test_');
    databasePath = p.join(tempDirectory.path, 'order_draft.db');
    repository = SqfliteLocalOrderDraftRepository(
      databaseFactory: databaseFactoryFfi,
      databasePathResolver: () async => databasePath,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('saves and reloads order draft selections and checkout input', () async {
    final draft =
        OrderDraft.empty(updatedAt: DateTime.parse('2026-05-22T10:00:00+09:00'))
            .withSealSelection(
              _sealSelection(),
              updatedAt: DateTime.parse('2026-05-22T10:05:00+09:00'),
            )
            .withStoneSelection(
              _stoneSelection(),
              updatedAt: DateTime.parse('2026-05-22T10:10:00+09:00'),
            )
            .withInput(
              const OrderDraftInput(
                contact: OrderDraftContactInput(
                  email: 'michael@example.test',
                  preferredLocale: 'en',
                ),
                shipping: OrderDraftShippingInput(
                  countryCode: 'JP',
                  recipientName: 'Michael Smith',
                  phone: '+81-90-0000-0000',
                  postalCode: '100-0001',
                  state: 'Tokyo',
                  city: 'Chiyoda',
                  addressLine1: '1-1',
                  addressLine2: '',
                ),
                orderNote: 'Please ship on a weekday.',
                termsAgreed: true,
                customerConfirmation: OrderDraftCustomerConfirmationInput(
                  kanjiAndDesign: true,
                  customMadePolicy: true,
                ),
              ),
              updatedAt: DateTime.parse('2026-05-22T10:15:00+09:00'),
            );

    await repository.saveOrderDraft(draft);

    final saved = await repository.loadOrderDraft();

    expect(saved.sealSelection?.localSealDesignId, 'local_seal_001');
    expect(saved.sealSelection?.selectedKanji, '美空');
    expect(saved.stoneSelection?.listingId, 'stone_listing_001');
    expect(saved.stoneSelection?.title, 'Soft Pink Rose Quartz Seal Stone');
    expect(saved.stoneSelection?.price.amount, 18000);
    expect(saved.stoneSelection?.primaryPhotoUrl, 'https://example.test/1.png');
    expect(saved.input.contact.email, 'michael@example.test');
    expect(saved.input.shipping.city, 'Chiyoda');
    expect(saved.input.orderNote, 'Please ship on a weekday.');
    expect(saved.input.termsAgreed, isTrue);
    expect(saved.input.customerConfirmation.kanjiAndDesign, isTrue);
    expect(saved.input.customerConfirmation.customMadePolicy, isTrue);
    expect(saved.input.customerConfirmation.isComplete, isTrue);
    expect(saved.hasCombinationSelections, isTrue);
  });

  test('clears and tolerates corrupted order draft rows', () async {
    expect(
      (await repository.loadOrderDraft()).hasCombinationSelections,
      isFalse,
    );

    await repository.saveOrderDraft(
      OrderDraft.empty().withSealSelection(_sealSelection()),
    );
    expect((await repository.loadOrderDraft()).hasSealSelection, isTrue);

    await repository.clearOrderDraft();
    expect((await repository.loadOrderDraft()).hasSealSelection, isFalse);

    final db = await databaseFactoryFfi.openDatabase(databasePath);
    await db.insert('order_draft', {
      'id': 'current',
      'draft_json': '{"updated_at": "not-a-date"}',
      'updated_at': 'not-a-date',
    });
    await db.close();

    expect((await repository.loadOrderDraft()).hasSealSelection, isFalse);
  });

  test(
    'keeps selections when older input payload omits checkout fields',
    () async {
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      await db.execute('''
CREATE TABLE IF NOT EXISTS order_draft (
  id TEXT PRIMARY KEY,
  draft_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
      await db.insert('order_draft', {
        'id': 'current',
        'draft_json':
            '{"updated_at":"2026-05-22T10:00:00.000+09:00",'
            '"seal_selection":${_jsonEncodeSealSelection()},'
            '"stone_selection":${_jsonEncodeStoneSelection()},'
            '"input":{}}',
        'updated_at': '2026-05-22T10:00:00.000+09:00',
      });
      await db.close();

      final saved = await repository.loadOrderDraft();

      expect(saved.sealSelection?.localSealDesignId, 'local_seal_001');
      expect(saved.stoneSelection?.listingId, 'stone_listing_001');
      expect(saved.input.contact.email, '');
      expect(saved.input.shipping.city, '');
      expect(saved.input.termsAgreed, isFalse);
      expect(saved.input.customerConfirmation.kanjiAndDesign, isFalse);
      expect(saved.input.customerConfirmation.customMadePolicy, isFalse);
    },
  );
}

OrderDraftSealSelection _sealSelection() {
  return const OrderDraftSealSelection(
    localSealDesignId: 'local_seal_001',
    selectedKanji: '美空',
    reading: 'Misora',
    shape: 'square',
    style: 'elegant',
    strokeWeight: 'standard',
    balance: 'balanced',
    aiGenerationId: 'seal_request_001',
    aiVariantId: 'seal_variant_001',
    previewImageStoragePath: 'seal_designs/seal_request_001/variant.png',
    previewImageDownloadUrl: 'https://storage.example.test/variant.png',
    localImagePath: '/tmp/local_seal_001.png',
  );
}

OrderDraftStoneSelection _stoneSelection() {
  return const OrderDraftStoneSelection(
    listingId: 'stone_listing_001',
    code: 'RQZ-0001',
    materialKey: 'rose_quartz',
    materialLabel: 'Rose Quartz',
    sizeLabel: '24x24x60 mm',
    title: 'Soft Pink Rose Quartz Seal Stone',
    price: Money(amount: 18000, currency: 'JPY'),
    status: 'published',
    isOrderable: true,
    primaryPhotoUrl: 'https://example.test/1.png',
  );
}

String _jsonEncodeSealSelection() {
  return '''
{
  "local_seal_design_id": "local_seal_001",
  "selected_kanji": "美空",
  "reading": "Misora",
  "shape": "square",
  "style": "elegant",
  "stroke_weight": "standard",
  "balance": "balanced",
  "ai_generation_id": "seal_request_001",
  "ai_variant_id": "seal_variant_001",
  "preview_image_storage_path": "seal_designs/seal_request_001/variant.png",
  "preview_image_download_url": "https://storage.example.test/variant.png",
  "local_image_path": "/tmp/local_seal_001.png"
}
''';
}

String _jsonEncodeStoneSelection() {
  return '''
{
  "listing_id": "stone_listing_001",
  "code": "RQZ-0001",
  "material_key": "rose_quartz",
  "material_label": "Rose Quartz",
  "size_label": "24x24x60 mm",
  "title": "Soft Pink Rose Quartz Seal Stone",
  "price": {
    "amount": 18000,
    "currency": "JPY",
    "display": null
  },
  "status": "published",
  "is_orderable": true,
  "primary_photo_url": "https://example.test/1.png"
}
''';
}
