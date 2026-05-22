import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../../core/domain/money.dart';
import '../domain/order_draft.dart';

abstract interface class LocalOrderDraftRepository {
  Future<OrderDraft> loadOrderDraft();

  Future<void> saveOrderDraft(OrderDraft draft);

  Future<void> clearOrderDraft();
}

class InMemoryLocalOrderDraftRepository implements LocalOrderDraftRepository {
  InMemoryLocalOrderDraftRepository([OrderDraft? draft])
    : _draft = draft ?? OrderDraft.empty();

  OrderDraft _draft;

  @override
  Future<OrderDraft> loadOrderDraft() async {
    return _draft;
  }

  @override
  Future<void> saveOrderDraft(OrderDraft draft) async {
    _draft = draft;
  }

  @override
  Future<void> clearOrderDraft() async {
    _draft = OrderDraft.empty();
  }
}

class SqfliteLocalOrderDraftRepository implements LocalOrderDraftRepository {
  SqfliteLocalOrderDraftRepository({
    sqflite.DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePathResolver,
  }) : _databaseFactory = databaseFactory ?? sqflite.databaseFactory,
       _databasePathResolver = databasePathResolver ?? _defaultDatabasePath;

  static const _databaseName = 'hanko_field_order_draft.db';
  static const _table = 'order_draft';
  static const _currentDraftId = 'current';

  final sqflite.DatabaseFactory _databaseFactory;
  final Future<String> Function() _databasePathResolver;

  @override
  Future<OrderDraft> loadOrderDraft() async {
    final db = await _openDatabase();
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [_currentDraftId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return OrderDraft.empty();
    }
    return _OrderDraftRecord.tryFromMap(rows.first)?.toDomain() ??
        OrderDraft.empty();
  }

  @override
  Future<void> saveOrderDraft(OrderDraft draft) async {
    final db = await _openDatabase();
    await db.insert(
      _table,
      _OrderDraftRecord.fromDomain(draft).toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearOrderDraft() async {
    final db = await _openDatabase();
    await db.delete(_table, where: 'id = ?', whereArgs: [_currentDraftId]);
  }

  Future<sqflite.Database> _openDatabase() async {
    final databasePath = await _databasePathResolver();
    return _databaseFactory.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => _ensureSchema(db),
        onOpen: _ensureSchema,
      ),
    );
  }

  Future<void> _ensureSchema(sqflite.Database db) {
    return db.execute('''
CREATE TABLE IF NOT EXISTS $_table (
  id TEXT PRIMARY KEY,
  draft_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
  }

  static Future<String> _defaultDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, _databaseName);
  }
}

class _OrderDraftRecord {
  const _OrderDraftRecord({required this.draft});

  factory _OrderDraftRecord.fromDomain(OrderDraft draft) {
    return _OrderDraftRecord(draft: draft);
  }

  static _OrderDraftRecord? tryFromMap(Map<String, Object?> map) {
    try {
      return _OrderDraftRecord(
        draft: _orderDraftFromJson(
          _readJsonMap(jsonDecode(_readString(map, 'draft_json'))),
        ),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  final OrderDraft draft;

  Map<String, Object?> toMap() {
    return {
      'id': SqfliteLocalOrderDraftRepository._currentDraftId,
      'draft_json': jsonEncode(_orderDraftToJson(draft)),
      'updated_at': draft.updatedAt.toIso8601String(),
    };
  }

  OrderDraft toDomain() => draft;
}

Map<String, Object?> _orderDraftToJson(OrderDraft draft) {
  return {
    'updated_at': draft.updatedAt.toIso8601String(),
    'seal_selection': _sealSelectionToJson(draft.sealSelection),
    'stone_selection': _stoneSelectionToJson(draft.stoneSelection),
    'input': _inputToJson(draft.input),
  };
}

OrderDraft _orderDraftFromJson(Map<String, Object?> json) {
  return OrderDraft(
    sealSelection: _sealSelectionFromJson(json['seal_selection']),
    stoneSelection: _stoneSelectionFromJson(json['stone_selection']),
    input: _inputFromJson(json['input']),
    updatedAt: DateTime.parse(_readString(json, 'updated_at')),
  );
}

Map<String, Object?>? _sealSelectionToJson(OrderDraftSealSelection? selection) {
  if (selection == null) {
    return null;
  }
  return {
    'local_seal_design_id': selection.localSealDesignId,
    'selected_kanji': selection.selectedKanji,
    'reading': selection.reading,
    'shape': selection.shape,
    'style': selection.style,
    'stroke_weight': selection.strokeWeight,
    'balance': selection.balance,
    'ai_generation_id': selection.aiGenerationId,
    'ai_variant_id': selection.aiVariantId,
    'preview_image_storage_path': selection.previewImageStoragePath,
    'preview_image_download_url': selection.previewImageDownloadUrl,
    'local_image_path': selection.localImagePath,
  };
}

OrderDraftSealSelection? _sealSelectionFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  final json = _readJsonMap(value);
  return OrderDraftSealSelection(
    localSealDesignId: _readString(json, 'local_seal_design_id'),
    selectedKanji: _readString(json, 'selected_kanji'),
    reading: _readString(json, 'reading'),
    shape: _readString(json, 'shape'),
    style: _readString(json, 'style'),
    strokeWeight: _readString(json, 'stroke_weight'),
    balance: _readString(json, 'balance'),
    aiGenerationId: _readString(json, 'ai_generation_id'),
    aiVariantId: _readString(json, 'ai_variant_id'),
    previewImageStoragePath: _readString(json, 'preview_image_storage_path'),
    previewImageDownloadUrl: _readString(
      json,
      'preview_image_download_url',
      allowEmpty: true,
    ),
    localImagePath: _readString(json, 'local_image_path', allowEmpty: true),
  );
}

Map<String, Object?>? _stoneSelectionToJson(
  OrderDraftStoneSelection? selection,
) {
  if (selection == null) {
    return null;
  }
  return {
    'listing_id': selection.listingId,
    'code': selection.code,
    'material_key': selection.materialKey,
    'material_label': selection.materialLabel,
    'size_label': selection.sizeLabel,
    'title': selection.title,
    'price': _moneyToJson(selection.price),
    'status': selection.status,
    'is_orderable': selection.isOrderable,
    'primary_photo_url': selection.primaryPhotoUrl,
  };
}

OrderDraftStoneSelection? _stoneSelectionFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  final json = _readJsonMap(value);
  return OrderDraftStoneSelection(
    listingId: _readString(json, 'listing_id'),
    code: _readString(json, 'code'),
    materialKey: _readString(json, 'material_key'),
    materialLabel: _readString(json, 'material_label', allowEmpty: true),
    sizeLabel: _readString(json, 'size_label', allowEmpty: true),
    title: _readString(json, 'title'),
    price: _moneyFromJson(json['price']),
    status: _readString(json, 'status'),
    isOrderable: _readBool(json, 'is_orderable'),
    primaryPhotoUrl: _readString(json, 'primary_photo_url', allowEmpty: true),
  );
}

Map<String, Object?> _moneyToJson(Money money) {
  return {
    'amount': money.amount,
    'currency': money.currency,
    'display': money.display,
  };
}

Money _moneyFromJson(Object? value) {
  final json = _readJsonMap(value);
  return Money(
    amount: _readInt(json, 'amount'),
    currency: _readString(json, 'currency'),
    display: _readNullableString(json, 'display'),
  );
}

Map<String, Object?> _inputToJson(OrderDraftInput input) {
  return {
    'contact': {
      'email': input.contact.email,
      'preferred_locale': input.contact.preferredLocale,
    },
    'shipping': {
      'country_code': input.shipping.countryCode,
      'recipient_name': input.shipping.recipientName,
      'phone': input.shipping.phone,
      'postal_code': input.shipping.postalCode,
      'state': input.shipping.state,
      'city': input.shipping.city,
      'address_line1': input.shipping.addressLine1,
      'address_line2': input.shipping.addressLine2,
    },
    'order_note': input.orderNote,
    'terms_agreed': input.termsAgreed,
  };
}

OrderDraftInput _inputFromJson(Object? value) {
  if (value == null) {
    return const OrderDraftInput.empty();
  }
  final json = _readJsonMap(value);
  final contact = _readOptionalJsonMap(json['contact']);
  final shipping = _readOptionalJsonMap(json['shipping']);
  return OrderDraftInput(
    contact: OrderDraftContactInput(
      email: _readOptionalString(contact, 'email'),
      preferredLocale: _readOptionalString(contact, 'preferred_locale'),
    ),
    shipping: OrderDraftShippingInput(
      countryCode: _readOptionalString(shipping, 'country_code'),
      recipientName: _readOptionalString(shipping, 'recipient_name'),
      phone: _readOptionalString(shipping, 'phone'),
      postalCode: _readOptionalString(shipping, 'postal_code'),
      state: _readOptionalString(shipping, 'state'),
      city: _readOptionalString(shipping, 'city'),
      addressLine1: _readOptionalString(shipping, 'address_line1'),
      addressLine2: _readOptionalString(shipping, 'address_line2'),
    ),
    orderNote: _readOptionalString(json, 'order_note'),
    termsAgreed: _readOptionalBool(json, 'terms_agreed'),
  );
}

Map<String, Object?> _readJsonMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('value must be a JSON object');
  }
  return value.map((key, value) {
    if (key is! String) {
      throw const FormatException('JSON object contains a non-string key');
    }
    return MapEntry(key, value);
  });
}

Map<String, Object?> _readOptionalJsonMap(Object? value) {
  if (value == null) {
    return const {};
  }
  return _readJsonMap(value);
}

String _readString(
  Map<String, Object?> map,
  String key, {
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is String && (allowEmpty || value.isNotEmpty)) {
    return value;
  }
  throw FormatException('Invalid order draft string: $key');
}

String _readOptionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid order draft optional string: $key');
}

String? _readNullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value.isEmpty ? null : value;
  }
  throw FormatException('Invalid order draft nullable string: $key');
}

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Invalid order draft int: $key');
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value == 1;
  }
  throw FormatException('Invalid order draft bool: $key');
}

bool _readOptionalBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return false;
  }
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value == 1;
  }
  throw FormatException('Invalid order draft optional bool: $key');
}
