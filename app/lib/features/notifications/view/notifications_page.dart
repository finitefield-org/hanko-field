// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:collection';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/features/notifications/data/models/notification_models.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/notifications/view_model/notifications_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _didResetBadge = false;
  late final ProviderSubscription<AsyncValue<NotificationsState>> _badgeCancel;
  late final ProviderSubscription<AsyncValue<int>> _unreadCancel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _badgeCancel = ref.container.listen<AsyncValue<NotificationsState>>(
      notificationsViewModel,
      (AsyncValue<NotificationsState>? _, AsyncValue<NotificationsState> next) {
        if (_didResetBadge) return;
        if (next.valueOrNull == null) return;
        final unreadState = ref.container.read(unreadNotificationsProvider);
        if (unreadState is AsyncLoading<int>) return;
        final unread = unreadState.valueOrNull;
        if (unread == null || unread <= 0) return;
        _didResetBadge = true;
        unawaited(ref.invoke(notificationsViewModel.markAllRead()));
      },
    );
    _unreadCancel = ref.container.listen<AsyncValue<int>>(
      unreadNotificationsProvider,
      (AsyncValue<int>? _, AsyncValue<int> next) {
        if (_didResetBadge) return;
        final unread = next.valueOrNull;
        if (unread == null || unread <= 0) return;
        if (ref.container.read(notificationsViewModel).valueOrNull == null) {
          return;
        }
        _didResetBadge = true;
        unawaited(ref.invoke(notificationsViewModel.markAllRead()));
      },
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _badgeCancel.close();
    _unreadCancel.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final unread = ref.watch(unreadNotificationsProvider);
    final state = ref.watch(notificationsViewModel);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _NotificationsAppBar(
        unread: unread,
        onMarkAllRead: _handleMarkAllRead,
        l10n: l10n,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.sm,
              ),
              child: _FilterBar(
                selected: state.valueOrNull?.filter ?? NotificationFilter.all,
                l10n: l10n,
                onSelected: (filter) =>
                    ref.invoke(notificationsViewModel.setFilter(filter)),
              ),
            ),
            Expanded(
              child: RefreshIndicator.adaptive(
                displacement: tokens.spacing.xl,
                edgeOffset: tokens.spacing.md,
                onRefresh: _refresh,
                child: _buildContent(
                  context: context,
                  state: state,
                  l10n: l10n,
                  tokens: tokens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required AsyncValue<NotificationsState> state,
    required AppLocalizations l10n,
    required DesignTokens tokens,
  }) {
    final loading = state is AsyncLoading<NotificationsState>;
    final error = state is AsyncError<NotificationsState>;
    final data = state.valueOrNull;

    if (loading && data == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
        child: const AppListSkeleton(items: 5, itemHeight: 88),
      );
    }

    if (error && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: l10n.commonLoadFailed,
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: l10n.commonRetry,
          onAction: () => unawaited(_refresh()),
        ),
      );
    }

    final rawItems = data?.items ?? const <AppNotification>[];
    final filter = data?.filter ?? NotificationFilter.all;
    final items = filter.unreadOnly
        ? rawItems.where((n) => !n.read).toList()
        : rawItems;
    final entries = _entriesFor(items);
    final hasMore = data?.nextPageToken != null;
    final isLoadingMore = data?.isLoadingMore == true;

    if (items.isEmpty) {
      final message =
          (state.valueOrNull?.filter ?? NotificationFilter.all) ==
              NotificationFilter.unread
          ? l10n.notificationsEmptyUnreadMessage
          : l10n.notificationsEmptyAllMessage;

      final cta = l10n.notificationsRefresh;

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: tokens.spacing.xl),
          AppEmptyState(
            title: l10n.notificationsEmptyTitle,
            message: message,
            icon: Icons.notifications_none_rounded,
            actionLabel: cta,
            onAction: () => unawaited(_refresh()),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      itemCount: entries.length + (hasMore || isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= entries.length) {
          return Padding(
            padding: EdgeInsets.only(top: tokens.spacing.md),
            child: Center(
              child: isLoadingMore
                  ? const CircularProgressIndicator.adaptive()
                  : Text(
                      l10n.notificationsLoadMoreHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          );
        }

        final entry = entries[index];
        return switch (entry) {
          _HeaderEntry(:final date) => Padding(
            padding: EdgeInsets.only(
              top: tokens.spacing.md,
              bottom: tokens.spacing.xs,
            ),
            child: Text(
              _formatHeader(date, l10n),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _ItemEntry(:final notification) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _NotificationTile(
              notification: notification,
              l10n: l10n,
              onTap: () => _openNotification(notification),
              onSwipe: (read) =>
                  _handleSwipe(notification: notification, read: read),
            ),
          ),
        };
      },
    );
  }

  Future<void> _refresh() {
    return ref.invoke(notificationsViewModel.refresh());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final state = ref.container.read(notificationsViewModel).valueOrNull;
    if (state == null || state.nextPageToken == null || state.isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 220) {
      ref.invoke(notificationsViewModel.loadMore());
    }
  }

  Future<void> _handleSwipe({
    required AppNotification notification,
    required bool read,
  }) async {
    final previous = notification.read;
    if (previous == read) return;

    await ref.invoke(
      notificationsViewModel.setReadState(notification.id, read),
    );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final message = read
        ? l10n.notificationsMarkedRead
        : l10n.notificationsMarkedUnread;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: l10n.notificationsUndo,
            onPressed: () => ref.invoke(
              notificationsViewModel.setReadState(notification.id, previous),
            ),
          ),
        ),
      );
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.read) {
      await ref.invoke(
        notificationsViewModel.setReadState(notification.id, true),
      );
    }

    if (!mounted) return;
    final navigation = ref.container.read(navigationControllerProvider);
    unawaited(navigation.push(notification.target));
  }

  Future<void> _handleMarkAllRead() async {
    await ref.invoke(notificationsViewModel.markAllRead());
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.notificationsAllCaughtUp)));
  }
}

class _NotificationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _NotificationsAppBar({
    required this.unread,
    required this.onMarkAllRead,
    required this.l10n,
  });

  final AsyncValue<int> unread;
  final Future<void> Function() onMarkAllRead;
  final AppLocalizations l10n;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final unreadCount = unread.valueOrNull ?? 0;

    return AppBar(
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.topBarNotificationsLabel),
          if (unreadCount > 0)
            Text(
              l10n.notificationsUnreadCount(unreadCount),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      actions: [
        PopupMenuButton<_OverflowAction>(
          tooltip: l10n.notificationsMoreTooltip,
          onSelected: (action) {
            if (action == _OverflowAction.markAllRead) {
              unawaited(onMarkAllRead());
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _OverflowAction.markAllRead,
              child: Row(
                children: [
                  const Icon(Icons.done_all, size: 18),
                  SizedBox(width: tokens.spacing.sm),
                  Text(l10n.notificationsMarkAllRead),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.l10n,
    required this.onSelected,
  });

  final NotificationFilter selected;
  final AppLocalizations l10n;
  final Future<void> Function(NotificationFilter) onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NotificationFilter>(
      segments: [
        ButtonSegment(
          value: NotificationFilter.all,
          label: Text(l10n.notificationsFilterAll),
          icon: const Icon(Icons.inbox_rounded),
        ),
        ButtonSegment(
          value: NotificationFilter.unread,
          label: Text(l10n.notificationsFilterUnread),
          icon: const Icon(Icons.mark_email_unread_outlined),
        ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (value) => unawaited(onSelected(value.first)),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.l10n,
    required this.onTap,
    required this.onSwipe,
  });

  final AppNotification notification;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final Future<void> Function(bool) onSwipe;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final categoryColor = _categoryColor(notification.category, tokens);
    final timeLabel = _timeLabel(notification.createdAt, l10n);

    return Dismissible(
      key: ValueKey(notification.id),
      confirmDismiss: (direction) async {
        final toRead = direction == DismissDirection.startToEnd
            ? true
            : !notification.read;
        await onSwipe(toRead);
        return false;
      },
      background: _SwipeBackground(
        label: l10n.notificationsMarkRead,
        icon: Icons.mark_email_read_outlined,
        color: tokens.colors.primary.withValues(alpha: 0.12),
      ),
      secondaryBackground: _SwipeBackground(
        label: notification.read
            ? l10n.notificationsMarkUnread
            : l10n.notificationsMarkRead,
        icon: notification.read
            ? Icons.mark_email_unread_outlined
            : Icons.mark_email_read_outlined,
        color: tokens.colors.surfaceVariant,
        alignEnd: true,
      ),
      child: AppCard(
        backgroundColor: notification.read
            ? tokens.colors.surface
            : Color.alphaBlend(
                tokens.colors.primary.withValues(alpha: 0.04),
                tokens.colors.surface,
              ),
        padding: EdgeInsets.all(tokens.spacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryIcon(
                  icon: _categoryIcon(notification.category),
                  color: categoryColor,
                  unread: !notification.read,
                ),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      Wrap(
                        spacing: tokens.spacing.sm,
                        runSpacing: tokens.spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ActionChip(
                            label: Text(
                              _categoryLabel(notification.category, l10n),
                            ),
                            avatar: Icon(
                              _categoryIcon(notification.category),
                              size: 16,
                            ),
                            onPressed: onTap,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: tokens.colors.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              SizedBox(width: tokens.spacing.xs),
                              Text(
                                timeLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: tokens.colors.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          if (notification.read)
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: tokens.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notification.ctaLabel != null) ...[
              SizedBox(height: tokens.spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(notification.ctaLabel!),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.label,
    required this.icon,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return Container(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.lg),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tokens.colors.onSurface),
          SizedBox(width: tokens.spacing.sm),
          Text(label),
        ],
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.icon,
    required this.color,
    required this.unread,
  });

  final IconData icon;
  final Color color;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final bg = Color.alphaBlend(
      color.withValues(alpha: 0.14),
      tokens.colors.surface,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        if (unread)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tokens.colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.colors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

sealed class _ListEntry {}

class _HeaderEntry extends _ListEntry {
  _HeaderEntry(this.date);

  final DateTime date;
}

class _ItemEntry extends _ListEntry {
  _ItemEntry(this.notification);

  final AppNotification notification;
}

List<_ListEntry> _entriesFor(List<AppNotification> items) {
  final buckets = SplayTreeMap<DateTime, List<AppNotification>>(
    (a, b) => b.compareTo(a),
  );

  for (final item in items) {
    final day = DateUtils.dateOnly(item.createdAt);
    buckets.putIfAbsent(day, () => []).add(item);
  }

  final entries = <_ListEntry>[];
  buckets.forEach((date, list) {
    entries.add(_HeaderEntry(date));
    entries.addAll(list.map(_ItemEntry.new));
  });
  return entries;
}

String _formatHeader(DateTime date, AppLocalizations l10n) {
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = today.difference(date).inDays;
  if (diff == 0) return l10n.notificationsToday;
  if (diff == 1) return l10n.notificationsYesterday;

  const weekdaysJa = ['月', '火', '水', '木', '金', '土', '日'];
  const weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final isJa = l10n.locale.languageCode == 'ja';
  final weekday = isJa
      ? weekdaysJa[date.weekday - 1]
      : weekdaysEn[date.weekday - 1];

  final month = date.month;
  final day = date.day;

  return isJa ? '$month月$day日($weekday)' : '$month/$day ($weekday)';
}

String _timeLabel(DateTime date, AppLocalizations l10n) {
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(date.hour)}:${two(date.minute)}';
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = today.difference(DateUtils.dateOnly(date)).inDays;

  if (diff == 0) return time;
  if (diff == 1) return '${l10n.notificationsYesterday} $time';
  return '${date.month}/${date.day} $time';
}

IconData _categoryIcon(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.order => Icons.local_shipping_outlined,
    NotificationCategory.design => Icons.brush_outlined,
    NotificationCategory.promotion => Icons.local_offer_outlined,
    NotificationCategory.support => Icons.headset_mic_outlined,
    NotificationCategory.system => Icons.info_outline,
    NotificationCategory.security => Icons.verified_user_outlined,
  };
}

String _categoryLabel(NotificationCategory category, AppLocalizations l10n) {
  switch (category) {
    case NotificationCategory.order:
      return l10n.notificationsCategoryOrder;
    case NotificationCategory.design:
      return l10n.notificationsCategoryDesign;
    case NotificationCategory.promotion:
      return l10n.notificationsCategoryPromo;
    case NotificationCategory.support:
      return l10n.notificationsCategorySupport;
    case NotificationCategory.system:
      return l10n.notificationsCategoryStatus;
    case NotificationCategory.security:
      return l10n.notificationsCategorySecurity;
  }
}

Color _categoryColor(NotificationCategory category, DesignTokens tokens) {
  return switch (category) {
    NotificationCategory.order => tokens.colors.primary,
    NotificationCategory.design => tokens.colors.secondary,
    NotificationCategory.promotion => tokens.colors.warning,
    NotificationCategory.support => tokens.colors.success,
    NotificationCategory.system => tokens.colors.onSurface,
    NotificationCategory.security => tokens.colors.error,
  };
}

enum _OverflowAction { markAllRead }
