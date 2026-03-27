import 'dart:convert';

import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/order_models.dart';

class OrderDraftStorage {
  static const _storageKey = 'hanko_field_order_draft_v1';

  Future<void> _pendingSave = Future<void>.value();

  Future<OrderDraftData?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return OrderDraftData.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(OrderDraftData draft) {
    final previous = _pendingSave;
    _pendingSave = previous.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(draft.toJson()));
    });
    return _pendingSave.catchError((_) {});
  }
}

final orderDraftStorageProvider = Provider<OrderDraftStorage>((ref) {
  return OrderDraftStorage();
});
