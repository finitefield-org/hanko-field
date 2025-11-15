import 'package:app/core/data/dtos/design_dto.dart';
import 'package:app/core/data/dtos/order_dto.dart';
import 'package:app/core/storage/cache_bucket.dart';
import 'package:app/core/storage/cache_policy.dart';
import 'package:app/core/storage/local_cache_store.dart';
import 'package:app/features/design_creation/domain/kanji_candidate.dart';
import 'package:app/features/design_creation/domain/registrability_check.dart';

const Object _cartSnapshotSentinel = Object();

class OfflineCacheRepository {
  OfflineCacheRepository(this._store);

  final LocalCacheStore _store;

  Future<CacheReadResult<CachedDesignList>> readDesignList({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.designs,
      key: key,
      decoder: (data) => CachedDesignList.fromJson(_asJson(data)),
    );
  }

  Future<void> writeDesignList(
    CachedDesignList payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.designs,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedOrderList>> readOrders({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.orders,
      key: key,
      decoder: (data) => CachedOrderList.fromJson(_asJson(data)),
    );
  }

  Future<void> writeOrders(
    CachedOrderList payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.orders,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedCartSnapshot>> readCart() {
    return _store.read(
      bucket: CacheBucket.cart,
      decoder: (data) => CachedCartSnapshot.fromJson(_asJson(data)),
    );
  }

  Future<void> writeCart(CachedCartSnapshot payload) {
    return _store.write(
      bucket: CacheBucket.cart,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedGuideList>> readGuides({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.guides,
      key: key,
      decoder: (data) => CachedGuideList.fromJson(_asJson(data)),
    );
  }

  Future<void> writeGuides(
    CachedGuideList payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.guides,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedFaqSnapshot>> readFaqSnapshot({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.support,
      key: key,
      decoder: (data) => CachedFaqSnapshot.fromJson(_asJson(data)),
    );
  }

  Future<void> writeFaqSnapshot(
    CachedFaqSnapshot payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.support,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedGuideDetail>> readGuideDetail({
    required String key,
  }) {
    return _store.read(
      bucket: CacheBucket.guides,
      key: key,
      decoder: (data) => CachedGuideDetail.fromJson(_asJson(data)),
    );
  }

  Future<void> writeGuideDetail(
    CachedGuideDetail payload, {
    required String key,
  }) {
    return _store.write(
      bucket: CacheBucket.guides,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedLegalDocumentList>> readLegalDocuments({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.legalDocuments,
      key: key,
      decoder: (data) => CachedLegalDocumentList.fromJson(_asJson(data)),
    );
  }

  Future<void> writeLegalDocuments(
    CachedLegalDocumentList payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.legalDocuments,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<KanjiCandidateResponse>> readKanjiCandidates({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.kanjiCandidates,
      key: key,
      decoder: (data) =>
          KanjiCandidateResponse.fromSerializableMap(_asJson(data)),
    );
  }

  Future<void> writeKanjiCandidates(
    KanjiCandidateResponse response, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.kanjiCandidates,
      key: key,
      encoder: (value) => value.toSerializableMap(),
      value: response,
    );
  }

  Future<CacheReadResult<Set<String>>> readKanjiBookmarks() {
    return _store.read(
      bucket: CacheBucket.kanjiCandidates,
      key: 'bookmarks',
      decoder: (data) => Set<String>.from(List<dynamic>.from(data as List)),
    );
  }

  Future<void> writeKanjiBookmarks(Set<String> bookmarks) {
    return _store.write(
      bucket: CacheBucket.kanjiCandidates,
      key: 'bookmarks',
      encoder: (value) => value.toList()..sort(),
      value: bookmarks,
    );
  }

  Future<CacheReadResult<List<String>>> readKanjiSearchHistory() {
    return _store.read(
      bucket: CacheBucket.kanjiCandidates,
      key: 'searchHistory',
      decoder: (data) => List<String>.from(List<dynamic>.from(data as List)),
    );
  }

  Future<void> writeKanjiSearchHistory(List<String> history) {
    return _store.write(
      bucket: CacheBucket.kanjiCandidates,
      key: 'searchHistory',
      encoder: (value) => value,
      value: history,
    );
  }

  Future<CacheReadResult<List<String>>> readKanjiViewedEntries() {
    return _store.read(
      bucket: CacheBucket.kanjiCandidates,
      key: 'viewedEntries',
      decoder: (data) => List<String>.from(List<dynamic>.from(data as List)),
    );
  }

  Future<void> writeKanjiViewedEntries(List<String> entryIds) {
    return _store.write(
      bucket: CacheBucket.kanjiCandidates,
      key: 'viewedEntries',
      encoder: (value) => value,
      value: entryIds,
    );
  }

  Future<CacheReadResult<Set<String>>> readHowToCompletions() {
    return _store.read(
      bucket: CacheBucket.learning,
      key: 'howto.completions',
      decoder: (data) => Set<String>.from(List<dynamic>.from(data as List)),
    );
  }

  Future<void> writeHowToCompletions(Set<String> tutorialIds) {
    return _store.write(
      bucket: CacheBucket.learning,
      key: 'howto.completions',
      encoder: (value) => value.toList()..sort(),
      value: tutorialIds,
    );
  }

  Future<CacheReadResult<RegistrabilityCheckSnapshot>> readRegistrabilityCheck({
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.read(
      bucket: CacheBucket.registrability,
      key: key,
      decoder: (data) => RegistrabilityCheckSnapshot.fromJson(_asJson(data)),
    );
  }

  Future<void> writeRegistrabilityCheck(
    RegistrabilityCheckSnapshot payload, {
    String key = LocalCacheStore.defaultEntryKey,
  }) {
    return _store.write(
      bucket: CacheBucket.registrability,
      key: key,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<CachedNotificationsSnapshot>> readNotifications() {
    return _store.read(
      bucket: CacheBucket.notifications,
      decoder: (data) => CachedNotificationsSnapshot.fromJson(_asJson(data)),
    );
  }

  Future<void> writeNotifications(CachedNotificationsSnapshot payload) {
    return _store.write(
      bucket: CacheBucket.notifications,
      encoder: (value) => value.toJson(),
      value: payload,
    );
  }

  Future<CacheReadResult<OnboardingFlags>> readOnboardingFlags() {
    return _store.read(
      bucket: CacheBucket.onboarding,
      decoder: (data) => OnboardingFlags.fromJson(_asJson(data)),
    );
  }

  Future<void> writeOnboardingFlags(OnboardingFlags flags) {
    return _store.write(
      bucket: CacheBucket.onboarding,
      encoder: (value) => value.toJson(),
      value: flags,
    );
  }
}

class CachedDesignList {
  CachedDesignList({
    required this.items,
    this.nextPageToken,
    this.appliedFilters,
  });

  factory CachedDesignList.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => DesignDto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return CachedDesignList(
      items: list,
      nextPageToken: json['nextPageToken'] as String?,
      appliedFilters: json['filters'] == null
          ? null
          : Map<String, dynamic>.from(json['filters'] as Map),
    );
  }

  final List<DesignDto> items;
  final String? nextPageToken;
  final Map<String, dynamic>? appliedFilters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((dto) => dto.toJson()).toList(),
      'nextPageToken': nextPageToken,
      if (appliedFilters != null) 'filters': appliedFilters,
    };
  }
}

class CachedOrderList {
  CachedOrderList({required this.items, this.appliedFilters});

  factory CachedOrderList.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => OrderDto.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    return CachedOrderList(
      items: list,
      appliedFilters: json['filters'] == null
          ? null
          : Map<String, dynamic>.from(json['filters'] as Map),
    );
  }

  final List<OrderDto> items;
  final Map<String, dynamic>? appliedFilters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((dto) => dto.toJson()).toList(),
      if (appliedFilters != null) 'filters': appliedFilters,
    };
  }
}

class CachedCartSnapshot {
  CachedCartSnapshot({
    required this.lines,
    this.currency,
    this.subtotal,
    this.total,
    this.discount,
    this.shipping,
    this.tax,
    this.promotion,
    this.updatedAt,
    this.shippingOptionId,
  });

  factory CachedCartSnapshot.fromJson(Map<String, dynamic> json) {
    return CachedCartSnapshot(
      lines: (json['lines'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (line) =>
                CartLineCache.fromJson(Map<String, dynamic>.from(line as Map)),
          )
          .toList(),
      currency: json['currency'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      discount: (json['discount'] as num?)?.toDouble(),
      shipping: (json['shipping'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      promotion: json['promotion'] == null
          ? null
          : Map<String, dynamic>.from(json['promotion'] as Map),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      shippingOptionId: json['shippingOptionId'] as String?,
    );
  }

  final List<CartLineCache> lines;
  final String? currency;
  final double? subtotal;
  final double? total;
  final double? discount;
  final double? shipping;
  final double? tax;
  final Map<String, dynamic>? promotion;
  final DateTime? updatedAt;
  final String? shippingOptionId;

  CachedCartSnapshot copyWith({
    List<CartLineCache>? lines,
    Object? currency = _cartSnapshotSentinel,
    Object? subtotal = _cartSnapshotSentinel,
    Object? total = _cartSnapshotSentinel,
    Object? discount = _cartSnapshotSentinel,
    Object? shipping = _cartSnapshotSentinel,
    Object? tax = _cartSnapshotSentinel,
    Object? promotion = _cartSnapshotSentinel,
    DateTime? updatedAt,
    Object? shippingOptionId = _cartSnapshotSentinel,
  }) {
    return CachedCartSnapshot(
      lines: lines ?? this.lines,
      currency: identical(currency, _cartSnapshotSentinel)
          ? this.currency
          : currency as String?,
      subtotal: identical(subtotal, _cartSnapshotSentinel)
          ? this.subtotal
          : subtotal as double?,
      total: identical(total, _cartSnapshotSentinel)
          ? this.total
          : total as double?,
      discount: identical(discount, _cartSnapshotSentinel)
          ? this.discount
          : discount as double?,
      shipping: identical(shipping, _cartSnapshotSentinel)
          ? this.shipping
          : shipping as double?,
      tax: identical(tax, _cartSnapshotSentinel) ? this.tax : tax as double?,
      promotion: identical(promotion, _cartSnapshotSentinel)
          ? this.promotion
          : promotion as Map<String, dynamic>?,
      updatedAt: updatedAt ?? this.updatedAt,
      shippingOptionId: identical(shippingOptionId, _cartSnapshotSentinel)
          ? this.shippingOptionId
          : shippingOptionId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lines': lines.map((line) => line.toJson()).toList(),
      'currency': currency,
      'subtotal': subtotal,
      'total': total,
      'discount': discount,
      'shipping': shipping,
      'tax': tax,
      'promotion': promotion,
      'updatedAt': updatedAt?.toIso8601String(),
      'shippingOptionId': shippingOptionId,
    };
  }
}

class CartLineCache {
  CartLineCache({
    required this.lineId,
    required this.productId,
    required this.quantity,
    this.designSnapshot,
    this.price,
    this.currency,
    this.addons,
  });

  factory CartLineCache.fromJson(Map<String, dynamic> json) {
    return CartLineCache(
      lineId: json['lineId'] as String,
      productId: json['productId'] as String,
      quantity: json['quantity'] as int,
      designSnapshot: json['designSnapshot'] == null
          ? null
          : DesignDto.fromJson(
              Map<String, dynamic>.from(json['designSnapshot'] as Map),
            ),
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      addons: json['addons'] == null
          ? null
          : Map<String, dynamic>.from(json['addons'] as Map),
    );
  }

  final String lineId;
  final String productId;
  final int quantity;
  final DesignDto? designSnapshot;
  final double? price;
  final String? currency;
  final Map<String, dynamic>? addons;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lineId': lineId,
      'productId': productId,
      'quantity': quantity,
      'designSnapshot': designSnapshot?.toJson(),
      'price': price,
      'currency': currency,
      'addons': addons,
    };
  }
}

class CachedGuideList {
  CachedGuideList({required this.guides, this.locale, this.updatedAt});

  factory CachedGuideList.fromJson(Map<String, dynamic> json) {
    final guides = (json['guides'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (guide) =>
              GuideCacheItem.fromJson(Map<String, dynamic>.from(guide as Map)),
        )
        .toList();
    return CachedGuideList(
      guides: guides,
      locale: json['locale'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  final List<GuideCacheItem> guides;
  final String? locale;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'guides': guides.map((guide) => guide.toJson()).toList(),
      'locale': locale,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class GuideCacheItem {
  GuideCacheItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.category,
    required this.locale,
    required this.featured,
    this.heroImage,
    this.readingTimeMinutes,
    List<String>? tags,
    List<String>? personaTargets,
  }) : tags = tags ?? <String>[],
       personaTargets = personaTargets ?? <String>[];

  factory GuideCacheItem.fromJson(Map<String, dynamic> json) {
    return GuideCacheItem(
      id: json['id'] as String? ?? json['slug'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      locale: json['locale'] as String? ?? 'en',
      featured: json['featured'] as bool? ?? false,
      heroImage: json['heroImage'] as String?,
      readingTimeMinutes: json['readingTimeMinutes'] as int?,
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((tag) => tag as String)
          .toList(),
      personaTargets: (json['personas'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
    );
  }

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String category;
  final String locale;
  final bool featured;
  final String? heroImage;
  final int? readingTimeMinutes;
  final List<String> tags;
  final List<String> personaTargets;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'title': title,
      'summary': summary,
      'category': category,
      'locale': locale,
      'featured': featured,
      'heroImage': heroImage,
      'readingTimeMinutes': readingTimeMinutes,
      'tags': tags,
      'personas': personaTargets,
    };
  }
}

class CachedGuideDetail {
  CachedGuideDetail({
    required this.article,
    required this.related,
    this.updatedAt,
  });

  factory CachedGuideDetail.fromJson(Map<String, dynamic> json) {
    return CachedGuideDetail(
      article: CachedGuideArticle.fromJson(
        Map<String, dynamic>.from(json['article'] as Map? ?? const {}),
      ),
      related: (json['related'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (item) =>
                GuideCacheItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  final CachedGuideArticle article;
  final List<GuideCacheItem> related;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'article': article.toJson(),
      'related': related.map((item) => item.toJson()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CachedGuideArticle {
  CachedGuideArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.body,
    required this.bodyFormat,
    required this.category,
    required this.locale,
    this.heroImage,
    this.readingTimeMinutes,
    this.authorName,
    this.authorProfileUrl,
    List<String>? tags,
    List<String>? personaTargets,
    List<String>? sources,
    this.publishAt,
    this.updatedAt,
    this.version,
    this.shareUrl,
    this.featured = false,
  }) : tags = tags ?? <String>[],
       personaTargets = personaTargets ?? <String>[],
       sources = sources ?? <String>[];

  factory CachedGuideArticle.fromJson(Map<String, dynamic> json) {
    return CachedGuideArticle(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      body: json['body'] as String? ?? '',
      bodyFormat: json['bodyFormat'] as String? ?? 'markdown',
      category: json['category'] as String? ?? 'other',
      locale: json['locale'] as String? ?? 'en',
      heroImage: json['heroImage'] as String?,
      readingTimeMinutes: json['readingTimeMinutes'] as int?,
      authorName: json['authorName'] as String?,
      authorProfileUrl: json['authorProfileUrl'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
      personaTargets: (json['personas'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
      sources: (json['sources'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
      publishAt: json['publishAt'] == null
          ? null
          : DateTime.tryParse(json['publishAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      version: json['version'] as String?,
      shareUrl: json['shareUrl'] as String?,
      featured: json['featured'] as bool? ?? false,
    );
  }

  final String id;
  final String slug;
  final String title;
  final String summary;
  final String body;
  final String bodyFormat;
  final String category;
  final String locale;
  final String? heroImage;
  final int? readingTimeMinutes;
  final String? authorName;
  final String? authorProfileUrl;
  final List<String> tags;
  final List<String> personaTargets;
  final List<String> sources;
  final DateTime? publishAt;
  final DateTime? updatedAt;
  final String? version;
  final String? shareUrl;
  final bool featured;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'title': title,
      'summary': summary,
      'body': body,
      'bodyFormat': bodyFormat,
      'category': category,
      'locale': locale,
      'heroImage': heroImage,
      'readingTimeMinutes': readingTimeMinutes,
      'authorName': authorName,
      'authorProfileUrl': authorProfileUrl,
      'tags': tags,
      'personas': personaTargets,
      'sources': sources,
      'publishAt': publishAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'version': version,
      'shareUrl': shareUrl,
      'featured': featured,
    };
  }
}

class CachedFaqSnapshot {
  CachedFaqSnapshot({
    required this.categories,
    required this.entries,
    required this.suggestions,
    this.locale,
    this.updatedAt,
  });

  factory CachedFaqSnapshot.fromJson(Map<String, dynamic> json) {
    return CachedFaqSnapshot(
      categories: (json['categories'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (value) => CachedFaqCategory.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      entries: (json['entries'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (value) => CachedFaqEntry.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      suggestions: (json['suggestions'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
      locale: json['locale'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  final List<CachedFaqCategory> categories;
  final List<CachedFaqEntry> entries;
  final List<String> suggestions;
  final String? locale;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categories': categories.map((category) => category.toJson()).toList(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'suggestions': suggestions,
      'locale': locale,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CachedFaqCategory {
  CachedFaqCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.highlight,
  });

  factory CachedFaqCategory.fromJson(Map<String, dynamic> json) {
    return CachedFaqCategory(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      highlight: json['highlight'] as String?,
    );
  }

  final String id;
  final String title;
  final String description;
  final String icon;
  final String? highlight;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'highlight': highlight,
    };
  }
}

class CachedFaqEntry {
  CachedFaqEntry({
    required this.id,
    required this.categoryId,
    required this.question,
    required this.answer,
    required this.tags,
    this.updatedAt,
    this.helpfulCount,
    this.notHelpfulCount,
    this.relatedLink,
  });

  factory CachedFaqEntry.fromJson(Map<String, dynamic> json) {
    return CachedFaqEntry(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => value as String)
          .toList(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      helpfulCount: json['helpfulCount'] as int?,
      notHelpfulCount: json['notHelpfulCount'] as int?,
      relatedLink: json['relatedLink'] as String?,
    );
  }

  final String id;
  final String categoryId;
  final String question;
  final String answer;
  final List<String> tags;
  final DateTime? updatedAt;
  final int? helpfulCount;
  final int? notHelpfulCount;
  final String? relatedLink;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'question': question,
      'answer': answer,
      'tags': tags,
      'updatedAt': updatedAt?.toIso8601String(),
      'helpfulCount': helpfulCount,
      'notHelpfulCount': notHelpfulCount,
      'relatedLink': relatedLink,
    };
  }
}

class CachedNotificationsSnapshot {
  CachedNotificationsSnapshot({
    required this.items,
    required this.unreadCount,
    this.lastSyncedAt,
  });

  factory CachedNotificationsSnapshot.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => NotificationCacheItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return CachedNotificationsSnapshot(
      items: items,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.parse(json['lastSyncedAt'] as String),
    );
  }

  final List<NotificationCacheItem> items;
  final int unreadCount;
  final DateTime? lastSyncedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'items': items.map((item) => item.toJson()).toList(),
      'unreadCount': unreadCount,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }
}

class NotificationCacheItem {
  NotificationCacheItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.deepLink,
  });

  factory NotificationCacheItem.fromJson(Map<String, dynamic> json) {
    return NotificationCacheItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
      deepLink: json['deepLink'] as String?,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final String? deepLink;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'deepLink': deepLink,
    };
  }
}

enum OnboardingStep { tutorial, locale, persona, notifications }

class OnboardingFlags {
  OnboardingFlags({
    required Map<OnboardingStep, bool> steps,
    DateTime? updatedAt,
  }) : stepCompletion = Map.unmodifiable(steps),
       updatedAt = updatedAt ?? DateTime.now();

  factory OnboardingFlags.initial() {
    return OnboardingFlags(
      steps: {for (final step in OnboardingStep.values) step: false},
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory OnboardingFlags.fromJson(Map<String, dynamic> json) {
    final rawSteps = Map<String, dynamic>.from(
      json['steps'] as Map? ?? <String, dynamic>{},
    );
    final steps = {
      for (final entry in rawSteps.entries)
        _parseStep(entry.key): entry.value as bool? ?? false,
    };
    final updatedAtRaw = json['updatedAt'] as String?;
    final updatedAt = updatedAtRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.tryParse(updatedAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0);
    return OnboardingFlags(steps: steps, updatedAt: updatedAt);
  }

  final Map<OnboardingStep, bool> stepCompletion;
  final DateTime updatedAt;

  bool get isCompleted => stepCompletion.values.every((done) => done);

  OnboardingFlags markStep(OnboardingStep step, bool completed) {
    final next = Map<OnboardingStep, bool>.from(stepCompletion)
      ..[step] = completed;
    return OnboardingFlags(steps: next, updatedAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'steps': {
        for (final entry in stepCompletion.entries)
          _stepKey(entry.key): entry.value,
      },
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String _stepKey(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.tutorial:
        return 'tutorial';
      case OnboardingStep.locale:
        return 'locale';
      case OnboardingStep.persona:
        return 'persona';
      case OnboardingStep.notifications:
        return 'notifications';
    }
  }

  static OnboardingStep _parseStep(String value) {
    switch (value) {
      case 'tutorial':
        return OnboardingStep.tutorial;
      case 'locale':
        return OnboardingStep.locale;
      case 'persona':
        return OnboardingStep.persona;
      case 'notifications':
        return OnboardingStep.notifications;
    }
    throw ArgumentError.value(value, 'value', 'Unknown onboarding step');
  }
}

class CachedLegalDocumentList {
  CachedLegalDocumentList({
    required this.locale,
    required this.documents,
    this.updatedAt,
  });

  factory CachedLegalDocumentList.fromJson(Map<String, dynamic> json) {
    return CachedLegalDocumentList(
      locale: json['locale'] as String? ?? 'en',
      documents: (json['documents'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (doc) => CachedLegalDocumentEntry.fromJson(
              Map<String, dynamic>.from(doc as Map),
            ),
          )
          .toList(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  final String locale;
  final List<CachedLegalDocumentEntry> documents;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'locale': locale,
      'documents': documents.map((doc) => doc.toJson()).toList(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CachedLegalDocumentEntry {
  CachedLegalDocumentEntry({
    required this.id,
    required this.slug,
    required this.type,
    required this.title,
    required this.version,
    required this.body,
    required this.bodyFormat,
    this.summary,
    this.effectiveDate,
    this.updatedAt,
    this.shareUrl,
    this.downloadUrl,
  });

  factory CachedLegalDocumentEntry.fromJson(Map<String, dynamic> json) {
    return CachedLegalDocumentEntry(
      id: json['id'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String? ?? 'terms',
      title: json['title'] as String,
      version: json['version'] as String? ?? '1.0.0',
      body: json['body'] as String? ?? '',
      bodyFormat: json['bodyFormat'] as String? ?? 'markdown',
      summary: json['summary'] as String?,
      effectiveDate: json['effectiveDate'] == null
          ? null
          : DateTime.tryParse(json['effectiveDate'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      shareUrl: json['shareUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
    );
  }

  final String id;
  final String slug;
  final String type;
  final String title;
  final String version;
  final String body;
  final String bodyFormat;
  final String? summary;
  final DateTime? effectiveDate;
  final DateTime? updatedAt;
  final String? shareUrl;
  final String? downloadUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'slug': slug,
      'type': type,
      'title': title,
      'version': version,
      'body': body,
      'bodyFormat': bodyFormat,
      'summary': summary,
      'effectiveDate': effectiveDate?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'shareUrl': shareUrl,
      'downloadUrl': downloadUrl,
    };
  }
}

Map<String, dynamic> _asJson(Object? data) {
  return Map<String, dynamic>.from((data as Map?) ?? <String, dynamic>{});
}
