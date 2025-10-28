import 'dart:async';

import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/notifications/domain/app_notification.dart';

abstract class NotificationRepository {
  static const defaultPageSize = 12;

  Future<NotificationsPage> fetch({
    String? cursor,
    int pageSize = defaultPageSize,
    bool unreadOnly = false,
  });

  Future<AppNotification?> findById(String id);

  Future<AppNotification> updateReadState({
    required String id,
    required bool read,
  });

  Future<void> markAllAsRead();
}

class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    required OfflineCacheRepository cache,
    Duration latency = const Duration(milliseconds: 320),
  }) : _cache = cache,
       _latency = latency {
    _items = List<AppNotification>.from(_seedData)..sort(_compareDesc);
    unawaited(_mergeCachedReadState());
  }

  final OfflineCacheRepository _cache;
  final Duration _latency;

  late final List<AppNotification> _items;

  static int _compareDesc(AppNotification a, AppNotification b) {
    return b.timestamp.compareTo(a.timestamp);
  }

  static DateTime get _now => DateTime.now();

  static List<AppNotification> get _seedData {
    final now = _now;
    return [
      AppNotification(
        id: 'notif-001',
        title: '注文 HF-202401 が発送されました',
        body: '配送番号 123-456 で追跡できます。',
        category: NotificationCategory.order,
        timestamp: now.subtract(const Duration(minutes: 5)),
        action: NotificationAction(
          label: '配送状況',
          destination: OrderDetailsRoute(orderId: 'HF-202401'),
        ),
        deepLink: '/orders/HF-202401',
      ),
      AppNotification(
        id: 'notif-002',
        title: '制作工程に新しい進捗があります',
        body: '彫刻工程が完了しました。検品に移ります。',
        category: NotificationCategory.production,
        timestamp: now.subtract(const Duration(minutes: 38)),
        action: NotificationAction(
          label: 'タイムライン',
          destination: OrderDetailsRoute(
            orderId: 'HF-202399',
            trailing: const ['production'],
          ),
        ),
        deepLink: '/orders/HF-202399/production',
      ),
      AppNotification(
        id: 'notif-003',
        title: '秋のキャンペーンが開始されました',
        body: '9/30 まで 15% OFF クーポンを利用できます。',
        category: NotificationCategory.promotion,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 5)),
        action: NotificationAction(
          label: 'クーポンを見る',
          destination: ShopDetailRoute(
            entity: 'campaigns',
            identifier: 'autumn-2024',
          ),
        ),
        deepLink: '/shop/campaigns/autumn-2024',
      ),
      AppNotification(
        id: 'notif-004',
        title: 'おすすめ素材を更新しました',
        body: '新しい御影石テンプレートを確認してください。',
        category: NotificationCategory.guide,
        timestamp: now.subtract(const Duration(hours: 5, minutes: 12)),
        action: NotificationAction(
          label: '素材を見る',
          destination: ShopDetailRoute(
            entity: 'materials',
            identifier: 'stone-001',
          ),
        ),
        deepLink: '/shop/materials/stone-001',
      ),
      AppNotification(
        id: 'notif-005',
        title: '推奨テンプレートを保存しました',
        body: '国際向けのテンプレートをライブラリに追加しました。',
        category: NotificationCategory.guide,
        timestamp: now.subtract(const Duration(hours: 11, minutes: 44)),
        action: NotificationAction(
          label: 'ライブラリを開く',
          destination: LibraryEntryRoute(designId: 'JP-INK-03'),
        ),
        deepLink: '/library/JP-INK-03',
      ),
      AppNotification(
        id: 'notif-006',
        title: '制作チームからのメッセージ',
        body: '刻印のフォント調整案を確認してください。',
        category: NotificationCategory.production,
        timestamp: now.subtract(const Duration(hours: 18, minutes: 20)),
        action: NotificationAction(
          label: '調整する',
          destination: CreationStageRoute(const ['editor', 'review']),
        ),
        deepLink: '/create/editor/review',
      ),
      AppNotification(
        id: 'notif-007',
        title: 'サポートからのお知らせ',
        body: 'アプリの強制アップデートが 11/1 に実施されます。',
        category: NotificationCategory.system,
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        deepLink: '/support/updates',
      ),
      AppNotification(
        id: 'notif-008',
        title: '印影データのエクスポートが完了しました',
        body: 'SVG と PNG ファイルをダウンロードできます。',
        category: NotificationCategory.order,
        timestamp: now.subtract(const Duration(days: 1, hours: 8, minutes: 20)),
        action: NotificationAction(
          label: 'ダウンロード',
          destination: LibraryEntryRoute(
            designId: 'JP-INK-02',
            trailing: const ['export'],
          ),
        ),
        deepLink: '/library/JP-INK-02/export',
      ),
      AppNotification(
        id: 'notif-009',
        title: 'オンボーディングチュートリアルの新ステップ',
        body: '外国人ユーザー向けの漢字マッピング解説を追加しました。',
        category: NotificationCategory.guide,
        timestamp: now.subtract(const Duration(days: 2, hours: 3)),
        action: NotificationAction(
          label: 'チュートリアル',
          destination: CreationStageRoute(const ['input', 'kanji-map']),
        ),
        deepLink: '/create/input/kanji-map',
      ),
      AppNotification(
        id: 'notif-010',
        title: 'ライブラリに新しい共有リンクがあります',
        body: '法人印章の共有リンクが更新されました。',
        category: NotificationCategory.system,
        timestamp: now.subtract(const Duration(days: 3, hours: 6)),
        action: NotificationAction(
          label: 'リンクを管理',
          destination: LibraryEntryRoute(
            designId: 'JP-INK-05',
            trailing: const ['shares'],
          ),
        ),
        deepLink: '/library/JP-INK-05/shares',
      ),
      AppNotification(
        id: 'notif-011',
        title: 'チェックアウトが途中です',
        body: 'カートの保存から 24 時間が経過しました。',
        category: NotificationCategory.promotion,
        timestamp: now.subtract(const Duration(days: 4, hours: 1)),
        action: NotificationAction(
          label: 'カートに戻る',
          destination: CreationStageRoute(const ['checkout']),
        ),
        deepLink: '/orders/cart',
      ),
      AppNotification(
        id: 'notif-012',
        title: '新しい素材ガイドを公開しました',
        body: '用途別の朱肉ケースガイドをお届けします。',
        category: NotificationCategory.guide,
        timestamp: now.subtract(const Duration(days: 5, hours: 3)),
        action: NotificationAction(
          label: 'ガイドを見る',
          destination: ProfileSectionRoute(const ['guides', 'inkpad-guide']),
        ),
        deepLink: '/profile/guides/inkpad-guide',
      ),
      AppNotification(
        id: 'notif-013',
        title: '制作工程アンケートのお願い',
        body: '制作完了後のフィードバックにご協力ください。',
        category: NotificationCategory.system,
        timestamp: now.subtract(const Duration(days: 6, hours: 5)),
      ),
      AppNotification(
        id: 'notif-014',
        title: '法人アカウントの権限を更新しました',
        body: '新しいメンバーを追加しました。',
        category: NotificationCategory.system,
        timestamp: now.subtract(const Duration(days: 7, hours: 11)),
        action: NotificationAction(
          label: '権限を確認',
          destination: ProfileSectionRoute(const [
            'organization',
            'permissions',
          ]),
        ),
        deepLink: '/profile/organization/permissions',
      ),
      AppNotification(
        id: 'notif-015',
        title: '素材「藍染」がお気に入りに追加されました',
        body: '次回注文時に簡単にアクセスできます。',
        category: NotificationCategory.promotion,
        timestamp: now.subtract(const Duration(days: 8, hours: 1)),
        action: NotificationAction(
          label: 'お気に入り',
          destination: ProfileSectionRoute(const ['favorites', 'materials']),
        ),
        deepLink: '/profile/favorites/materials',
      ),
    ];
  }

  Future<void> _mergeCachedReadState() async {
    try {
      final snapshot = await _cache.readNotifications();
      final cached = snapshot.value;
      if (cached == null) {
        return;
      }
      final readLookup = {for (final item in cached.items) item.id: item.read};
      _items = [
        for (final item in _items)
          readLookup.containsKey(item.id)
              ? item.copyWith(read: readLookup[item.id])
              : item,
      ]..sort(_compareDesc);
    } catch (_) {
      // Ignore cache errors; continue with in-memory defaults.
    }
  }

  Future<void> _persist() async {
    final snapshot = CachedNotificationsSnapshot(
      items: [
        for (final item in _items)
          NotificationCacheItem(
            id: item.id,
            title: item.title,
            body: item.body,
            timestamp: item.timestamp,
            read: item.read,
            deepLink: item.deepLink,
          ),
      ],
      unreadCount: _items.where((item) => !item.read).length,
      lastSyncedAt: DateTime.now(),
    );
    await _cache.writeNotifications(snapshot);
  }

  @override
  Future<NotificationsPage> fetch({
    String? cursor,
    int pageSize = NotificationRepository.defaultPageSize,
    bool unreadOnly = false,
  }) async {
    await Future<void>.delayed(_latency);
    final source = unreadOnly
        ? _items.where((item) => !item.read).toList()
        : List<AppNotification>.from(_items);
    var index = 0;
    if (cursor != null) {
      index = int.tryParse(cursor) ?? 0;
      index = index.clamp(0, source.length);
    }
    final slice = source.skip(index).take(pageSize).toList();
    final nextCursor = index + slice.length < source.length
        ? '${index + slice.length}'
        : null;

    // Persist the snapshot after fetch to keep unread count in sync.
    await _persist();

    return NotificationsPage(
      items: slice,
      unreadCount: _items.where((item) => !item.read).length,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<AppNotification?> findById(String id) async {
    await Future<void>.delayed(_latency ~/ 2);
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    await Future<void>.delayed(_latency);
    _items = [for (final item in _items) item.copyWith(read: true)];
    await _persist();
  }

  @override
  Future<AppNotification> updateReadState({
    required String id,
    required bool read,
  }) async {
    await Future<void>.delayed(_latency);
    final updated = _items.map((item) {
      if (item.id == id) {
        return item.copyWith(read: read);
      }
      return item;
    }).toList();
    final result = updated.firstWhere((item) => item.id == id);
    _items = updated;
    await _persist();
    return result;
  }
}
