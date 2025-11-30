// ignore_for_file: public_member_api_docs

import 'package:app/core/utils/json_utils.dart';
import 'package:app/features/content/data/models/content_models.dart';

class GuideSeoDto {
  const GuideSeoDto({this.metaTitle, this.metaDescription, this.ogImage});

  final String? metaTitle;
  final String? metaDescription;
  final String? ogImage;

  factory GuideSeoDto.fromJson(Map<String, Object?> json) {
    return GuideSeoDto(
      metaTitle: json['metaTitle'] as String?,
      metaDescription: json['metaDescription'] as String?,
      ogImage: json['ogImage'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'metaTitle': metaTitle,
    'metaDescription': metaDescription,
    'ogImage': ogImage,
  };

  GuideSeo toDomain() {
    return GuideSeo(
      metaTitle: metaTitle,
      metaDescription: metaDescription,
      ogImage: ogImage,
    );
  }

  static GuideSeoDto fromDomain(GuideSeo seo) {
    return GuideSeoDto(
      metaTitle: seo.metaTitle,
      metaDescription: seo.metaDescription,
      ogImage: seo.ogImage,
    );
  }
}

class GuideTranslationDto {
  const GuideTranslationDto({
    required this.title,
    required this.body,
    this.summary,
    this.seo,
  });

  final String title;
  final String body;
  final String? summary;
  final GuideSeoDto? seo;

  factory GuideTranslationDto.fromJson(Map<String, Object?> json) {
    return GuideTranslationDto(
      title: json['title'] as String,
      body: json['body'] as String,
      summary: json['summary'] as String?,
      seo: json['seo'] != null
          ? GuideSeoDto.fromJson(Map<String, Object?>.from(json['seo'] as Map))
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
    'summary': summary,
    'seo': seo?.toJson(),
  };

  GuideTranslation toDomain() {
    return GuideTranslation(
      title: title,
      body: body,
      summary: summary,
      seo: seo?.toDomain(),
    );
  }

  static GuideTranslationDto fromDomain(GuideTranslation translation) {
    return GuideTranslationDto(
      title: translation.title,
      body: translation.body,
      summary: translation.summary,
      seo: translation.seo != null
          ? GuideSeoDto.fromDomain(translation.seo!)
          : null,
    );
  }
}

class GuideAuthorDto {
  const GuideAuthorDto({this.name, this.profileUrl});

  final String? name;
  final String? profileUrl;

  factory GuideAuthorDto.fromJson(Map<String, Object?> json) {
    return GuideAuthorDto(
      name: json['name'] as String?,
      profileUrl: json['profileUrl'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'profileUrl': profileUrl,
  };

  GuideAuthor toDomain() => GuideAuthor(name: name, profileUrl: profileUrl);

  static GuideAuthorDto fromDomain(GuideAuthor author) {
    return GuideAuthorDto(name: author.name, profileUrl: author.profileUrl);
  }
}

class GuideDto {
  const GuideDto({
    required this.slug,
    required this.category,
    required this.isPublic,
    required this.translations,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const <String>[],
    this.heroImageUrl,
    this.readingTimeMinutes,
    this.author,
    this.sources = const <String>[],
    this.publishAt,
    this.version,
    this.isDeprecated = false,
  });

  final String slug;
  final GuideCategory category;
  final bool isPublic;
  final Map<String, GuideTranslationDto> translations;
  final List<String> tags;
  final String? heroImageUrl;
  final int? readingTimeMinutes;
  final GuideAuthorDto? author;
  final List<String> sources;
  final DateTime? publishAt;
  final String? version;
  final bool isDeprecated;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GuideDto.fromJson(Map<String, Object?> json) {
    final translationsMap = Map<String, Object?>.from(
      json['translations'] as Map,
    );
    final translations = <String, GuideTranslationDto>{};
    translationsMap.forEach((key, value) {
      translations[key] = GuideTranslationDto.fromJson(
        Map<String, Object?>.from(value as Map),
      );
    });

    return GuideDto(
      slug: json['slug'] as String,
      category: GuideCategoryX.fromJson(json['category'] as String),
      isPublic: json['isPublic'] as bool? ?? false,
      translations: translations,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      heroImageUrl: json['heroImageUrl'] as String?,
      readingTimeMinutes: (json['readingTimeMinutes'] as num?)?.toInt(),
      author: json['author'] != null
          ? GuideAuthorDto.fromJson(
              Map<String, Object?>.from(json['author'] as Map),
            )
          : null,
      sources:
          (json['sources'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      publishAt: parseDateTime(json['publishAt']),
      version: json['version'] as String?,
      isDeprecated: json['isDeprecated'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'slug': slug,
    'category': category.toJson(),
    'isPublic': isPublic,
    'translations': translations.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'tags': tags,
    'heroImageUrl': heroImageUrl,
    'readingTimeMinutes': readingTimeMinutes,
    'author': author?.toJson(),
    'sources': sources,
    'publishAt': publishAt?.toIso8601String(),
    'version': version,
    'isDeprecated': isDeprecated,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Guide toDomain() {
    return Guide(
      slug: slug,
      category: category,
      isPublic: isPublic,
      translations: translations.map(
        (key, value) => MapEntry(key, value.toDomain()),
      ),
      tags: tags,
      heroImageUrl: heroImageUrl,
      readingTimeMinutes: readingTimeMinutes,
      author: author?.toDomain(),
      sources: sources,
      publishAt: publishAt,
      version: version,
      isDeprecated: isDeprecated,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static GuideDto fromDomain(Guide guide) {
    return GuideDto(
      slug: guide.slug,
      category: guide.category,
      isPublic: guide.isPublic,
      translations: guide.translations.map(
        (key, value) => MapEntry(key, GuideTranslationDto.fromDomain(value)),
      ),
      tags: guide.tags,
      heroImageUrl: guide.heroImageUrl,
      readingTimeMinutes: guide.readingTimeMinutes,
      author: guide.author != null
          ? GuideAuthorDto.fromDomain(guide.author!)
          : null,
      sources: guide.sources,
      publishAt: guide.publishAt,
      version: guide.version,
      isDeprecated: guide.isDeprecated,
      createdAt: guide.createdAt,
      updatedAt: guide.updatedAt,
    );
  }
}

class PageSeoDto {
  const PageSeoDto({this.metaTitle, this.metaDescription, this.ogImage});

  final String? metaTitle;
  final String? metaDescription;
  final String? ogImage;

  factory PageSeoDto.fromJson(Map<String, Object?> json) {
    return PageSeoDto(
      metaTitle: json['metaTitle'] as String?,
      metaDescription: json['metaDescription'] as String?,
      ogImage: json['ogImage'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'metaTitle': metaTitle,
    'metaDescription': metaDescription,
    'ogImage': ogImage,
  };

  PageSeo toDomain() {
    return PageSeo(
      metaTitle: metaTitle,
      metaDescription: metaDescription,
      ogImage: ogImage,
    );
  }

  static PageSeoDto fromDomain(PageSeo seo) {
    return PageSeoDto(
      metaTitle: seo.metaTitle,
      metaDescription: seo.metaDescription,
      ogImage: seo.ogImage,
    );
  }
}

class PageBlockDto {
  const PageBlockDto({required this.type, required this.data});

  final String type;
  final Map<String, Object?> data;

  factory PageBlockDto.fromJson(Map<String, Object?> json) {
    return PageBlockDto(
      type: json['type'] as String,
      data: Map<String, Object?>.from(json['data'] as Map),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'data': data,
  };

  PageBlock toDomain() => PageBlock(type: type, data: data);

  static PageBlockDto fromDomain(PageBlock block) {
    return PageBlockDto(type: block.type, data: block.data);
  }
}

class PageTranslationDto {
  const PageTranslationDto({
    required this.title,
    this.body,
    this.blocks = const <PageBlockDto>[],
    this.seo,
  });

  final String title;
  final String? body;
  final List<PageBlockDto> blocks;
  final PageSeoDto? seo;

  factory PageTranslationDto.fromJson(Map<String, Object?> json) {
    return PageTranslationDto(
      title: json['title'] as String,
      body: json['body'] as String?,
      blocks:
          (json['blocks'] as List?)
              ?.map(
                (e) =>
                    PageBlockDto.fromJson(Map<String, Object?>.from(e as Map)),
              )
              .toList() ??
          const <PageBlockDto>[],
      seo: json['seo'] != null
          ? PageSeoDto.fromJson(Map<String, Object?>.from(json['seo'] as Map))
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
    'blocks': blocks.map((e) => e.toJson()).toList(),
    'seo': seo?.toJson(),
  };

  PageTranslation toDomain() {
    return PageTranslation(
      title: title,
      body: body,
      blocks: blocks.map((e) => e.toDomain()).toList(),
      seo: seo?.toDomain(),
    );
  }

  static PageTranslationDto fromDomain(PageTranslation translation) {
    return PageTranslationDto(
      title: translation.title,
      body: translation.body,
      blocks: translation.blocks
          .map((e) => PageBlockDto.fromDomain(e))
          .toList(),
      seo: translation.seo != null
          ? PageSeoDto.fromDomain(translation.seo!)
          : null,
    );
  }
}

class PageContentDto {
  const PageContentDto({
    required this.slug,
    required this.type,
    required this.isPublic,
    required this.translations,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const <String>[],
    this.navOrder,
    this.publishAt,
    this.version,
    this.isDeprecated = false,
  });

  final String slug;
  final PageType type;
  final bool isPublic;
  final Map<String, PageTranslationDto> translations;
  final List<String> tags;
  final int? navOrder;
  final DateTime? publishAt;
  final String? version;
  final bool isDeprecated;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PageContentDto.fromJson(Map<String, Object?> json) {
    final translationsMap = Map<String, Object?>.from(
      json['translations'] as Map,
    );
    final translations = <String, PageTranslationDto>{};
    translationsMap.forEach((key, value) {
      translations[key] = PageTranslationDto.fromJson(
        Map<String, Object?>.from(value as Map),
      );
    });

    return PageContentDto(
      slug: json['slug'] as String,
      type: PageTypeX.fromJson(json['type'] as String),
      isPublic: json['isPublic'] as bool? ?? false,
      translations: translations,
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      navOrder: (json['navOrder'] as num?)?.toInt(),
      publishAt: parseDateTime(json['publishAt']),
      version: json['version'] as String?,
      isDeprecated: json['isDeprecated'] as bool? ?? false,
      createdAt:
          parseDateTime(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          parseDateTime(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'slug': slug,
    'type': type.toJson(),
    'isPublic': isPublic,
    'translations': translations.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'tags': tags,
    'navOrder': navOrder,
    'publishAt': publishAt?.toIso8601String(),
    'version': version,
    'isDeprecated': isDeprecated,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  PageContent toDomain() {
    return PageContent(
      slug: slug,
      type: type,
      isPublic: isPublic,
      translations: translations.map(
        (key, value) => MapEntry(key, value.toDomain()),
      ),
      tags: tags,
      navOrder: navOrder,
      publishAt: publishAt,
      version: version,
      isDeprecated: isDeprecated,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static PageContentDto fromDomain(PageContent page) {
    return PageContentDto(
      slug: page.slug,
      type: page.type,
      isPublic: page.isPublic,
      translations: page.translations.map(
        (key, value) => MapEntry(key, PageTranslationDto.fromDomain(value)),
      ),
      tags: page.tags,
      navOrder: page.navOrder,
      publishAt: page.publishAt,
      version: page.version,
      isDeprecated: page.isDeprecated,
      createdAt: page.createdAt,
      updatedAt: page.updatedAt,
    );
  }
}
