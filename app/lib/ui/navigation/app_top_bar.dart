// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.leading,
    this.showBack = false,
    this.actions,
  });

  final String title;
  final Widget? leading;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final unread = ref.watch(unreadNotificationsProvider);
    final router = GoRouter.of(context);

    void openNotifications() => router.go(AppRoutePaths.notifications);
    void openSearch() => router.go(AppRoutePaths.search);
    void openHelp() => unawaited(_showHelpOverlay(context));

    return CallbackShortcuts(
      bindings: _shortcuts(
        onSearch: openSearch,
        onNotifications: openNotifications,
        onHelp: openHelp,
      ),
      child: FocusTraversalGroup(
        child: AppBar(
          title: Text(title),
          leading: leading ?? (showBack ? const BackButton() : null),
          actions: [
            _SearchAction(onPressed: openSearch),
            _HelpAction(onPressed: openHelp),
            _NotificationsAction(unread: unread, onPressed: openNotifications),
            if (actions != null && actions!.isNotEmpty) ...[
              SizedBox(width: tokens.spacing.sm),
              ...actions!,
            ],
            SizedBox(width: tokens.spacing.sm),
          ],
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts({
    required VoidCallback onSearch,
    required VoidCallback onNotifications,
    required VoidCallback onHelp,
  }) {
    return {
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): onSearch,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): onSearch,
      const SingleActivator(LogicalKeyboardKey.keyN, alt: true):
          onNotifications,
      const SingleActivator(LogicalKeyboardKey.slash, shift: true): onHelp,
    };
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '検索',
      hint: '⌘K / Ctrl+K のショートカットに対応',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.search_rounded),
        tooltip: '検索 (⌘K / Ctrl+K)',
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _HelpAction extends StatelessWidget {
  const _HelpAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ヘルプ',
      hint: 'Shift + / でも開けます',
      button: true,
      child: IconButton(
        icon: const Icon(Icons.help_outline_rounded),
        tooltip: 'ヘルプ・FAQ (Shift + /)',
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _NotificationsAction extends StatelessWidget {
  const _NotificationsAction({required this.unread, required this.onPressed});

  final AsyncValue<int> unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final unreadCount = switch (unread) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final count = unreadCount ?? 0;
    final hasUnread = count > 0;
    final label = hasUnread ? '通知 ($unreadCount 件の未読)' : '通知';

    final icon = IconButton(
      icon: Icon(
        hasUnread
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
      ),
      tooltip: hasUnread ? '$label (Alt + N)' : '通知 (Alt + N)',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );

    final button = Semantics(label: label, button: true, child: icon);

    if (!hasUnread) return button;

    return Badge.count(
      count: count,
      backgroundColor: tokens.colors.primary,
      textColor: tokens.colors.onPrimary,
      offset: const Offset(2, -2),
      child: button,
    );
  }
}

Future<void> _showHelpOverlay(BuildContext context) async {
  final tokens = DesignTokensTheme.of(context);
  final router = GoRouter.of(context);

  await showAppModal<void>(
    context: context,
    title: 'ヘルプとショートカット',
    primaryAction: 'FAQを見る',
    secondaryAction: '問い合わせる',
    onPrimaryPressed: () {
      Navigator.of(context).maybePop();
      router.go(AppRoutePaths.supportFaq);
    },
    onSecondaryPressed: () {
      Navigator.of(context).maybePop();
      router.go(AppRoutePaths.supportContact);
    },
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ショートカットとサポートへの入り口です。'
          '困ったときはFAQやチャットにすぐ移動できます。',
        ),
        SizedBox(height: tokens.spacing.md),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: const [
            _ShortcutPill(label: '検索', combo: '⌘K / Ctrl+K'),
            _ShortcutPill(label: 'ヘルプ', combo: 'Shift + /'),
            _ShortcutPill(label: '通知', combo: 'Alt + N'),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        _HelpLinkTile(
          icon: Icons.quiz_outlined,
          title: 'FAQで調べる',
          subtitle: 'よくある質問とトラブルシューティング',
          onTap: () {
            Navigator.of(context).maybePop();
            router.go(AppRoutePaths.supportFaq);
          },
        ),
        SizedBox(height: tokens.spacing.sm),
        _HelpLinkTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'チャットで相談',
          subtitle: 'すぐ聞きたいときはこちら',
          onTap: () {
            Navigator.of(context).maybePop();
            router.go(AppRoutePaths.supportChat);
          },
        ),
        SizedBox(height: tokens.spacing.sm),
        _HelpLinkTile(
          icon: Icons.mail_outline_rounded,
          title: '問い合わせフォーム',
          subtitle: '詳細なサポートが必要な場合',
          onTap: () {
            Navigator.of(context).maybePop();
            router.go(AppRoutePaths.supportContact);
          },
        ),
      ],
    ),
  );
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({required this.label, required this.combo});

  final String label;
  final String combo;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(tokens.radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          SizedBox(width: tokens.spacing.xs),
          Text(
            combo,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpLinkTile extends StatelessWidget {
  const _HelpLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tokens.colors.primary),
              SizedBox(width: tokens.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: tokens.colors.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: tokens.colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
