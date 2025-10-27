import 'package:flutter/material.dart';

/// Opens a contextual help overlay with quick links and keyboard hints.
Future<void> showHelpOverlay(
  BuildContext context, {
  required String contextLabel,
}) {
  final topics = _HelpTopic.samplesFor(contextLabel);
  const shortcuts = [
    _ShortcutHint(label: 'お知らせ', shortcut: 'N'),
    _ShortcutHint(label: '検索', shortcut: '/'),
    _ShortcutHint(label: 'ヘルプ', shortcut: 'F1'),
  ];

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return Semantics(
        label: '$contextLabel のヘルプオーバーレイ',
        explicitChildNodes: true,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$contextLabel のヘルプ', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  const Text(
                    'クイックガイドや FAQ に素早くアクセスできます。'
                    'キーボードショートカットも利用可能です。',
                  ),
                  const SizedBox(height: 24),
                  ...topics.map(
                    (topic) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(topic.icon),
                        title: Text(topic.title),
                        subtitle: Text(topic.description),
                        trailing: Text(
                          topic.actionLabel,
                          style: theme.textTheme.labelMedium,
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${topic.title} を開きます')),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('ショートカット', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final shortcut in shortcuts)
                        Chip(
                          avatar: CircleAvatar(child: Text(shortcut.shortcut)),
                          label: Text(shortcut.label),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _HelpTopic {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;

  static List<_HelpTopic> samplesFor(String contextLabel) {
    return [
      _HelpTopic(
        icon: Icons.library_books_outlined,
        title: '$contextLabel のガイド',
        description: 'ステップバイステップのチュートリアルを表示します。',
        actionLabel: 'ガイド',
      ),
      const _HelpTopic(
        icon: Icons.chat_bubble_outline,
        title: 'FAQ とサポート',
        description: 'よくある質問や問い合わせリンクを確認します。',
        actionLabel: 'FAQ',
      ),
      const _HelpTopic(
        icon: Icons.live_help_outlined,
        title: 'コンシェルジュとチャット',
        description: '担当者にチャットで質問できます。',
        actionLabel: 'チャット',
      ),
    ];
  }
}

class _ShortcutHint {
  const _ShortcutHint({required this.label, required this.shortcut});

  final String label;
  final String shortcut;
}
