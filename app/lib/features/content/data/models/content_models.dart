// ignore_for_file: public_member_api_docs

import 'package:collection/collection.dart';

enum GuideCategory { culture, howto, policy, faq, news, other }

extension GuideCategoryX on GuideCategory {
  String toJson() => switch (this) {
    GuideCategory.culture => 'culture',
    GuideCategory.howto => 'howto',
    GuideCategory.policy => 'policy',
    GuideCategory.faq => 'faq',
    GuideCategory.news => 'news',
    GuideCategory.other => 'other',
  };

  static GuideCategory fromJson(String value) {
    switch (value) {
      case 'culture':
        return GuideCategory.culture;
      case 'howto':
        return GuideCategory.howto;
      case 'policy':
        return GuideCategory.policy;
      case 'faq':
        return GuideCategory.faq;
      case 'news':
        return GuideCategory.news;
      case 'other':
        return GuideCategory.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported guide category');
  }
}

class GuideSeo {
  const GuideSeo({this.metaTitle, this.metaDescription, this.ogImage});

  final String? metaTitle;
  final String? metaDescription;
  final String? ogImage;

  GuideSeo copyWith({
    String? metaTitle,
    String? metaDescription,
    String? ogImage,
  }) {
    return GuideSeo(
      metaTitle: metaTitle ?? this.metaTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      ogImage: ogImage ?? this.ogImage,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GuideSeo &&
            other.metaTitle == metaTitle &&
            other.metaDescription == metaDescription &&
            other.ogImage == ogImage);
  }

  @override
  int get hashCode => Object.hash(metaTitle, metaDescription, ogImage);
}

class GuideTranslation {
  const GuideTranslation({
    required this.title,
    required this.body,
    this.summary,
    this.seo,
  });

  final String title;
  final String body;
  final String? summary;
  final GuideSeo? seo;

  GuideTranslation copyWith({
    String? title,
    String? body,
    String? summary,
    GuideSeo? seo,
  }) {
    return GuideTranslation(
      title: title ?? this.title,
      body: body ?? this.body,
      summary: summary ?? this.summary,
      seo: seo ?? this.seo,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GuideTranslation &&
            other.title == title &&
            other.body == body &&
            other.summary == summary &&
            other.seo == seo);
  }

  @override
  int get hashCode => Object.hash(title, body, summary, seo);
}

class GuideAuthor {
  const GuideAuthor({this.name, this.profileUrl});

  final String? name;
  final String? profileUrl;

  GuideAuthor copyWith({String? name, String? profileUrl}) {
    return GuideAuthor(
      name: name ?? this.name,
      profileUrl: profileUrl ?? this.profileUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is GuideAuthor &&
            other.name == name &&
            other.profileUrl == profileUrl);
  }

  @override
  int get hashCode => Object.hash(name, profileUrl);
}

class Guide {
  const Guide({
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
  final Map<String, GuideTranslation> translations;
  final List<String> tags;
  final String? heroImageUrl;
  final int? readingTimeMinutes;
  final GuideAuthor? author;
  final List<String> sources;
  final DateTime? publishAt;
  final String? version;
  final bool isDeprecated;
  final DateTime createdAt;
  final DateTime updatedAt;

  Guide copyWith({
    String? slug,
    GuideCategory? category,
    bool? isPublic,
    Map<String, GuideTranslation>? translations,
    List<String>? tags,
    String? heroImageUrl,
    int? readingTimeMinutes,
    GuideAuthor? author,
    List<String>? sources,
    DateTime? publishAt,
    String? version,
    bool? isDeprecated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Guide(
      slug: slug ?? this.slug,
      category: category ?? this.category,
      isPublic: isPublic ?? this.isPublic,
      translations: translations ?? this.translations,
      tags: tags ?? this.tags,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      readingTimeMinutes: readingTimeMinutes ?? this.readingTimeMinutes,
      author: author ?? this.author,
      sources: sources ?? this.sources,
      publishAt: publishAt ?? this.publishAt,
      version: version ?? this.version,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is Guide &&
            other.slug == slug &&
            other.category == category &&
            other.isPublic == isPublic &&
            deepEq.equals(other.translations, translations) &&
            listEq.equals(other.tags, tags) &&
            other.heroImageUrl == heroImageUrl &&
            other.readingTimeMinutes == readingTimeMinutes &&
            other.author == author &&
            listEq.equals(other.sources, sources) &&
            other.publishAt == publishAt &&
            other.version == version &&
            other.isDeprecated == isDeprecated &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    const listEq = ListEquality<String>();
    return Object.hashAll([
      slug,
      category,
      isPublic,
      deepEq.hash(translations),
      listEq.hash(tags),
      heroImageUrl,
      readingTimeMinutes,
      author,
      listEq.hash(sources),
      publishAt,
      version,
      isDeprecated,
      createdAt,
      updatedAt,
    ]);
  }
}

enum PageType { landing, legal, help, faq, pricing, system, other }

extension PageTypeX on PageType {
  String toJson() => switch (this) {
    PageType.landing => 'landing',
    PageType.legal => 'legal',
    PageType.help => 'help',
    PageType.faq => 'faq',
    PageType.pricing => 'pricing',
    PageType.system => 'system',
    PageType.other => 'other',
  };

  static PageType fromJson(String value) {
    switch (value) {
      case 'landing':
        return PageType.landing;
      case 'legal':
        return PageType.legal;
      case 'help':
        return PageType.help;
      case 'faq':
        return PageType.faq;
      case 'pricing':
        return PageType.pricing;
      case 'system':
        return PageType.system;
      case 'other':
        return PageType.other;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported page type');
  }
}

class PageBlock {
  const PageBlock({required this.type, required this.data});

  final String type;
  final Map<String, Object?> data;

  PageBlock copyWith({String? type, Map<String, Object?>? data}) {
    return PageBlock(type: type ?? this.type, data: data ?? this.data);
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    return identical(this, other) ||
        (other is PageBlock &&
            other.type == type &&
            deepEq.equals(other.data, data));
  }

  @override
  int get hashCode =>
      Object.hash(type, const DeepCollectionEquality().hash(data));
}

class PageSeo {
  const PageSeo({this.metaTitle, this.metaDescription, this.ogImage});

  final String? metaTitle;
  final String? metaDescription;
  final String? ogImage;

  PageSeo copyWith({
    String? metaTitle,
    String? metaDescription,
    String? ogImage,
  }) {
    return PageSeo(
      metaTitle: metaTitle ?? this.metaTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      ogImage: ogImage ?? this.ogImage,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PageSeo &&
            other.metaTitle == metaTitle &&
            other.metaDescription == metaDescription &&
            other.ogImage == ogImage);
  }

  @override
  int get hashCode => Object.hash(metaTitle, metaDescription, ogImage);
}

class PageTranslation {
  const PageTranslation({
    required this.title,
    this.body,
    this.blocks = const <PageBlock>[],
    this.seo,
  });

  final String title;
  final String? body;
  final List<PageBlock> blocks;
  final PageSeo? seo;

  PageTranslation copyWith({
    String? title,
    String? body,
    List<PageBlock>? blocks,
    PageSeo? seo,
  }) {
    return PageTranslation(
      title: title ?? this.title,
      body: body ?? this.body,
      blocks: blocks ?? this.blocks,
      seo: seo ?? this.seo,
    );
  }

  @override
  bool operator ==(Object other) {
    const listEq = ListEquality<PageBlock>();
    return identical(this, other) ||
        (other is PageTranslation &&
            other.title == title &&
            other.body == body &&
            listEq.equals(other.blocks, blocks) &&
            other.seo == seo);
  }

  @override
  int get hashCode => Object.hash(
    title,
    body,
    const ListEquality<PageBlock>().hash(blocks),
    seo,
  );
}

class PageContent {
  const PageContent({
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
  final Map<String, PageTranslation> translations;
  final List<String> tags;
  final int? navOrder;
  final DateTime? publishAt;
  final String? version;
  final bool isDeprecated;
  final DateTime createdAt;
  final DateTime updatedAt;

  PageContent copyWith({
    String? slug,
    PageType? type,
    bool? isPublic,
    Map<String, PageTranslation>? translations,
    List<String>? tags,
    int? navOrder,
    DateTime? publishAt,
    String? version,
    bool? isDeprecated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PageContent(
      slug: slug ?? this.slug,
      type: type ?? this.type,
      isPublic: isPublic ?? this.isPublic,
      translations: translations ?? this.translations,
      tags: tags ?? this.tags,
      navOrder: navOrder ?? this.navOrder,
      publishAt: publishAt ?? this.publishAt,
      version: version ?? this.version,
      isDeprecated: isDeprecated ?? this.isDeprecated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    const deepEq = DeepCollectionEquality();
    const listEq = ListEquality<String>();
    return identical(this, other) ||
        (other is PageContent &&
            other.slug == slug &&
            other.type == type &&
            other.isPublic == isPublic &&
            deepEq.equals(other.translations, translations) &&
            listEq.equals(other.tags, tags) &&
            other.navOrder == navOrder &&
            other.publishAt == publishAt &&
            other.version == version &&
            other.isDeprecated == isDeprecated &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode {
    const deepEq = DeepCollectionEquality();
    const listEq = ListEquality<String>();
    return Object.hashAll([
      slug,
      type,
      isPublic,
      deepEq.hash(translations),
      listEq.hash(tags),
      navOrder,
      publishAt,
      version,
      isDeprecated,
      createdAt,
      updatedAt,
    ]);
  }
}
