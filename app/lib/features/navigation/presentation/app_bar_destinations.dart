import 'package:app/core/app_state/notification_badge.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/core/ui/widgets/app_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationInboxPage extends ConsumerWidget {
  const NotificationInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationBadgeProvider).value ?? 0;
    void openNotificationsHelp() {
      showHelpOverlay(context, contextLabel: 'お知らせ');
    }

    return AppShortcutRegistrar(
      onHelpTap: openNotificationsHelp,
      child: Scaffold(
        appBar: AppTopAppBar(
          title: 'お知らせ',
          showNotificationAction: false,
          showSearchAction: false,
          helpContextLabel: 'お知らせ',
          onHelpTap: openNotificationsHelp,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Text(
                    '未読 $unreadCount 件',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: unreadCount == 0
                        ? null
                        : () {
                            ref
                                .read(notificationBadgeProvider.notifier)
                                .updateCount(0);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('すべて既読になりました')),
                            );
                          },
                    icon: const Icon(Icons.done_all),
                    label: const Text('すべて既読'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final notification in _sampleNotifications)
                Card(
                  elevation: notification.unread ? 1 : 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      notification.icon,
                      color: notification.unread
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          notification.timestampLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (notification.unread)
                          const Text(
                            '未読',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${notification.title} を開きます')),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    showHelpOverlay(context, contextLabel: 'お知らせセンター'),
                icon: const Icon(Icons.help_center_outlined),
                label: const Text('ヘルプを見る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchFieldFocusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _searchFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final results = _mockSearchResults
        .where(
          (result) =>
              query.isEmpty ||
              result.title.contains(query) ||
              result.subtitle.contains(query),
        )
        .toList();
    final notifier = ref.read(appStateProvider.notifier);

    void openNotifications() {
      notifier.push(const NotificationsRoute());
    }

    void focusSearchField() {
      _searchFieldFocusNode.requestFocus();
    }

    void openSearchHelp() {
      showHelpOverlay(context, contextLabel: '検索');
    }

    return AppShortcutRegistrar(
      onNotificationsTap: openNotifications,
      onSearchTap: focusSearchField,
      onHelpTap: openSearchHelp,
      child: Scaffold(
        appBar: AppTopAppBar(
          title: '検索',
          showSearchAction: false,
          helpContextLabel: '検索',
          onNotificationsTap: openNotifications,
          onHelpTap: openSearchHelp,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Semantics(
                label: 'アプリ全体を検索',
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFieldFocusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'キーワードで検索',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '入力をクリア',
                            onPressed: () {
                              _controller.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 24),
              Text('クイックアクセス', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final suggestion in _quickQueries)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        _controller.text = suggestion;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                query.isEmpty ? '最近のトピック' : '検索結果 (${results.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (results.isEmpty) const Text('一致する結果がありません。'),
              for (final result in results)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(result.icon),
                    title: Text(result.title),
                    subtitle: Text(result.subtitle),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${result.title} へ移動します')),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPreview {
  const _NotificationPreview({
    required this.icon,
    required this.title,
    required this.description,
    required this.timestampLabel,
    this.unread = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String timestampLabel;
  final bool unread;
}

const _sampleNotifications = [
  _NotificationPreview(
    icon: Icons.inventory_2_outlined,
    title: '注文 HF-202401 が発送されました',
    description: '配送番号 123-456 で追跡できます。',
    timestampLabel: '5分前',
    unread: true,
  ),
  _NotificationPreview(
    icon: Icons.star_border,
    title: 'おすすめ素材を更新しました',
    description: '新しい御影石テンプレートを確認してください。',
    timestampLabel: '2時間前',
    unread: true,
  ),
  _NotificationPreview(
    icon: Icons.discount_outlined,
    title: '秋のキャンペーンが開始',
    description: '9/30 まで 15% OFF クーポンを利用できます。',
    timestampLabel: '昨日',
  ),
];

class _SearchResultPreview {
  const _SearchResultPreview({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

const _mockSearchResults = [
  _SearchResultPreview(
    icon: Icons.design_services_outlined,
    title: '作成ステップ: 印影エディタ',
    subtitle: '編集済みテンプレートを調整',
  ),
  _SearchResultPreview(
    icon: Icons.shopping_bag_outlined,
    title: 'ショップ: 人気商品',
    subtitle: 'ランキングとおすすめ素材',
  ),
  _SearchResultPreview(
    icon: Icons.receipt_long_outlined,
    title: '注文 HF-202401',
    subtitle: '制作中 / 支払い済み',
  ),
  _SearchResultPreview(
    icon: Icons.collections_bookmark_outlined,
    title: 'マイ印鑑: JP-INK-01',
    subtitle: 'クラウド同期済み',
  ),
];

const _quickQueries = ['注文ステータス', '素材ガイド', 'マイ印鑑', 'サポート'];
