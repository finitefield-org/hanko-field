// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/core/storage/preferences.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class GuideBookmarksRepository {
  static final fallback = const Scope<GuideBookmarksRepository>.required(
    'guides.bookmarks.repo',
  );

  Future<Set<String>> loadBookmarks();
  Future<Set<String>> toggleBookmark(String slug);
}

final guideBookmarksRepositoryProvider = Provider<GuideBookmarksRepository>((
  ref,
) {
  try {
    return ref.scope(GuideBookmarksRepository.fallback);
  } on StateError {
    return _SharedPreferencesGuideBookmarksRepository(ref);
  }
});

class _SharedPreferencesGuideBookmarksRepository
    implements GuideBookmarksRepository {
  _SharedPreferencesGuideBookmarksRepository(this._ref)
    : _logger = Logger('GuideBookmarksRepository');

  final Ref _ref;
  final Logger _logger;

  Set<String>? _cache;

  Future<SharedPreferences> get _prefs =>
      _ref.watch(sharedPreferencesProvider.future);

  @override
  Future<Set<String>> loadBookmarks() async {
    if (_cache != null) return _cache!.toSet();
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = <String>{};
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = <String>{};
        return <String>{};
      }
      final ids = (decoded['slugs'] as List?)?.whereType<String>() ?? const [];
      _cache = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      return _cache!.toSet();
    } catch (e, stack) {
      _logger.warning('Failed to decode bookmarks', e, stack);
      _cache = <String>{};
      return <String>{};
    }
  }

  @override
  Future<Set<String>> toggleBookmark(String slug) async {
    final normalized = slug.trim();
    if (normalized.isEmpty) throw ArgumentError.value(slug, 'slug');

    final current = await loadBookmarks();
    final next = current.toSet();
    if (next.contains(normalized)) {
      next.remove(normalized);
    } else {
      next.add(normalized);
    }

    _cache = next.toSet();

    try {
      final prefs = await _prefs;
      await prefs.setString(
        _storageKey,
        jsonEncode(<String, Object?>{'slugs': next.toList()..sort()}),
      );
    } catch (e, stack) {
      _logger.warning('Failed to write bookmarks', e, stack);
    }

    return next;
  }
}

const _storageKey = 'content.guides.bookmarks.v1';
