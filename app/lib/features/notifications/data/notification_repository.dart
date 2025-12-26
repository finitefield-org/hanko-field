// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/core/storage/cache_keys.dart';
import 'package:app/core/storage/local_cache.dart';
import 'package:app/core/storage/local_persistence_providers.dart';
import 'package:app/features/notifications/data/models/notification_models.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class NotificationRepository {
  static const fallback = Scope<NotificationRepository>.required(
    'notifications.repository',
  );

  Future<Page<AppNotification>> listNotifications({
    bool unreadOnly = false,
    String? pageToken,
    int pageSize = 8,
  });

  Future<int> setReadState(String notificationId, {required bool read});

  Future<int> upsertNotification(
    AppNotification notification, {
    bool markRead = false,
  });

  Future<int> markAllRead();

  Future<int> unreadCount();
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final cache = ref.watch(notificationsCacheProvider);
  final gates = ref.watch(appExperienceGatesProvider);
  final logger = Logger('NotificationRepository');

  return LocalNotificationRepository(
    cache: cache,
    gates: gates,
    logger: logger,
  );
});

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository({
    required LocalCacheStore<JsonMap> cache,
    required AppExperienceGates gates,
    Logger? logger,
  }) : _cache = cache,
       _gates = gates,
       _logger = logger ?? Logger('LocalNotificationRepository');

  final LocalCacheStore<JsonMap> _cache;
  final AppExperienceGates _gates;
  final Logger _logger;

  final Set<String> _readIds = {};
  late final LocalCacheKey _cacheKey = LocalCacheKeys.notifications(
    userId: _gates.isAuthenticated ? 'current' : 'guest',
  );

  bool _seeded = false;
  late final List<AppNotification> _baseNotifications;
  final List<AppNotification> _extraNotifications = [];
  late List<AppNotification> _notifications;

  @override
  Future<Page<AppNotification>> listNotifications({
    bool unreadOnly = false,
    String? pageToken,
    int pageSize = 8,
  }) async {
    await _ensureSeeded();
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final all = _withReadState();
    final filtered = unreadOnly ? all.where((n) => !n.read).toList() : all;

    final start = int.tryParse(pageToken ?? '') ?? 0;
    final items = filtered.skip(start).take(pageSize).toList();
    final next = start + items.length < filtered.length
        ? '${start + items.length}'
        : null;

    return Page(items: items, nextPageToken: next);
  }

  @override
  Future<int> setReadState(String notificationId, {required bool read}) async {
    await _ensureSeeded();

    if (!_containsNotificationId(notificationId)) {
      _logger.fine('Ignoring unknown notification id: $notificationId');
      return _unreadCount();
    }

    if (read) {
      _readIds.add(notificationId);
    } else {
      _readIds.remove(notificationId);
    }

    await _persist();
    return _unreadCount();
  }

  @override
  Future<int> upsertNotification(
    AppNotification notification, {
    bool markRead = false,
  }) async {
    await _ensureSeeded();

    _baseNotifications.removeWhere((item) => item.id == notification.id);
    _extraNotifications.removeWhere((item) => item.id == notification.id);
    _notifications.removeWhere((item) => item.id == notification.id);

    _extraNotifications.insert(0, notification);
    _notifications = [..._baseNotifications, ..._extraNotifications];

    if (markRead) {
      _readIds.add(notification.id);
    } else {
      _readIds.remove(notification.id);
    }

    await _persist();
    return _unreadCount();
  }

  @override
  Future<int> markAllRead() async {
    await _ensureSeeded();
    _readIds.addAll(_notifications.map((n) => n.id));
    await _persist();
    return 0;
  }

  @override
  Future<int> unreadCount() async {
    await _ensureSeeded();
    return _unreadCount();
  }

  List<AppNotification> _withReadState() {
    final sorted = List<AppNotification>.of(_notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted
        .map((n) => n.copyWith(read: _readIds.contains(n.id)))
        .toList();
  }

  Future<void> _ensureSeeded() async {
    if (_seeded) return;
    _baseNotifications = _seedNotifications();
    _notifications = List<AppNotification>.of(_baseNotifications);
    await _loadFromCache();
    _seeded = true;
  }

  Future<void> _loadFromCache() async {
    try {
      final hit = await _cache.read(_cacheKey.value);
      if (hit != null) {
        final extraRaw = hit.value['extraNotifications'];
        if (extraRaw is List) {
          _extraNotifications
            ..clear()
            ..addAll(
              extraRaw.map(_decodeNotification).whereType<AppNotification>(),
            );
          _notifications = [..._baseNotifications, ..._extraNotifications];
        }

        final raw = hit.value['readIds'];
        if (raw is List) {
          _readIds.addAll(
            raw.whereType<String>().where(_containsNotificationId),
          );
        }
      }
      if (hit == null) {
        await _persist();
      }
    } catch (e, stack) {
      _logger.warning('Failed to load notifications cache', e, stack);
    }
  }

  Future<void> _persist() async {
    final payload = <String, Object?>{
      'readIds': _readIds.toList(),
      'unreadCount': _unreadCount(),
      'extraNotifications': _extraNotifications
          .map(_encodeNotification)
          .toList(),
    };
    await _cache.write(_cacheKey.value, payload, tags: _cacheKey.tags);
  }

  int _unreadCount() {
    return _notifications.where((n) => !_readIds.contains(n.id)).length;
  }

  bool _containsNotificationId(String id) {
    return _notifications.any((n) => n.id == id);
  }

  List<AppNotification> _seedNotifications() {
    final now = DateTime.now();
    final prefersEnglish = _gates.prefersEnglish;
    final intl = _gates.emphasizeInternationalFlows;
    final rng = Random(now.millisecondsSinceEpoch ~/ 1000);

    String formatOrderId(int i) => 'ord-10${rng.nextInt(70) + i}';
    String formatDesignId(int i) => 'design-${rng.nextInt(90) + i}';

    return [
      AppNotification(
        id: 'notif-order-shipped',
        title: prefersEnglish ? 'Your order is shipped' : 'ご注文を出荷しました',
        body: prefersEnglish
            ? 'DHL picked up your parcel. Tracking is now available.'
            : 'DHLが荷物を集荷しました。追跡が有効になっています。',
        category: NotificationCategory.order,
        createdAt: now.subtract(const Duration(hours: 2)),
        target: '${AppRoutePaths.orders}/${formatOrderId(42)}/tracking',
        ctaLabel: prefersEnglish ? 'Track package' : '配送状況を見る',
      ),
      AppNotification(
        id: 'notif-production-proof',
        title: prefersEnglish ? 'Proof ready for your seal' : '刻印の校正が届きました',
        body: prefersEnglish
            ? 'Review the engraving proof so we can start cutting.'
            : '刻印工程に入る前に、校正内容をご確認ください。',
        category: NotificationCategory.design,
        createdAt: now.subtract(const Duration(hours: 5)),
        target: '${AppRoutePaths.orders}/${formatOrderId(33)}/production',
        ctaLabel: prefersEnglish ? 'Review proof' : '校正を確認',
      ),
      AppNotification(
        id: 'notif-library-ready',
        title: prefersEnglish
            ? 'New seal saved to your library'
            : '新しい印影をライブラリに保存しました',
        body: prefersEnglish
            ? 'We kept the latest AI-refined stamp with version history.'
            : 'AIで仕上げた最新の印影をバージョン履歴付きで保存しました。',
        category: NotificationCategory.design,
        createdAt: now.subtract(const Duration(hours: 9)),
        target: '${AppRoutePaths.library}/${formatDesignId(15)}',
        ctaLabel: prefersEnglish ? 'Open library' : 'マイ印鑑を開く',
      ),
      AppNotification(
        id: 'notif-promo-intl',
        title: prefersEnglish
            ? 'Priority DHL for international orders'
            : '国際配送の優先枠を解放しました',
        body: prefersEnglish
            ? 'This week only: expedited pickup for overseas shipments.'
            : '今週限定でDHL優先集荷枠を追加しました。海外配送の方はご利用ください。',
        category: NotificationCategory.promotion,
        createdAt: now.subtract(const Duration(hours: 16)),
        target: AppRoutePaths.checkoutShipping,
        ctaLabel: prefersEnglish ? 'Choose shipping' : '配送方法を選ぶ',
      ),
      AppNotification(
        id: 'notif-support-reply',
        title: prefersEnglish
            ? 'Support replied about your engraving'
            : 'サポートから回答が届きました',
        body: prefersEnglish
            ? 'We added size guidance for bank seal use cases.'
            : '銀行印向けのサイズ目安とレイアウト案をお送りします。',
        category: NotificationCategory.support,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        target: AppRoutePaths.supportChat,
        ctaLabel: prefersEnglish ? 'Open chat' : 'チャットを開く',
      ),
      AppNotification(
        id: 'notif-security-login',
        title: prefersEnglish ? 'New login detected' : '新しいログインを検出しました',
        body: prefersEnglish
            ? 'Chrome on iOS signed in near Yokohama. Was this you?'
            : 'iOS版Chromeから横浜付近でログインがありました。ご本人でしょうか？',
        category: NotificationCategory.security,
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        target: AppRoutePaths.profile,
        ctaLabel: prefersEnglish ? 'Review account' : 'アカウントを確認',
      ),
      AppNotification(
        id: 'notif-order-complete',
        title: prefersEnglish ? 'Order delivered' : '商品をお届けしました',
        body: prefersEnglish
            ? 'Let us know how the new seal feels. Reorder is one tap away.'
            : '新しい印鑑の使用感をお聞かせください。リピート注文も簡単です。',
        category: NotificationCategory.order,
        createdAt: now.subtract(const Duration(days: 1, hours: 12)),
        target: '${AppRoutePaths.orders}/${formatOrderId(28)}',
        ctaLabel: prefersEnglish ? 'View receipt' : '領収書を見る',
      ),
      AppNotification(
        id: 'notif-status-incident',
        title: prefersEnglish ? 'Minor delay resolved' : '一時的な遅延が解消しました',
        body: prefersEnglish
            ? 'Proof uploads were delayed for 12 minutes. Service is back to normal.'
            : '校正アップロードが12分ほど遅延しましたが、現在は復旧しています。',
        category: NotificationCategory.system,
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
        target: AppRoutePaths.status,
        ctaLabel: prefersEnglish ? 'View status' : 'ステータスを見る',
      ),
      AppNotification(
        id: 'notif-promo-gift',
        title: prefersEnglish ? 'Case upgrade gift' : 'ケースアップグレード特典',
        body: prefersEnglish
            ? 'Free cedar box upgrade for the next 48 hours.'
            : '48時間限定で桐箱アップグレードを無料で適用できます。',
        category: NotificationCategory.promotion,
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
        target: AppRoutePaths.cart,
        ctaLabel: prefersEnglish ? 'Apply offer' : '特典を適用',
      ),
      AppNotification(
        id: 'notif-design-versions',
        title: prefersEnglish ? 'Version history saved' : 'バージョン履歴を保存しました',
        body: prefersEnglish
            ? 'We kept the before/after of your AI refinement so you can roll back.'
            : 'AI仕上げ前後の履歴を保存しました。いつでも巻き戻せます。',
        category: NotificationCategory.design,
        createdAt: now.subtract(const Duration(days: 3, hours: 1)),
        target: AppRoutePaths.designVersions,
        ctaLabel: prefersEnglish ? 'Compare versions' : '差分を確認',
      ),
      AppNotification(
        id: 'notif-intl-permission',
        title: prefersEnglish
            ? 'Enable notifications to skip delays'
            : '通知を許可して遅延を防止',
        body: prefersEnglish
            ? 'We can alert you when customs needs info. Takes 10 seconds.'
            : '通関で情報が必要なときにすぐ通知します。10秒で設定できます。',
        category: NotificationCategory.system,
        createdAt: now.subtract(const Duration(days: 3, hours: 8)),
        target: AppRoutePaths.permissions,
        ctaLabel: prefersEnglish ? 'Allow notifications' : '通知を有効にする',
      ),
      AppNotification(
        id: 'notif-order-international',
        title: prefersEnglish ? 'Export document check' : '輸出用ドキュメントの確認',
        body: prefersEnglish
            ? 'For overseas shipments, please confirm the invoice name.'
            : '海外配送のため、インボイス記載名の確認をお願いします。',
        category: NotificationCategory.order,
        createdAt: now.subtract(const Duration(days: 4)),
        target: '${AppRoutePaths.orders}/${formatOrderId(11)}/invoice',
        ctaLabel: prefersEnglish ? 'Confirm details' : '内容を確認',
      ),
      if (intl)
        AppNotification(
          id: 'notif-intl-guide',
          title: prefersEnglish ? 'Guide: using seals abroad' : '海外での印鑑活用ガイド',
          body: prefersEnglish
              ? 'Tips for bank, immigration, and packaging when outside Japan.'
              : '海外での銀行・ビザ手続き・梱包での注意点をまとめました。',
          category: NotificationCategory.support,
          createdAt: now.subtract(const Duration(days: 5)),
          target: '${AppRoutePaths.guides}/intl-stamp',
          ctaLabel: prefersEnglish ? 'Read guide' : 'ガイドを読む',
        ),
    ];
  }
}

JsonMap _encodeNotification(AppNotification notification) {
  return {
    'id': notification.id,
    'title': notification.title,
    'body': notification.body,
    'category': notification.category.toJson(),
    'createdAt': notification.createdAt.toIso8601String(),
    'target': notification.target,
    'ctaLabel': notification.ctaLabel,
  };
}

AppNotification? _decodeNotification(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, Object?>.from(value);
  final id = map['id'];
  final title = map['title'];
  final body = map['body'];
  final target = map['target'];
  if (id is! String ||
      title is! String ||
      body is! String ||
      target is! String) {
    return null;
  }

  final categoryRaw = map['category'];
  final category = categoryRaw is String
      ? _parseCategory(categoryRaw)
      : NotificationCategory.system;

  final createdAtRaw = map['createdAt'];
  final createdAt = createdAtRaw is String
      ? DateTime.tryParse(createdAtRaw)
      : null;
  if (createdAt == null) return null;

  final ctaLabel = map['ctaLabel'];
  return AppNotification(
    id: id,
    title: title,
    body: body,
    category: category,
    createdAt: createdAt,
    target: target,
    ctaLabel: ctaLabel is String && ctaLabel.isNotEmpty ? ctaLabel : null,
  );
}

NotificationCategory _parseCategory(String raw) {
  try {
    return NotificationCategoryX.fromJson(raw);
  } on ArgumentError {
    return NotificationCategory.system;
  }
}
