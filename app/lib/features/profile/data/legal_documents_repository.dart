import 'dart:async';

import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/profile/domain/legal_document.dart';
import 'package:flutter/foundation.dart';

@immutable
class LegalDocumentsResult {
  const LegalDocumentsResult({
    required this.documents,
    required this.localeTag,
    required this.fetchedAt,
    required this.fromCache,
  });

  final List<LegalDocument> documents;
  final String localeTag;
  final DateTime fetchedAt;
  final bool fromCache;
}

abstract class LegalDocumentsRepository {
  Future<LegalDocumentsResult> fetchDocuments({required String localeTag});
}

class FakeLegalDocumentsRepository implements LegalDocumentsRepository {
  FakeLegalDocumentsRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 320),
    DateTime Function()? now,
  }) : _cache = cache,
       _latency = latency,
       _now = now ?? DateTime.now {
    _documentsByLocale = {
      'en': _buildEnglishDocuments(),
      'ja': _buildJapaneseDocuments(),
    };
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;
  late final Map<String, List<LegalDocument>> _documentsByLocale;

  @override
  Future<LegalDocumentsResult> fetchDocuments({
    required String localeTag,
  }) async {
    final normalized = _normalizeLocale(localeTag);
    final cacheKey = normalized;
    final cached = await _readCache(cacheKey: cacheKey);

    try {
      await Future<void>.delayed(_latency);
      final docs = _documentsForLocale(normalized);
      final timestamp = _now();
      await _cache.writeLegalDocuments(
        CachedLegalDocumentList(
          locale: normalized,
          documents: docs.map(_cacheEntryFromDocument).toList(),
          updatedAt: timestamp,
        ),
        key: cacheKey,
      );
      return LegalDocumentsResult(
        documents: docs,
        localeTag: normalized,
        fetchedAt: timestamp,
        fromCache: false,
      );
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<LegalDocumentsResult?> _readCache({required String cacheKey}) async {
    final cache = await _cache.readLegalDocuments(key: cacheKey);
    final payload = cache.value;
    if (payload == null) {
      return null;
    }
    final docs = payload.documents
        .map(_documentFromCache)
        .toList(growable: false);
    final timestamp = payload.updatedAt ?? cache.lastUpdated ?? _now();
    return LegalDocumentsResult(
      documents: docs,
      localeTag: payload.locale,
      fetchedAt: timestamp,
      fromCache: true,
    );
  }

  List<LegalDocument> _documentsForLocale(String locale) {
    final documents = _documentsByLocale[locale];
    if (documents != null) {
      return List<LegalDocument>.unmodifiable(documents);
    }
    return List<LegalDocument>.unmodifiable(_documentsByLocale['en']!);
  }

  List<LegalDocument> _buildEnglishDocuments() {
    final now = DateTime(2024, 5, 1);
    return [
      LegalDocument(
        id: 'terms',
        slug: 'terms-of-service',
        type: LegalDocumentType.terms,
        title: 'Terms of Service',
        version: 'v2.1',
        summary:
            'Rules about account usage, eligibility, payments, deliveries, and liability.',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _englishTermsMarkdown,
        updatedAt: now,
        effectiveDate: DateTime(2024, 4, 20),
        shareUrl: 'https://hanko-field.app/legal/terms-of-service',
        downloadUrl: 'https://downloads.hanko-field.com/legal/terms-v2.1.pdf',
      ),
      LegalDocument(
        id: 'privacy',
        slug: 'privacy-policy',
        type: LegalDocumentType.privacy,
        title: 'Privacy Policy',
        version: 'v1.9',
        summary:
            'How we collect, process, and store personal information with regional controls.',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _englishPrivacyMarkdown,
        updatedAt: now.subtract(const Duration(days: 10)),
        effectiveDate: DateTime(2024, 3, 1),
        shareUrl: 'https://hanko-field.app/legal/privacy-policy',
        downloadUrl: 'https://downloads.hanko-field.com/legal/privacy-v1.9.pdf',
      ),
      LegalDocument(
        id: 'commercial-act',
        slug: 'specified-commercial-transactions',
        type: LegalDocumentType.commercial,
        title: 'Specified Commercial Transactions Act Notice',
        version: 'v1.4',
        summary:
            'Seller information and statutory disclosures required for Japanese commerce.',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _englishSctaMarkdown,
        updatedAt: now.subtract(const Duration(days: 3)),
        effectiveDate: DateTime(2024, 5, 1),
        shareUrl:
            'https://hanko-field.app/legal/specified-commercial-transactions',
        downloadUrl:
            'https://downloads.hanko-field.com/legal/scta-notice-v1.4.pdf',
      ),
    ];
  }

  List<LegalDocument> _buildJapaneseDocuments() {
    final now = DateTime(2024, 5, 1);
    return [
      LegalDocument(
        id: 'terms',
        slug: 'terms-of-service',
        type: LegalDocumentType.terms,
        title: '利用規約',
        version: '第2.1版',
        summary: 'アカウント、料金、配送、免責に関する基本ルールです。',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _japaneseTermsMarkdown,
        updatedAt: now,
        effectiveDate: DateTime(2024, 4, 20),
        shareUrl: 'https://hanko-field.app/ja/legal/terms-of-service',
        downloadUrl:
            'https://downloads.hanko-field.com/legal/terms-v2.1-ja.pdf',
      ),
      LegalDocument(
        id: 'privacy',
        slug: 'privacy-policy',
        type: LegalDocumentType.privacy,
        title: 'プライバシーポリシー',
        version: '第1.9版',
        summary: '取得する個人データと利用目的、第三者提供、越境移転について記載しています。',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _japanesePrivacyMarkdown,
        updatedAt: now.subtract(const Duration(days: 7)),
        effectiveDate: DateTime(2024, 3, 1),
        shareUrl: 'https://hanko-field.app/ja/legal/privacy-policy',
        downloadUrl:
            'https://downloads.hanko-field.com/legal/privacy-v1.9-ja.pdf',
      ),
      LegalDocument(
        id: 'commercial-act',
        slug: 'specified-commercial-transactions',
        type: LegalDocumentType.commercial,
        title: '特定商取引法に基づく表記',
        version: '第1.4版',
        summary: '販売業者や連絡先、支払方法、返品特約などを明記しています。',
        bodyFormat: LegalDocumentBodyFormat.markdown,
        body: _japaneseSctaMarkdown,
        updatedAt: now.subtract(const Duration(days: 2)),
        effectiveDate: DateTime(2024, 5, 1),
        shareUrl:
            'https://hanko-field.app/ja/legal/specified-commercial-transactions',
        downloadUrl:
            'https://downloads.hanko-field.com/legal/scta-notice-v1.4-ja.pdf',
      ),
    ];
  }

  CachedLegalDocumentEntry _cacheEntryFromDocument(LegalDocument doc) {
    return CachedLegalDocumentEntry(
      id: doc.id,
      slug: doc.slug,
      type: doc.type.name,
      title: doc.title,
      version: doc.version,
      body: doc.body,
      bodyFormat: doc.bodyFormat.name,
      summary: doc.summary,
      effectiveDate: doc.effectiveDate,
      updatedAt: doc.updatedAt,
      shareUrl: doc.shareUrl,
      downloadUrl: doc.downloadUrl,
    );
  }

  LegalDocument _documentFromCache(CachedLegalDocumentEntry entry) {
    return LegalDocument(
      id: entry.id,
      slug: entry.slug,
      type: _parseType(entry.type),
      title: entry.title,
      version: entry.version,
      body: entry.body,
      bodyFormat: _parseBodyFormat(entry.bodyFormat),
      summary: entry.summary,
      effectiveDate: entry.effectiveDate,
      updatedAt: entry.updatedAt ?? _now(),
      shareUrl: entry.shareUrl,
      downloadUrl: entry.downloadUrl,
    );
  }

  LegalDocumentType _parseType(String raw) {
    return LegalDocumentType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => LegalDocumentType.terms,
    );
  }

  LegalDocumentBodyFormat _parseBodyFormat(String raw) {
    return LegalDocumentBodyFormat.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => LegalDocumentBodyFormat.markdown,
    );
  }

  String _normalizeLocale(String localeTag) {
    final lower = localeTag.toLowerCase();
    if (lower.startsWith('ja')) {
      return 'ja';
    }
    return 'en';
  }
}

const String _englishTermsMarkdown = '''
# Hanko Field Terms of Service

## 1. Eligibility and account usage
- You must be at least 16 years old and capable of entering a contract.
- Corporate accounts must have a verified administrator.
- We may suspend accounts that violate usage limits or appear fraudulent.

## 2. Payments and renewals
- Prices are displayed in the currency selected in the profile tab.
- Orders ship only after payment confirmation; partial refunds follow the same method.
- Subscriptions renew automatically unless cancelled 24 hours before renewal time.

## 3. Deliveries and cancellations
- Physical seals ship from our Tokyo studio with tracking numbers.
- Digital exports remain available for 30 days after delivery.
- You may cancel unfinished orders through the Orders tab; completed orders follow the return policy.

## 4. Liability
- We provide designs “as is” and recommend verifying requirements with your local authority.
- Our maximum liability is limited to the amount paid for the product or service.

## 5. Contact
- Email: support@hanko-field.com
- Phone: +81-3-1234-5678 (weekdays 10:00-17:00 JST)
''';

const String _englishPrivacyMarkdown = '''
# Privacy Policy

### Data we collect
- Account details: name, email, authentication IDs.
- Design content: kanji selections, engraving notes, export history.
- Device signals: app version, locale, crash diagnostics.

### How we use the data
1. Deliver products, manage orders, and notify you about progress.
2. Improve guidance, such as kanji recommendations or tutorial ordering.
3. Respect legal obligations like bookkeeping and anti-abuse monitoring.

### Your controls
- Switch persona and locale without deleting history.
- Download your full profile data from `/profile/export`.
- Request deletion at `/profile/delete`; we respond within 30 days.
''';

const String _englishSctaMarkdown = '''
# Specified Commercial Transactions Act Notice

| Item | Details |
| --- | --- |
| Seller | Hanko Field Co., Ltd. |
| Responsible manager | Kazue Tanaka |
| Address | 2-10-12 Nihonbashi, Chuo-ku, Tokyo 103-0027, Japan |
| Phone | 03-1234-5678 (weekdays 10:00-17:00) |
| Email | support@hanko-field.com |
| Product price | Displayed per item (tax included) |
| Additional fees | Shipping (from ¥500), customs duties for international orders |
| Payment methods | Credit card, convenience store payment, bank transfer |
| Delivery timing | Ships within 7 business days after design approval |
| Returns | Accepted within 7 days for unused products; custom items are non-refundable unless defective |
''';

const String _japaneseTermsMarkdown = '''
# 利用規約

## 第1条（適用）
本規約は、Hanko Field（以下「当社」）が提供するアプリ・サービスの利用条件を定めるものです。

## 第2条（アカウント）
- 16歳未満の方は保護者の同意が必要です。
- 法人アカウントは管理者を登録し、権限を適切に管理してください。

## 第3条（料金と支払）
- 料金はプロフィールで選択した通貨で表示・決済されます。
- キャンセルは制作開始前まで可能です。制作後の返金は実費を控除します。

## 第4条（配送）
- 物理商品は東京都中央区のアトリエから発送し、追跡番号を通知します。
- デジタルデータは納品後30日間ダウンロードできます。

## 第5条（免責）
- 登録可能性や法的効力について当社は保証しません。ご自身で確認してください。
- 当社の責任はお客様が支払った金額を上限とします。
''';

const String _japanesePrivacyMarkdown = '''
# プライバシーポリシー

### 取得する情報
- 氏名・メールアドレスなどの登録情報
- 設計データ、漢字の選択履歴、エクスポートログ
- 端末情報（OS、アプリバージョン、クラッシュレポート）

### 利用目的
1. 商品提供、発送、サポート対応
2. 文化ガイドやおすすめテンプレートの最適化
3. 法令に基づく記帳、濫用防止

### 権利の行使
- `/profile/export` からデータコピーを取得可能
- `/profile/delete` より削除を申請すると30日以内に対応
- 通知やプロモーション設定は `/profile/notifications` で変更
''';

const String _japaneseSctaMarkdown = '''
# 特定商取引法に基づく表記

| 項目 | 内容 |
| --- | --- |
| 販売業者 | 株式会社Hanko Field |
| 運営責任者 | 田中 和恵 |
| 所在地 | 〒103-0027 東京都中央区日本橋2-10-12 |
| 連絡先 | 03-1234-5678（平日10:00〜17:00） / support@hanko-field.com |
| 商品代金 | 各商品ページに税込表示 |
| 付帯費用 | 送料（国内500円〜）、国外は関税・通関手数料 |
| 支払方法 | クレジットカード、コンビニ決済、銀行振込 |
| 引渡時期 | デザイン確定後7営業日以内に発送 |
| 返品 | 受取後7日以内（オーダーメイド品は不良品のみ対応） |
''';
