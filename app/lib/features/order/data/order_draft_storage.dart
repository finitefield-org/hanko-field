import 'dart:convert';

import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/order_models.dart';

class OrderDraftStorage {
  static const _storageKey = 'hanko_field_order_draft_v2';
  static const _savedAtKey = 'saved_at_ms';
  static const _retention = Duration(minutes: 30);

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
      final savedAtMillis = _savedAtMillis(payload);
      if (savedAtMillis != null) {
        final ageMillis = DateTime.now().millisecondsSinceEpoch - savedAtMillis;
        if (ageMillis > _retention.inMilliseconds) {
          await prefs.remove(_storageKey);
          return null;
        }
        return OrderDraftData.fromJson(payload);
      }

      final draft = OrderDraftData.fromJson(payload);
      await _persistDraft(prefs, draft);
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(OrderDraftData draft) {
    final previous = _pendingSave;
    _pendingSave = previous.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await _persistDraft(prefs, draft);
    });
    return _pendingSave.catchError((_) {});
  }

  Future<void> pruneExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(_storageKey);
        return;
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final savedAtMillis = _savedAtMillis(payload);
      if (savedAtMillis == null) {
        return;
      }

      final ageMillis = DateTime.now().millisecondsSinceEpoch - savedAtMillis;
      if (ageMillis > _retention.inMilliseconds) {
        await prefs.remove(_storageKey);
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persistDraft(
    SharedPreferences prefs,
    OrderDraftData draft,
  ) async {
    final payload = <String, Object?>{
      _savedAtKey: DateTime.now().millisecondsSinceEpoch,
      ...draft.toJson(),
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  int? _savedAtMillis(Map<String, Object?> payload) {
    final value = payload[_savedAtKey];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

final orderDraftStorageProvider = Provider<OrderDraftStorage>((ref) {
  return OrderDraftStorage();
});
