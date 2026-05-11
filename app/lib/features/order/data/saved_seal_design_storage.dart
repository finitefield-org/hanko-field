import 'dart:convert';
import 'dart:math';

import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/order_models.dart';

class SavedSealDesignStorage {
  static const _storageKey = 'hanko_field_saved_seal_designs_v1';
  static const _maxItems = 20;

  Future<List<SavedSealDesignData>> _pendingWrite =
      Future<List<SavedSealDesignData>>.value(const []);

  Future<List<SavedSealDesignData>> load() async {
    try {
      await _pendingWrite.catchError((_) => const <SavedSealDesignData>[]);
      final prefs = await SharedPreferences.getInstance();
      final designs = _loadFromPrefs(prefs);
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          await _persist(prefs, designs);
        } catch (_) {
          // Loading should still succeed even if normalizing old payloads fails.
        }
      }
      return designs;
    } catch (_) {
      return const [];
    }
  }

  Future<List<SavedSealDesignData>> save(SavedSealDesignData design) {
    return _queueWrite((prefs) async {
      final existing = _loadFromPrefs(prefs);
      final now = DateTime.now().millisecondsSinceEpoch;

      SavedSealDesignData? previousDesign;
      for (final item in existing) {
        if (item.id == design.id || item.hasSameDesignAs(design)) {
          previousDesign = item;
          break;
        }
      }

      final normalized = design.copyWith(
        id: design.id.trim().isNotEmpty ? design.id : _newId(now),
        isFavorite: previousDesign?.isFavorite ?? design.isFavorite,
        createdAtMillis:
            previousDesign?.createdAtMillis ??
            (design.createdAtMillis > 0 ? design.createdAtMillis : now),
        updatedAtMillis: now,
      );

      final next = <SavedSealDesignData>[
        normalized,
        ...existing.where(
          (item) =>
              item.id != normalized.id && !item.hasSameDesignAs(normalized),
        ),
      ].take(_maxItems).toList(growable: false);

      await _persist(prefs, next);
      return next;
    });
  }

  Future<List<SavedSealDesignData>> setFavorite(String id, bool isFavorite) {
    return _queueWrite((prefs) async {
      final existing = _loadFromPrefs(prefs);
      var changed = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      final next = existing
          .map((item) {
            if (item.id != id) {
              return item;
            }
            changed = true;
            return item.copyWith(isFavorite: isFavorite, updatedAtMillis: now);
          })
          .toList(growable: false);

      if (!changed) {
        return existing;
      }

      next.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      await _persist(prefs, next);
      return next;
    });
  }

  Future<List<SavedSealDesignData>> delete(String id) {
    return _queueWrite((prefs) async {
      final next = _loadFromPrefs(
        prefs,
      ).where((item) => item.id != id).toList(growable: false);
      await _persist(prefs, next);
      return next;
    });
  }

  Future<List<SavedSealDesignData>> _queueWrite(
    Future<List<SavedSealDesignData>> Function(SharedPreferences prefs) write,
  ) {
    final previous = _pendingWrite;
    final next = previous.catchError((_) => const <SavedSealDesignData>[]).then(
      (_) async {
        final prefs = await SharedPreferences.getInstance();
        return write(prefs);
      },
    );
    _pendingWrite = next;
    return next;
  }

  List<SavedSealDesignData> _loadFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }

    final rawItems = switch (decoded) {
      List<Object?> items => items,
      {'items': List<Object?> items} => items,
      _ => const <Object?>[],
    };

    final designs = <SavedSealDesignData>[];
    for (final item in rawItems) {
      if (item is! Map) {
        continue;
      }
      final payload = item.map((key, value) => MapEntry(key.toString(), value));
      final design = SavedSealDesignData.fromJson(payload);
      if (design.id.trim().isEmpty || design.sealLine1.trim().isEmpty) {
        continue;
      }
      designs.add(design);
    }

    designs.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    return designs.take(_maxItems).toList(growable: false);
  }

  Future<void> _persist(
    SharedPreferences prefs,
    List<SavedSealDesignData> designs,
  ) async {
    await prefs.setString(
      _storageKey,
      jsonEncode(designs.map((design) => design.toJson()).toList()),
    );
  }

  String _newId(int millis) {
    final randomPart = Random().nextInt(0x7fffffff).toRadixString(16);
    return 'seal_${millis}_$randomPart';
  }
}

final savedSealDesignStorageProvider = Provider<SavedSealDesignStorage>((ref) {
  return SavedSealDesignStorage();
});
