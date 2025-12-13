// ignore_for_file: public_member_api_docs

import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/content/data/models/content_models.dart';

class GuideListResponseDto {
  const GuideListResponseDto({
    required this.guides,
    this.nextPageToken,
    this.locale,
  });

  final List<GuideSummaryDto> guides;
  final String? nextPageToken;
  final String? locale;

  factory GuideListResponseDto.fromJson(Map<String, Object?> json) {
    return GuideListResponseDto(
      guides: mapList(json['guides'], (m) => GuideSummaryDto.fromJson(m)),
      nextPageToken: json['next_page_token'] as String?,
      locale: json['locale'] as String?,
    );
  }
}

class GuideSummaryDto {
  const GuideSummaryDto({
    required this.slug,
    required this.locale,
    required this.title,
    required this.isPublished,
    this.category,
    this.summary,
    this.heroImageUrl,
    this.tags = const <String>[],
    this.publishedAt,
    this.updatedAt,
    this.createdAt,
  });

  final String slug;
  final String locale;
  final String? category;
  final String title;
  final String? summary;
  final String? heroImageUrl;
  final List<String> tags;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  factory GuideSummaryDto.fromJson(Map<String, Object?> json) {
    return GuideSummaryDto(
      slug: (json['slug'] as String?)?.trim() ?? '',
      locale: (json['locale'] as String?)?.trim() ?? 'ja',
      category: (json['category'] as String?)?.trim(),
      title: (json['title'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim(),
      heroImageUrl: (json['hero_image_url'] as String?)?.trim(),
      tags:
          (json['tags'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const <String>[],
      isPublished: json['is_published'] as bool? ?? false,
      publishedAt: parseDateTime(json['published_at']),
      updatedAt: parseDateTime(json['updated_at']),
      createdAt: parseDateTime(json['created_at']),
    );
  }

  Guide toDomain() {
    GuideCategory categoryValue = GuideCategory.other;
    final categoryRaw = category;
    if (categoryRaw != null && categoryRaw.isNotEmpty) {
      try {
        categoryValue = GuideCategoryX.fromJson(categoryRaw);
      } catch (_) {}
    }

    final lang = locale.split('-').first.toLowerCase();
    final now = DateTime.fromMillisecondsSinceEpoch(0);

    return Guide(
      slug: slug,
      category: categoryValue,
      isPublic: isPublished,
      translations: {
        lang: GuideTranslation(
          title: title,
          body: '',
          summary: summary,
          seo: null,
        ),
      },
      tags: tags,
      heroImageUrl: heroImageUrl,
      readingTimeMinutes: _estimateReadingMinutes(summary),
      author: null,
      sources: const <String>[],
      publishAt: publishedAt,
      version: null,
      isDeprecated: false,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? createdAt ?? now,
    );
  }
}

class GuideDetailDto {
  const GuideDetailDto({required this.summary, this.bodyHtml});

  final GuideSummaryDto summary;
  final String? bodyHtml;

  factory GuideDetailDto.fromJson(Map<String, Object?> json) {
    return GuideDetailDto(
      summary: GuideSummaryDto.fromJson(json),
      bodyHtml: (json['body_html'] as String?)?.trim(),
    );
  }

  Guide toDomain() {
    final base = summary.toDomain();
    final lang = summary.locale.split('-').first.toLowerCase();
    final existing = base.translations[lang]!;
    return base.copyWith(
      translations: {
        ...base.translations,
        lang: existing.copyWith(body: bodyHtml ?? existing.body),
      },
    );
  }
}

class ContentPageDto {
  const ContentPageDto({
    required this.slug,
    required this.locale,
    required this.title,
    required this.isPublished,
    this.bodyHtml,
    this.updatedAt,
  });

  final String slug;
  final String locale;
  final String title;
  final String? bodyHtml;
  final bool isPublished;
  final DateTime? updatedAt;

  factory ContentPageDto.fromJson(Map<String, Object?> json) {
    return ContentPageDto(
      slug: (json['slug'] as String?)?.trim() ?? '',
      locale: (json['locale'] as String?)?.trim() ?? 'ja',
      title: (json['title'] as String?)?.trim() ?? '',
      bodyHtml: (json['body_html'] as String?)?.trim(),
      isPublished: json['is_published'] as bool? ?? false,
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  PageContent toDomain() {
    final lang = locale.split('-').first.toLowerCase();
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return PageContent(
      slug: slug,
      type: PageType.other,
      isPublic: isPublished,
      translations: {
        lang: PageTranslation(
          title: title,
          body: bodyHtml ?? '',
          blocks: const <PageBlock>[],
          seo: null,
        ),
      },
      tags: const <String>[],
      navOrder: null,
      publishAt: null,
      version: null,
      isDeprecated: false,
      createdAt: now,
      updatedAt: updatedAt ?? now,
    );
  }
}

int? _estimateReadingMinutes(String? summary) {
  final text = summary?.trim();
  if (text == null || text.isEmpty) return null;
  // 600-800 chars ~= ~3-4 min in Japanese/English mixed snippets.
  final minutes = (text.length / 220).ceil();
  return minutes.clamp(1, 15);
}
