import 'dart:async';
import 'dart:math';

import 'package:app/core/ui/widgets/app_help_overlay.dart';
import 'package:app/core/ui/widgets/app_top_app_bar.dart';
import 'package:app/features/notifications/application/notification_navigation_handler.dart';
import 'package:app/features/notifications/application/notifications_list_controller.dart';
import 'package:app/features/notifications/domain/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class NotificationInboxPage extends ConsumerStatefulWidget {
  const NotificationInboxPage({super.key});

  @override
  ConsumerState<NotificationInboxPage> createState() =>
      _NotificationInboxPageState();
}

class _NotificationInboxPageState extends ConsumerState<NotificationInboxPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  NotificationsListController get _controller =>
      ref.read(notificationsListControllerProvider.notifier);

  NotificationNavigationHandler get _navigation =>
      ref.read(notificationNavigationHandlerProvider);

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final metrics = _scrollController.position;
    if (metrics.extentAfter > 320) {
      return;
    }
    _controller.loadMore();
  }

  Future<void> _refresh() async {
    try {
      await _controller.refresh();
    } catch (error) {
      _showSnackBar('最新のお知らせを取得できませんでした');
    }
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _handleMarkAllRead() async {
    try {
      await _controller.markAllAsRead();
      _showSnackBar('すべて既読にしました');
    } catch (_) {
      _showSnackBar('一括既読に失敗しました');
    }
  }

  Future<void> _handleToggleRead(
    AppNotification notification,
    bool read,
  ) async {
    final previous = notification.read;
    if (previous == read) {
      return;
    }
    try {
      await _controller.setReadState(id: notification.id, read: read);
      final label = read ? '既読' : '未読';
      _showSnackBar(
        '${notification.title} を$labelにしました',
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            unawaited(
              _controller
                  .setReadState(id: notification.id, read: previous)
                  .catchError((_) {
                    _showSnackBar('元に戻せませんでした');
                    return null;
                  }),
            );
          },
        ),
      );
    } catch (_) {
      _showSnackBar('お知らせの更新に失敗しました');
    }
  }

  Future<void> _handleOpen(AppNotification notification) async {
    final opened = await _navigation.open(notification);
    if (!opened) {
      _showSnackBar('このお知らせでは移動できません');
      return;
    }
    if (!notification.read) {
      try {
        await _controller.setReadState(id: notification.id, read: true);
      } catch (_) {
        // Ignore failure to auto-mark read
      }
    }
  }

  Future<bool> _handleDismiss(
    AppNotification notification,
    DismissDirection direction,
  ) async {
    final markRead = switch (direction) {
      DismissDirection.startToEnd => true,
      DismissDirection.endToStart => false,
      _ => notification.read,
    };
    await _handleToggleRead(notification, markRead);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(notificationsListControllerProvider);
    final filter = ref.watch(notificationFilterProvider);
    final state = asyncState.asData?.value;
    final unreadCount = state?.unreadCount ?? 0;

    void openHelp() {
      showHelpOverlay(context, contextLabel: 'お知らせ');
    }

    final overflow = PopupMenuButton<_OverflowAction>(
      tooltip: '表示オプション',
      onSelected: (action) {
        switch (action) {
          case _OverflowAction.markAllRead:
            _handleMarkAllRead();
          case _OverflowAction.refresh:
            _refresh();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _OverflowAction.markAllRead,
          enabled: unreadCount > 0,
          child: const Text('すべて既読にする'),
        ),
        const PopupMenuItem(
          value: _OverflowAction.refresh,
          child: Text('最新の情報に更新'),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );

    return AppShortcutRegistrar(
      onHelpTap: openHelp,
      child: Scaffold(
        appBar: AppTopAppBar(
          title: 'お知らせ',
          centerTitle: true,
          showNotificationAction: false,
          showSearchAction: false,
          helpContextLabel: 'お知らせ',
          onHelpTap: openHelp,
          trailingActions: [overflow],
        ),
        body: SafeArea(
          child: asyncState.when(
            data: (value) => _InboxBody(
              state: value,
              filter: filter,
              scrollController: _scrollController,
              onRefresh: _refresh,
              onChangeFilter: (next) => _controller.changeFilter(next),
              onOpen: _handleOpen,
              onToggleRead: _handleToggleRead,
              onDismiss: _handleDismiss,
            ),
            loading: () => _LoadingList(controller: _scrollController),
            error: (error, _) =>
                _InboxError(onRetry: _refresh, message: 'お知らせの読み込みに失敗しました'),
          ),
        ),
      ),
    );
  }
}

class _InboxBody extends StatelessWidget {
  const _InboxBody({
    required this.state,
    required this.filter,
    required this.scrollController,
    required this.onRefresh,
    required this.onChangeFilter,
    required this.onOpen,
    required this.onToggleRead,
    required this.onDismiss,
  });

  final NotificationsListState state;
  final NotificationFilter filter;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(NotificationFilter filter) onChangeFilter;
  final void Function(AppNotification notification) onOpen;
  final Future<void> Function(AppNotification notification, bool read)
  onToggleRead;
  final Future<bool> Function(
    AppNotification notification,
    DismissDirection direction,
  )
  onDismiss;

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections(state.items);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 24,
      child: ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _Header(
            unreadCount: state.unreadCount,
            filter: filter,
            isRefreshing: state.isRefreshing,
            onChangeFilter: onChangeFilter,
          ),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            _EmptyState(filter: filter)
          else
            for (final section in sections) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(section.label, style: theme.textTheme.titleSmall),
              ),
              for (final entry in section.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationCard(
                    notification: entry,
                    pending: state.pendingUpdates.contains(entry.id),
                    onOpen: onOpen,
                    onToggleRead: onToggleRead,
                    onDismiss: onDismiss,
                  ),
                ),
            ],
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.unreadCount,
    required this.filter,
    required this.isRefreshing,
    required this.onChangeFilter,
  });

  final int unreadCount;
  final NotificationFilter filter;
  final bool isRefreshing;
  final void Function(NotificationFilter filter) onChangeFilter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selection = <NotificationFilter>{filter};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('未読 $unreadCount 件', style: textTheme.titleMedium),
            if (isRefreshing) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<NotificationFilter>(
          segments: const [
            ButtonSegment(value: NotificationFilter.all, label: Text('すべて')),
            ButtonSegment(
              value: NotificationFilter.unread,
              label: Text('未読のみ'),
            ),
          ],
          selected: selection,
          onSelectionChanged: (values) {
            if (values.isEmpty) {
              return;
            }
            onChangeFilter(values.first);
          },
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.pending,
    required this.onOpen,
    required this.onToggleRead,
    required this.onDismiss,
  });

  final AppNotification notification;
  final bool pending;
  final void Function(AppNotification notification) onOpen;
  final Future<void> Function(AppNotification notification, bool read)
  onToggleRead;
  final Future<bool> Function(
    AppNotification notification,
    DismissDirection direction,
  )
  onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = _visualFor(notification.category);
    final read = notification.read;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: read ? FontWeight.w500 : FontWeight.bold,
      color: read
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: read
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface.withValues(alpha: 0.85),
    );
    final surface = theme.colorScheme.surface;
    final unreadBlend = theme.colorScheme.primary.withValues(alpha: 0.08);
    final cardColor = read ? surface : Color.alphaBlend(unreadBlend, surface);
    final indicatorColor = read
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.7);
    final iconColor = read
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onPrimaryContainer;

    final chipLabel = notification.action?.label ?? visuals.chipLabel;
    final timeLabel = DateFormat.Hm().format(notification.timestamp.toLocal());

    final child = Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: pending ? null : () => onOpen(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visuals.icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(notification.body, style: subtitleStyle),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          timeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (chipLabel != null)
                          ActionChip(
                            label: Text(chipLabel),
                            avatar: notification.action != null
                                ? Icon(visuals.assistIcon, size: 18)
                                : null,
                            onPressed: (pending || notification.action == null)
                                ? null
                                : () => onOpen(notification),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  IconButton(
                    tooltip: read ? '未読に戻す' : '既読にする',
                    icon: Icon(
                      read
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                    onPressed: pending
                        ? null
                        : () => onToggleRead(notification, !read),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey(notification.id),
      confirmDismiss: (direction) => onDismiss(notification, direction),
      background: _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.mark_email_read_outlined,
        label: '既読',
        color: theme.colorScheme.primaryContainer,
      ),
      secondaryBackground: _SwipeActionBackground(
        alignment: Alignment.centerRight,
        icon: Icons.mark_email_unread_outlined,
        label: '未読',
        color: theme.colorScheme.secondaryContainer,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: read
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: 6,
      itemBuilder: (context, index) {
        final opacity = pow(0.85, index).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ShimmerPlaceholder(opacity: opacity),
        );
      },
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({required this.opacity, super.key});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final alpha = (0.3 + opacity * 0.4).clamp(0.0, 1.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 88,
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  const _InboxError({required this.onRetry, required this.message});

  final Future<void> Function() onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final NotificationFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = filter == NotificationFilter.unread
        ? '未読のお知らせはありません'
        : 'お知らせはありません';
    final subtitle = filter == NotificationFilter.unread
        ? '既読タブで過去のお知らせを確認できます'
        : '新しい更新が届いたらここに表示されます';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 56),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationSection {
  _NotificationSection({required this.label, required this.items});

  final String label;
  final List<AppNotification> items;
}

List<_NotificationSection> _buildSections(List<AppNotification> items) {
  if (items.isEmpty) {
    return const [];
  }
  final sorted = List<AppNotification>.from(items)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final sections = <_NotificationSection>[];
  DateTime? currentDate;
  final now = DateTime.now();
  final buffer = <AppNotification>[];

  void flush() {
    final date = currentDate;
    if (date == null || buffer.isEmpty) {
      return;
    }
    sections.add(
      _NotificationSection(
        label: _formatSectionLabel(date, now),
        items: List<AppNotification>.from(buffer, growable: false),
      ),
    );
    buffer.clear();
  }

  for (final notification in sorted) {
    final ts = notification.timestamp.toLocal();
    final key = DateUtils.dateOnly(ts);
    final date = currentDate;
    if (date == null || !DateUtils.isSameDay(date, key)) {
      flush();
      currentDate = key;
    }
    buffer.add(notification);
  }
  flush();
  return sections;
}

String _formatSectionLabel(DateTime date, DateTime now) {
  if (DateUtils.isSameDay(date, now)) {
    return '今日';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (DateUtils.isSameDay(date, yesterday)) {
    return '昨日';
  }
  final formatter = DateFormat.MMMMd();
  return formatter.format(date);
}

class _CategoryVisuals {
  const _CategoryVisuals({
    required this.icon,
    required this.chipLabel,
    required this.assistIcon,
  });

  final IconData icon;
  final String? chipLabel;
  final IconData assistIcon;
}

_CategoryVisuals _visualFor(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.order:
      return const _CategoryVisuals(
        icon: Icons.inventory_2_outlined,
        chipLabel: '注文',
        assistIcon: Icons.local_shipping_outlined,
      );
    case NotificationCategory.production:
      return const _CategoryVisuals(
        icon: Icons.precision_manufacturing_outlined,
        chipLabel: '制作',
        assistIcon: Icons.timeline_outlined,
      );
    case NotificationCategory.promotion:
      return const _CategoryVisuals(
        icon: Icons.discount_outlined,
        chipLabel: 'キャンペーン',
        assistIcon: Icons.open_in_new,
      );
    case NotificationCategory.guide:
      return const _CategoryVisuals(
        icon: Icons.menu_book_outlined,
        chipLabel: 'ガイド',
        assistIcon: Icons.open_in_new,
      );
    case NotificationCategory.system:
      return const _CategoryVisuals(
        icon: Icons.notifications_active_outlined,
        chipLabel: 'システム',
        assistIcon: Icons.settings_outlined,
      );
  }
}

enum _OverflowAction { markAllRead, refresh }
