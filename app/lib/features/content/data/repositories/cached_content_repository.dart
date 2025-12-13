// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/network/network_client.dart';
import 'package:app/core/network/network_config.dart';
import 'package:app/core/network/network_providers.dart';
import 'package:app/core/storage/preferences.dart';
import 'package:app/features/content/data/dtos/public_content_dtos.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/content_repository.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  try {
    return ref.scope(ContentRepository.fallback);
  } on StateError {
    return CachedContentRepository(ref);
  }
});

class CachedContentRepository implements ContentRepository {
  CachedContentRepository(this._ref) : _logger = Logger('ContentRepository');

  final Ref _ref;
  final Logger _logger;

  NetworkClient get _client => _ref.watch(networkClientProvider);

  Future<SharedPreferences> get _prefs =>
      _ref.watch(sharedPreferencesProvider.future);

  @override
  Future<Page<Guide>> listGuides({
    String? lang,
    GuideCategory? category,
    String? pageToken,
  }) async {
    final normalizedLang = _normalizeLang(lang);
    final cacheKey = _guidesListCacheKey(
      lang: normalizedLang,
      category: category,
    );

    try {
      final response = await _client.get<Object?>(
        '/content/guides',
        queryParameters: {
          'lang': normalizedLang,
          if (category != null) 'category': category.toJson(),
          if (pageToken != null) 'pageToken': pageToken,
          'pageSize': 40,
        },
        decoder: (json) => json,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('Unexpected guide list response: $data');
      }
      final dto = GuideListResponseDto.fromJson(
        Map<String, Object?>.from(data),
      );

      if (pageToken == null || pageToken.isEmpty) {
        await _writeCache(cacheKey, dto);
      }

      return Page(
        items: dto.guides.map((g) => g.toDomain()).toList(),
        nextPageToken: dto.nextPageToken,
      );
    } catch (e, stack) {
      _logger.warning(
        'Guide list fetch failed; falling back to cache',
        e,
        stack,
      );
      final cached = await _readCache(cacheKey);
      if (cached != null) {
        return Page(
          items: cached.guides.map((g) => g.toDomain()).toList(),
          nextPageToken: cached.nextPageToken,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Guide> getGuide(String slug, {String? lang}) async {
    final trimmed = slug.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(slug, 'slug');

    final normalizedLang = _normalizeLang(lang);
    final cacheKey = _guideDetailCacheKey(slug: trimmed, lang: normalizedLang);

    try {
      final response = await _client.get<Object?>(
        '/content/guides/$trimmed',
        queryParameters: {'lang': normalizedLang},
        decoder: (json) => json,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('Unexpected guide detail response: $data');
      }

      await _writeCacheRaw(cacheKey, Map<String, Object?>.from(data));
      return GuideDetailDto.fromJson(
        Map<String, Object?>.from(data),
      ).toDomain();
    } catch (e, stack) {
      _logger.warning(
        'Guide detail fetch failed; falling back to cache',
        e,
        stack,
      );
      final cached = await _readCacheRaw(cacheKey);
      if (cached != null) {
        return GuideDetailDto.fromJson(cached).toDomain();
      }
      rethrow;
    }
  }

  @override
  Future<PageContent> getPage(String slug, {String? lang}) async {
    final trimmed = slug.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(slug, 'slug');

    final normalizedLang = _normalizeLang(lang);
    final cacheKey = _pageCacheKey(slug: trimmed, lang: normalizedLang);

    try {
      final response = await _client.get<Object?>(
        '/content/pages/$trimmed',
        queryParameters: {'lang': normalizedLang},
        decoder: (json) => json,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('Unexpected page response: $data');
      }

      await _writeCacheRaw(cacheKey, Map<String, Object?>.from(data));
      return ContentPageDto.fromJson(
        Map<String, Object?>.from(data),
      ).toDomain();
    } catch (e, stack) {
      _logger.warning('Page fetch failed; falling back to cache', e, stack);
      final cached = await _readCacheRaw(cacheKey);
      if (cached != null) {
        return ContentPageDto.fromJson(cached).toDomain();
      }
      rethrow;
    }
  }

  String _normalizeLang(String? lang) {
    final normalized = (lang ?? _ref.watch(networkConfigProvider).locale)
        ?.trim()
        .toLowerCase();
    if (normalized == null || normalized.isEmpty) return 'ja';
    if (normalized.startsWith('en')) return 'en';
    if (normalized.startsWith('ja')) return 'ja';
    return normalized.split('-').first;
  }

  Future<void> _writeCache(String key, GuideListResponseDto dto) async {
    final prefs = await _prefs;
    final json = <String, Object?>{
      'guides': dto.guides.map(_guideSummaryToJson).toList(),
      'next_page_token': dto.nextPageToken,
      'locale': dto.locale,
    };
    await prefs.setString(key, jsonEncode(json));
  }

  Future<GuideListResponseDto?> _readCache(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return GuideListResponseDto.fromJson(Map<String, Object?>.from(decoded));
    } catch (e, stack) {
      _logger.warning('Failed to decode guide list cache: $key', e, stack);
      return null;
    }
  }

  Future<void> _writeCacheRaw(String key, Map<String, Object?> value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<Map<String, Object?>?> _readCacheRaw(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, Object?>.from(decoded);
    } catch (e, stack) {
      _logger.warning('Failed to decode cache: $key', e, stack);
      return null;
    }
  }
}

Map<String, Object?> _guideSummaryToJson(GuideSummaryDto dto) {
  return <String, Object?>{
    'slug': dto.slug,
    'locale': dto.locale,
    'category': dto.category,
    'title': dto.title,
    'summary': dto.summary,
    'hero_image_url': dto.heroImageUrl,
    'tags': dto.tags,
    'is_published': dto.isPublished,
    'published_at': dto.publishedAt?.toIso8601String(),
    'updated_at': dto.updatedAt?.toIso8601String(),
    'created_at': dto.createdAt?.toIso8601String(),
  };
}

String _guidesListCacheKey({required String lang, GuideCategory? category}) {
  final cat = category?.toJson() ?? 'all';
  return 'content.guides.list.$lang.$cat';
}

String _guideDetailCacheKey({required String slug, required String lang}) {
  return 'content.guides.detail.$slug.$lang';
}

String _pageCacheKey({required String slug, required String lang}) {
  return 'content.pages.$slug.$lang';
}
