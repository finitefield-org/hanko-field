import 'dart:async';

import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/support_faq/data/support_faq_repository.dart';
import 'package:app/features/support_faq/domain/support_faq.dart';

class FakeSupportFaqRepository implements SupportFaqRepository {
  FakeSupportFaqRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 240),
    DateTime Function()? now,
  }) : _cache = cache,
       _latency = latency,
       _now = now ?? DateTime.now {
    _categories = _buildCategorySeeds();
    _entries = _buildEntrySeeds();
    _entryMap = {for (final entry in _entries) entry.id: entry};
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;
  final DateTime Function() _now;
  late final List<_FaqCategorySeed> _categories;
  late final List<_FaqEntrySeed> _entries;
  late final Map<String, _FaqEntrySeed> _entryMap;

  @override
  Future<FaqContentResult> fetchFaqs(FaqContentRequest request) async {
    final cacheKey = _cacheKey(request);
    final cached = await _readCache(cacheKey: cacheKey, request: request);
    try {
      await Future<void>.delayed(_latency);
      final locale = _normalizeLocale(request.localeTag);
      final categories = _categories
          .map((seed) => seed.toDomain(locale))
          .toList(growable: false);
      final entries = _entriesForRequest(request, locale);
      final suggestions = _buildSuggestions(entries);
      final timestamp = _now();
      await _cache.writeFaqSnapshot(
        CachedFaqSnapshot(
          categories: categories.map(_cacheCategoryFromDomain).toList(),
          entries: entries.map(_cacheEntryFromDomain).toList(),
          suggestions: suggestions,
          locale: locale,
          updatedAt: timestamp,
        ),
        key: cacheKey,
      );
      return FaqContentResult(
        categories: categories,
        entries: entries,
        suggestions: suggestions,
        fetchedAt: timestamp,
        localeTag: locale,
        fromCache: false,
      );
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<FaqEntry> submitFeedback(FaqFeedbackRequest request) async {
    final entry = _entryMap[request.entryId];
    if (entry == null) {
      throw StateError('FAQ entry not found: ${request.entryId}');
    }
    await Future<void>.delayed(_latency ~/ 2);
    switch (request.choice) {
      case FaqFeedbackChoice.helpful:
        entry.helpfulCount++;
        break;
      case FaqFeedbackChoice.unhelpful:
        entry.notHelpfulCount++;
        break;
    }
    final locale = _normalizeLocale(request.localeTag);
    return entry.toDomain(locale);
  }

  Future<FaqContentResult?> _readCache({
    required String cacheKey,
    required FaqContentRequest request,
  }) async {
    final snapshot = await _cache.readFaqSnapshot(key: cacheKey);
    final payload = snapshot.value;
    if (payload == null) {
      return null;
    }
    final categories = payload.categories
        .map(_categoryFromCache)
        .toList(growable: false);
    final entries = payload.entries
        .map(_entryFromCache)
        .toList(growable: false);
    final timestamp = payload.updatedAt ?? snapshot.lastUpdated ?? _now();
    return FaqContentResult(
      categories: categories,
      entries: entries,
      suggestions: payload.suggestions,
      fetchedAt: timestamp,
      localeTag: payload.locale ?? request.localeTag,
      fromCache: true,
    );
  }

  List<FaqEntry> _entriesForRequest(FaqContentRequest request, String locale) {
    return _entries
        .where((entry) => entry.matchesPersona(request.persona))
        .map((entry) => entry.toDomain(locale))
        .toList(growable: false);
  }

  List<String> _buildSuggestions(List<FaqEntry> entries) {
    final counts = <String, _SuggestionCount>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        final normalized = tag.toLowerCase();
        final aggregate = counts.putIfAbsent(
          normalized,
          () => _SuggestionCount(label: tag),
        );
        aggregate.count++;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final diff = b.value.count.compareTo(a.value.count);
        if (diff != 0) {
          return diff;
        }
        return a.value.label.compareTo(b.value.label);
      });
    return sorted.map((entry) => entry.value.label).take(8).toList();
  }

  String _cacheKey(FaqContentRequest request) {
    final locale = _normalizeLocale(request.localeTag);
    return 'faq-$locale-${request.persona.name}';
  }

  String _normalizeLocale(String localeTag) {
    final normalized = localeTag.toLowerCase();
    if (normalized.startsWith('ja')) {
      return 'ja';
    }
    return 'en';
  }

  CachedFaqCategory _cacheCategoryFromDomain(FaqCategory category) {
    return CachedFaqCategory(
      id: category.id,
      title: category.title,
      description: category.description,
      icon: category.icon.name,
      highlight: category.highlight,
    );
  }

  CachedFaqEntry _cacheEntryFromDomain(FaqEntry entry) {
    return CachedFaqEntry(
      id: entry.id,
      categoryId: entry.categoryId,
      question: entry.question,
      answer: entry.answer,
      tags: entry.tags,
      updatedAt: entry.updatedAt,
      helpfulCount: entry.helpfulCount,
      notHelpfulCount: entry.notHelpfulCount,
      relatedLink: entry.relatedLink?.toString(),
    );
  }

  FaqCategory _categoryFromCache(CachedFaqCategory cached) {
    final icon = FaqCategoryIcon.values.firstWhere(
      (value) => value.name == cached.icon,
      orElse: () => FaqCategoryIcon.sparkles,
    );
    return FaqCategory(
      id: cached.id,
      title: cached.title,
      description: cached.description,
      highlight: cached.highlight,
      icon: icon,
    );
  }

  FaqEntry _entryFromCache(CachedFaqEntry cached) {
    return FaqEntry(
      id: cached.id,
      categoryId: cached.categoryId,
      question: cached.question,
      answer: cached.answer,
      tags: cached.tags,
      updatedAt: cached.updatedAt ?? _now(),
      helpfulCount: cached.helpfulCount ?? 0,
      notHelpfulCount: cached.notHelpfulCount ?? 0,
      relatedLink: cached.relatedLink == null
          ? null
          : Uri.tryParse(cached.relatedLink!),
    );
  }

  List<_FaqCategorySeed> _buildCategorySeeds() {
    return [
      _FaqCategorySeed(
        id: 'setup',
        icon: FaqCategoryIcon.account,
        title: {'en': 'Account & setup', 'ja': 'アカウント・セットアップ'},
        description: {
          'en': 'Sign-in methods, passkeys, and localization settings.',
          'ja': 'サインイン方法、パスキー、言語設定に関する案内。',
        },
        highlight: {
          'en': 'Passwords, passkeys, and security',
          'ja': 'パスワードやセキュリティの基本',
        },
      ),
      _FaqCategorySeed(
        id: 'orders',
        icon: FaqCategoryIcon.status,
        title: {'en': 'Orders & production', 'ja': '注文・制作'},
        description: {
          'en': 'Proof approvals, revisions, and production status.',
          'ja': '校正、修正回数、制作状況について。',
        },
        highlight: {'en': 'Proofing timeline', 'ja': '校正の流れ'},
      ),
      _FaqCategorySeed(
        id: 'shipping',
        icon: FaqCategoryIcon.shipping,
        title: {'en': 'Shipping & tracking', 'ja': '配送・トラッキング'},
        description: {
          'en': 'Delivery estimates, customs forms, and address changes.',
          'ja': '配送目安、通関、住所変更の手順。',
        },
        highlight: {'en': 'Tracking and notifications', 'ja': '追跡と通知'},
      ),
      _FaqCategorySeed(
        id: 'billing',
        icon: FaqCategoryIcon.billing,
        title: {'en': 'Billing & payments', 'ja': '請求・支払い'},
        description: {
          'en': 'Invoices, receipts, and split payments.',
          'ja': '請求書、領収書、分割支払いの管理。',
        },
        highlight: {'en': 'Invoices & receipts', 'ja': '請求管理'},
      ),
      _FaqCategorySeed(
        id: 'ai',
        icon: FaqCategoryIcon.ai,
        title: {'en': 'AI & suggestions', 'ja': 'AI・提案'},
        description: {
          'en': 'Tuning automated kanji suggestions and offline behavior.',
          'ja': 'AI漢字提案の調整やオフライン時の挙動。',
        },
        highlight: {'en': 'Guided refinement', 'ja': 'AIの活用'},
      ),
    ];
  }

  List<_FaqEntrySeed> _buildEntrySeeds() {
    final now = _now();
    return [
      _FaqEntrySeed(
        id: 'reset-passkey',
        categoryId: 'setup',
        question: {
          'en': 'How do I reset my password or passkey?',
          'ja': 'パスワード/パスキーをリセットするには？',
        },
        answer: {
          'en':
              'Open Profile ▸ Security ▸ Credentials. Choose “Reset password” to receive a one-time link, or select “Reset passkey” to revoke trusted devices. We recommend setting a new passkey immediately after resetting to keep biometric sign-in available.',
          'ja':
              '「プロフィール ▸ セキュリティ ▸ 認証情報」を開き、「パスワードをリセット」を選ぶとワンタイムリンクが届きます。「パスキーをリセット」を選ぶと登録済みデバイスが無効化されるため、リセット後すぐに新しいパスキーを登録してください。',
        },
        tagsByLocale: {
          'en': ['password', 'passkey', 'login'],
          'ja': ['パスワード', 'パスキー', 'ログイン'],
        },
        updatedAt: now.subtract(const Duration(days: 1)),
        helpfulCount: 42,
        notHelpfulCount: 2,
        relatedLink: Uri.parse(
          'https://support.hanko-field.com/articles/reset-passkey',
        ),
      ),
      _FaqEntrySeed(
        id: 'two-factor',
        categoryId: 'setup',
        question: {
          'en': 'Can I enforce two-factor authentication for my workspace?',
          'ja': 'ワークスペース全体で二要素認証を必須にできますか？',
        },
        answer: {
          'en':
              'Workspace owners can toggle “Require 2FA” under Profile ▸ Security ▸ Enforcement. The setting applies to all members after a 6-hour grace period. During the grace period the app nudges members to register SMS, authenticator apps, or hardware keys.',
          'ja':
              'プロフィール ▸ セキュリティ ▸ 強制設定 から「二要素認証を必須」に切り替えると、6時間の猶予後に全メンバーへ適用されます。猶予中はSMS・認証アプリ・ハードウェアキーのいずれかの登録を促す通知が送られます。',
        },
        tagsByLocale: {
          'en': ['2FA', 'security', 'workspace'],
          'ja': ['二要素認証', 'セキュリティ', 'ワークスペース'],
        },
        updatedAt: now.subtract(const Duration(days: 3)),
        helpfulCount: 31,
        notHelpfulCount: 1,
      ),
      _FaqEntrySeed(
        id: 'proof-iterations',
        categoryId: 'orders',
        question: {
          'en': 'How many proof iterations are included?',
          'ja': '校正は何回まで含まれますか？',
        },
        answer: {
          'en':
              'Every order includes three complimentary proof rounds. Additional rounds are available as “Priority tweaks” with a guaranteed 12-hour turnaround. Tip: flag major layout concerns in the first response so the artisan can batch adjustments.',
          'ja':
              '各注文には3回までの無料校正が含まれます。追加が必要な場合は「優先調整」を購入すると最長12時間で反映されます。初回返信で大きなレイアウト変更点をまとめて伝えると職人が効率よく調整できます。',
        },
        tagsByLocale: {
          'en': ['proof', 'revision', 'order'],
          'ja': ['校正', '修正', '注文'],
        },
        updatedAt: now.subtract(const Duration(days: 2)),
        helpfulCount: 27,
        notHelpfulCount: 0,
        relatedLink: Uri.parse(
          'https://support.hanko-field.com/articles/proof-iterations',
        ),
      ),
      _FaqEntrySeed(
        id: 'production-window',
        categoryId: 'orders',
        question: {
          'en': 'What is the typical production window?',
          'ja': '制作期間の目安はどれくらいですか？',
        },
        answer: {
          'en':
              'Once the final proof is approved, production starts within 4 business hours. Standard materials ship in 5–7 business days; rare materials may take up to 12 days. Track real-time progress from Orders ▸ Detail ▸ Production tab.',
          'ja':
              '最終校正の承認から4営業時間以内に制作が開始されます。標準素材は5〜7営業日で出荷、希少素材は最大12日かかる場合があります。アプリの「注文 ▸ 詳細 ▸ 制作」タブでリアルタイム進捗を確認できます。',
        },
        tagsByLocale: {
          'en': ['production', 'timeline', 'status'],
          'ja': ['制作', 'スケジュール', '進捗'],
        },
        updatedAt: now.subtract(const Duration(days: 4)),
        helpfulCount: 19,
        notHelpfulCount: 3,
      ),
      _FaqEntrySeed(
        id: 'shipping-tracking',
        categoryId: 'shipping',
        question: {
          'en': 'When do I receive tracking information?',
          'ja': '追跡番号はいつ発行されますか？',
        },
        answer: {
          'en':
              'Tracking numbers are generated immediately after the quality check scan. You will see push, SMS, and email notifications with the carrier link. International orders gain a secondary Japan Post or Yamato number once exports clear customs.',
          'ja':
              '品質検査のスキャン完了直後に追跡番号が発行され、プッシュ通知・SMS・メールでキャリアリンクが届きます。海外発送分は通関完了後に日本郵便またはヤマトのサブ番号も付与されます。',
        },
        tagsByLocale: {
          'en': ['tracking', 'notifications', 'delivery'],
          'ja': ['追跡', '通知', '配送'],
        },
        updatedAt: now.subtract(const Duration(days: 5)),
        helpfulCount: 24,
        notHelpfulCount: 2,
      ),
      _FaqEntrySeed(
        id: 'address-change',
        categoryId: 'shipping',
        question: {
          'en': 'How do I change the shipping address after ordering?',
          'ja': '注文後に配送先を変更するには？',
        },
        answer: {
          'en':
              'Open the order detail and tap “Request change” in the shipping section. Changes are instant before pickup and best-effort (handled by the carrier) once a label is printed. For urgent reroutes call the concierge line shown in the request sheet.',
          'ja':
              '注文詳細の「配送」セクションで「変更を依頼」を押すと、集荷前であれば即時反映されます。ラベル印刷後はキャリア側での対応となるため、緊急の場合は依頼モーダルに表示される専用番号へお電話ください。',
        },
        tagsByLocale: {
          'en': ['address change', 'shipping', 'support'],
          'ja': ['住所変更', '配送', 'サポート'],
        },
        updatedAt: now.subtract(const Duration(days: 6)),
        helpfulCount: 13,
        notHelpfulCount: 4,
      ),
      _FaqEntrySeed(
        id: 'billing-receipts',
        categoryId: 'billing',
        question: {
          'en': 'Where can I download receipts and tax invoices?',
          'ja': '領収書や請求書はどこでダウンロードできますか？',
        },
        answer: {
          'en':
              'Go to Profile ▸ Billing ▸ Documents. Each order generates a receipt, invoice (with invoice number and tax ID), and CSV export. Toggle “Auto-send to accounting inbox” to email every update to your finance system.',
          'ja':
              '「プロフィール ▸ 請求 ▸ ドキュメント」にアクセスすると、領収書・適格請求書・CSVを注文ごとにダウンロードできます。「会計担当へ自動送信」をオンにすると更新の度に指定メールへ転送されます。',
        },
        tagsByLocale: {
          'en': ['invoice', 'receipt', 'billing'],
          'ja': ['請求書', '領収書', '請求'],
        },
        updatedAt: now.subtract(const Duration(days: 8)),
        helpfulCount: 36,
        notHelpfulCount: 1,
      ),
      _FaqEntrySeed(
        id: 'split-payment',
        categoryId: 'billing',
        question: {
          'en': 'Can I split payments between a deposit and final charge?',
          'ja': '着手金と残額に分けて支払えますか？',
        },
        answer: {
          'en':
              'Yes. Choose “Split payment” at checkout or from the invoice screen. Deposits are collected immediately while final charges trigger automatically when the shipping label is created. You can assign different payment methods to each portion.',
          'ja':
              '可能です。チェックアウト時または請求画面で「分割支払い」を選択すると、着手金は即時決済、残額は発送ラベル確定時に自動決済されます。各支払いに別の決済方法を指定することもできます。',
        },
        tagsByLocale: {
          'en': ['split payment', 'deposit', 'billing'],
          'ja': ['分割払い', '着手金', '請求'],
        },
        personaTargets: const ['japanese'],
        updatedAt: now.subtract(const Duration(days: 7)),
        helpfulCount: 15,
        notHelpfulCount: 3,
      ),
      _FaqEntrySeed(
        id: 'ai-conflicts',
        categoryId: 'ai',
        question: {
          'en': 'How do I handle AI suggestions that conflict with branding?',
          'ja': 'AI提案がブランドガイドラインと合わない場合は？',
        },
        answer: {
          'en':
              'From any AI preview, tap “Adjust tone” and upload your brand sheet or choose a saved preset. The assistant re-ranks kanji strokes, spacing, and engraving depth to match your constraints. You can also lock glyphs so that only layout changes in later suggestions.',
          'ja':
              'AIプレビュー画面の「トーン調整」からブランドガイドラインをアップロードするかプリセットを選択すると、筆致・余白・彫刻の深さを制約内で再提案します。特定の字形をロックして、以降は配置のみ変更させることも可能です。',
        },
        tagsByLocale: {
          'en': ['AI', 'brand', 'suggestions'],
          'ja': ['AI', 'ブランド', '提案'],
        },
        updatedAt: now.subtract(const Duration(days: 2)),
        helpfulCount: 29,
        notHelpfulCount: 2,
      ),
      _FaqEntrySeed(
        id: 'ai-offline',
        categoryId: 'ai',
        question: {
          'en': 'Does the AI assistant work offline?',
          'ja': 'AIアシスタントはオフラインでも使えますか？',
        },
        answer: {
          'en':
              'Yes, recent suggestions are cached for 30 days. While offline you can re-open saved kanji mappings, tweak layout, and export to AR preview. Generating brand-new suggestions requires connectivity, but the app queues the request and syncs once you regain a signal.',
          'ja':
              'はい。直近30日間の提案は端末にキャッシュされ、オフラインでも再表示やレイアウト調整、ARプレビュー出力が可能です。完全に新しい提案の生成はオンライン接続が必要ですが、リクエストはキューに入り復帰後に自動同期されます。',
        },
        tagsByLocale: {
          'en': ['offline', 'AI', 'cache'],
          'ja': ['オフライン', 'AI', 'キャッシュ'],
        },
        updatedAt: now.subtract(const Duration(days: 9)),
        helpfulCount: 33,
        notHelpfulCount: 5,
      ),
    ];
  }
}

class _FaqCategorySeed {
  _FaqCategorySeed({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    this.highlight,
  });

  final String id;
  final FaqCategoryIcon icon;
  final Map<String, String> title;
  final Map<String, String> description;
  final Map<String, String>? highlight;

  FaqCategory toDomain(String locale) {
    final resolved = title[locale] ?? title['en'] ?? title.values.first;
    final resolvedDescription =
        description[locale] ?? description['en'] ?? description.values.first;
    final resolvedHighlight = highlight == null
        ? null
        : highlight![locale] ?? highlight!['en'] ?? highlight!.values.first;
    return FaqCategory(
      id: id,
      title: resolved,
      description: resolvedDescription,
      highlight: resolvedHighlight,
      icon: icon,
    );
  }
}

class _FaqEntrySeed {
  _FaqEntrySeed({
    required this.id,
    required this.categoryId,
    required this.question,
    required this.answer,
    required this.tagsByLocale,
    required this.updatedAt,
    this.relatedLink,
    this.personaTargets = const [],
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
  });

  final String id;
  final String categoryId;
  final Map<String, String> question;
  final Map<String, String> answer;
  final Map<String, List<String>> tagsByLocale;
  final DateTime updatedAt;
  final Uri? relatedLink;
  final List<String> personaTargets;
  int helpfulCount;
  int notHelpfulCount;

  bool matchesPersona(UserPersona persona) {
    if (personaTargets.isEmpty) {
      return true;
    }
    final personaKey = persona.name;
    return personaTargets.contains(personaKey);
  }

  FaqEntry toDomain(String locale) {
    final resolvedQuestion =
        question[locale] ?? question['en'] ?? question.values.first;
    final resolvedAnswer =
        answer[locale] ?? answer['en'] ?? answer.values.first;
    final tags =
        tagsByLocale[locale] ?? tagsByLocale['en'] ?? tagsByLocale.values.first;
    return FaqEntry(
      id: id,
      categoryId: categoryId,
      question: resolvedQuestion,
      answer: resolvedAnswer,
      tags: tags,
      updatedAt: updatedAt,
      helpfulCount: helpfulCount,
      notHelpfulCount: notHelpfulCount,
      relatedLink: relatedLink,
    );
  }
}

class _SuggestionCount {
  _SuggestionCount({required this.label});
  final String label;
  int count = 0;
}
