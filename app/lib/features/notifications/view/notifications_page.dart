// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:collection';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/features/notifications/data/models/notification_models.dart';
import 'package:app/features/notifications/data/providers/unread_notifications_provider.dart';
import 'package:app/features/notifications/view_model/notifications_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final state = ref.watch(notificationsViewModel);
    final prefersEnglish = gates.prefersEnglish;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _NotificationsAppBar(
        unread: unread,
        onMarkAllRead: _handleMarkAllRead,
        prefersEnglish: prefersEnglish,
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
                prefersEnglish: prefersEnglish,
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
                  prefersEnglish: prefersEnglish,
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
    required bool prefersEnglish,
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
          title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
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
          ? (prefersEnglish ? 'You are all caught up.' : '未読はありません。')
          : (prefersEnglish ? 'No notifications yet.' : '通知はまだありません。');

      final cta = prefersEnglish ? 'Refresh' : '更新する';

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: tokens.spacing.xl),
          AppEmptyState(
            title: prefersEnglish ? 'Inbox is clear' : 'お知らせはありません',
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
                      prefersEnglish ? 'Pull to load more' : '引っ張って続きを読み込む',
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
              _formatHeader(date, prefersEnglish),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _ItemEntry(:final notification) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _NotificationTile(
              notification: notification,
              prefersEnglish: prefersEnglish,
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

    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    final message = read
        ? (prefersEnglish ? 'Marked as read' : '既読にしました')
        : (prefersEnglish ? 'Moved back to unread' : '未読に戻しました');

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: prefersEnglish ? 'Undo' : '元に戻す',
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
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    await ref.invoke(notificationsViewModel.markAllRead());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(prefersEnglish ? 'All caught up' : 'すべて既読にしました')),
    );
  }
}

class _NotificationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _NotificationsAppBar({
    required this.unread,
    required this.onMarkAllRead,
    required this.prefersEnglish,
  });

  final AsyncValue<int> unread;
  final Future<void> Function() onMarkAllRead;
  final bool prefersEnglish;

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
          Text(prefersEnglish ? 'Notifications' : 'お知らせ'),
          if (unreadCount > 0)
            Text(
              prefersEnglish ? '$unreadCount unread' : '未読 $unreadCount 件',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      actions: [
        PopupMenuButton<_OverflowAction>(
          tooltip: prefersEnglish ? 'More' : 'その他の操作',
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
                  Text(prefersEnglish ? 'Mark all read' : 'すべて既読にする'),
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
    required this.prefersEnglish,
    required this.onSelected,
  });

  final NotificationFilter selected;
  final bool prefersEnglish;
  final Future<void> Function(NotificationFilter) onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<NotificationFilter>(
      segments: [
        ButtonSegment(
          value: NotificationFilter.all,
          label: Text(prefersEnglish ? 'All' : 'すべて'),
          icon: const Icon(Icons.inbox_rounded),
        ),
        ButtonSegment(
          value: NotificationFilter.unread,
          label: Text(prefersEnglish ? 'Unread' : '未読'),
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
    required this.prefersEnglish,
    required this.onTap,
    required this.onSwipe,
  });

  final AppNotification notification;
  final bool prefersEnglish;
  final VoidCallback onTap;
  final Future<void> Function(bool) onSwipe;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final categoryColor = _categoryColor(notification.category, tokens);
    final timeLabel = _timeLabel(notification.createdAt, prefersEnglish);

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
        label: prefersEnglish ? 'Mark read' : '既読にする',
        icon: Icons.mark_email_read_outlined,
        color: tokens.colors.primary.withValues(alpha: 0.12),
      ),
      secondaryBackground: _SwipeBackground(
        label: notification.read
            ? (prefersEnglish ? 'Mark unread' : '未読に戻す')
            : (prefersEnglish ? 'Mark read' : '既読にする'),
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
                              _categoryLabel(
                                notification.category,
                                prefersEnglish,
                              ),
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

String _formatHeader(DateTime date, bool prefersEnglish) {
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = today.difference(date).inDays;
  if (diff == 0) return prefersEnglish ? 'Today' : '今日';
  if (diff == 1) return prefersEnglish ? 'Yesterday' : '昨日';

  const weekdaysJa = ['月', '火', '水', '木', '金', '土', '日'];
  const weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = prefersEnglish
      ? weekdaysEn[date.weekday - 1]
      : weekdaysJa[date.weekday - 1];

  final month = date.month;
  final day = date.day;

  return prefersEnglish ? '$month/$day ($weekday)' : '$month月$day日($weekday)';
}

String _timeLabel(DateTime date, bool prefersEnglish) {
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(date.hour)}:${two(date.minute)}';
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = today.difference(DateUtils.dateOnly(date)).inDays;

  if (diff == 0) return time;
  if (diff == 1) return prefersEnglish ? 'Yesterday $time' : '昨日 $time';
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

String _categoryLabel(NotificationCategory category, bool prefersEnglish) {
  switch (category) {
    case NotificationCategory.order:
      return prefersEnglish ? 'Order' : '注文';
    case NotificationCategory.design:
      return prefersEnglish ? 'Design' : 'デザイン';
    case NotificationCategory.promotion:
      return prefersEnglish ? 'Promo' : 'お得情報';
    case NotificationCategory.support:
      return prefersEnglish ? 'Support' : 'サポート';
    case NotificationCategory.system:
      return prefersEnglish ? 'Status' : 'お知らせ';
    case NotificationCategory.security:
      return prefersEnglish ? 'Security' : 'セキュリティ';
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
