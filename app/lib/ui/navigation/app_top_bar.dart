// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/routes.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
            _SearchAction(onPressed: openSearch, l10n: l10n),
            _HelpAction(onPressed: openHelp, l10n: l10n),
            _NotificationsAction(
              unread: unread,
              onPressed: openNotifications,
              l10n: l10n,
            ),
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
  const _SearchAction({required this.onPressed, required this.l10n});

  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.topBarSearchLabel,
      hint: l10n.topBarSearchHint,
      button: true,
      child: IconButton(
        icon: const Icon(Icons.search_rounded),
        tooltip: l10n.topBarSearchTooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _HelpAction extends StatelessWidget {
  const _HelpAction({required this.onPressed, required this.l10n});

  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.topBarHelpLabel,
      hint: l10n.topBarHelpHint,
      button: true,
      child: IconButton(
        icon: const Icon(Icons.help_outline_rounded),
        tooltip: l10n.topBarHelpTooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _NotificationsAction extends StatelessWidget {
  const _NotificationsAction({
    required this.unread,
    required this.onPressed,
    required this.l10n,
  });

  final AsyncValue<int> unread;
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final unreadCount = switch (unread) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final count = unreadCount ?? 0;
    final hasUnread = count > 0;
    final label = hasUnread
        ? l10n.topBarNotificationsLabelWithUnread(count)
        : l10n.topBarNotificationsLabel;

    final icon = IconButton(
      icon: Icon(
        hasUnread
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_rounded,
      ),
      tooltip: hasUnread
          ? l10n.topBarNotificationsTooltipWithUnread(count)
          : l10n.topBarNotificationsTooltip,
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
  final l10n = AppLocalizations.of(context);

  await showAppModal<void>(
    context: context,
    title: l10n.topBarHelpOverlayTitle,
    primaryAction: l10n.topBarHelpOverlayPrimaryAction,
    secondaryAction: l10n.topBarHelpOverlaySecondaryAction,
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
        Text(l10n.topBarHelpOverlayBody),
        SizedBox(height: tokens.spacing.md),
        Wrap(
          spacing: tokens.spacing.sm,
          runSpacing: tokens.spacing.sm,
          children: [
            _ShortcutPill(
              label: l10n.topBarShortcutSearchLabel,
              combo: '⌘K / Ctrl+K',
            ),
            _ShortcutPill(
              label: l10n.topBarShortcutHelpLabel,
              combo: 'Shift + /',
            ),
            _ShortcutPill(
              label: l10n.topBarShortcutNotificationsLabel,
              combo: 'Alt + N',
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.lg),
        _HelpLinkTile(
          icon: Icons.quiz_outlined,
          title: l10n.topBarHelpLinkFaqTitle,
          subtitle: l10n.topBarHelpLinkFaqSubtitle,
          onTap: () {
            Navigator.of(context).maybePop();
            router.go(AppRoutePaths.supportFaq);
          },
        ),
        SizedBox(height: tokens.spacing.sm),
        _HelpLinkTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.topBarHelpLinkChatTitle,
          subtitle: l10n.topBarHelpLinkChatSubtitle,
          onTap: () {
            Navigator.of(context).maybePop();
            router.go(AppRoutePaths.supportChat);
          },
        ),
        SizedBox(height: tokens.spacing.sm),
        _HelpLinkTile(
          icon: Icons.mail_outline_rounded,
          title: l10n.topBarHelpLinkContactTitle,
          subtitle: l10n.topBarHelpLinkContactSubtitle,
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
