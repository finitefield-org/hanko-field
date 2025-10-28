import 'package:app/core/app_state/notification_badge.dart';
import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppTopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopAppBar({
    super.key,
    required this.title,
    this.customTitle,
    this.leading,
    this.centerTitle,
    this.showNotificationAction = true,
    this.showSearchAction = true,
    this.showHelpAction = true,
    this.onNotificationsTap,
    this.onSearchTap,
    this.onHelpTap,
    this.trailingActions = const [],
    this.helpContextLabel,
  });

  final String title;
  final Widget? customTitle;
  final Widget? leading;
  final bool? centerTitle;
  final bool showNotificationAction;
  final bool showSearchAction;
  final bool showHelpAction;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onHelpTap;
  final List<Widget> trailingActions;
  final String? helpContextLabel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(notificationBadgeProvider);
    final unreadCount = unreadAsync.value ?? 0;
    final isLoadingUnread = unreadAsync.isLoading && unreadAsync.value == null;

    final resolvedHelpTap =
        onHelpTap ??
        () => showHelpOverlay(context, contextLabel: helpContextLabel ?? title);

    final actions = <Widget>[
      if (showNotificationAction)
        _NotificationBellButton(
          unreadCount: unreadCount,
          isLoading: isLoadingUnread,
          onPressed: onNotificationsTap,
        ),
      if (showSearchAction)
        _TopBarIconButton(
          icon: Icons.search,
          label: '検索',
          shortcutHint: '/',
          onPressed: onSearchTap,
        ),
      if (showHelpAction)
        _TopBarIconButton(
          icon: Icons.help_outline,
          label: 'ヘルプ',
          shortcutHint: 'F1',
          onPressed: resolvedHelpTap,
          semanticLabel: helpContextLabel == null
              ? 'ヘルプ'
              : '${helpContextLabel!}のヘルプ',
        ),
      ...trailingActions,
    ];

    return AppBar(
      title: customTitle ?? Text(title),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.isLoading,
    required this.onPressed,
  });

  final int unreadCount;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = isLoading ? 'お知らせを読み込み中' : 'お知らせ (N)';
    final semanticsLabel = unreadCount > 0
        ? '未読お知らせ $unreadCount 件'
        : 'お知らせはありません';
    Widget icon = const Icon(Icons.notifications_none);
    if (isLoading) {
      icon = Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.notifications_none),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    }
    Widget button = IconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
    );
    button = Semantics(
      label: semanticsLabel,
      button: true,
      value: unreadCount > 0 ? '$unreadCount' : null,
      child: button,
    );

    if (unreadCount <= 0) {
      return button;
    }
    return Badge.count(count: unreadCount, child: button);
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.label,
    this.shortcutHint,
    this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? shortcutHint;
  final String? semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = shortcutHint == null ? label : '$label ($shortcutHint)';
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class AppShortcutRegistrar extends StatelessWidget {
  const AppShortcutRegistrar({
    super.key,
    required this.child,
    this.onNotificationsTap,
    this.onSearchTap,
    this.onHelpTap,
  });

  final Widget child;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onHelpTap;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{};
    final actions = <Type, Action<Intent>>{};

    if (onNotificationsTap != null) {
      shortcuts[LogicalKeySet(LogicalKeyboardKey.keyN)] =
          const _NotificationIntent();
      actions[_NotificationIntent] = CallbackAction<_NotificationIntent>(
        onInvoke: (_) {
          onNotificationsTap!();
          return null;
        },
      );
    }
    if (onSearchTap != null) {
      shortcuts[LogicalKeySet(LogicalKeyboardKey.slash)] =
          const _SearchIntent();
      actions[_SearchIntent] = CallbackAction<_SearchIntent>(
        onInvoke: (_) {
          onSearchTap!();
          return null;
        },
      );
    }
    if (onHelpTap != null) {
      shortcuts[LogicalKeySet(LogicalKeyboardKey.f1)] = const _HelpIntent();
      actions[_HelpIntent] = CallbackAction<_HelpIntent>(
        onInvoke: (_) {
          onHelpTap!();
          return null;
        },
      );
    }

    if (shortcuts.isEmpty) {
      return child;
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          descendantsAreFocusable: true,
          child: child,
        ),
      ),
    );
  }
}

class _NotificationIntent extends Intent {
  const _NotificationIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}
