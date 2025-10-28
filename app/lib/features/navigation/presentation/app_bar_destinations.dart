import 'package:app/core/app_state/notification_badge.dart';
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
