// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/features/library/data/models/design_share_link_models.dart';
import 'package:app/features/library/view_model/library_design_shares_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class LibraryDesignSharesPage extends ConsumerStatefulWidget {
  const LibraryDesignSharesPage({super.key, required this.designId});

  final String designId;

  @override
  ConsumerState<LibraryDesignSharesPage> createState() =>
      _LibraryDesignSharesPageState();
}

class _LibraryDesignSharesPageState
    extends ConsumerState<LibraryDesignSharesPage> {
  int? _lastFeedbackId;
  late LibraryDesignSharesViewModel _viewModel;
  late final ProviderSubscription<AsyncValue<LibraryDesignSharesState>>
  _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _viewModel = LibraryDesignSharesViewModel(designId: widget.designId);
    _feedbackCancel = ref.container
        .listen<AsyncValue<LibraryDesignSharesState>>(_viewModel, (_, next) {
          if (next case AsyncData(:final value)) {
            _handleFeedback(value);
          }
        });
  }

  @override
  void dispose() {
    _feedbackCancel.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(_viewModel);
    final data = state.valueOrNull;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(prefersEnglish ? 'Share links' : '共有リンク'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Create link' : 'リンクを作成',
            onPressed: data == null || data.isCreating
                ? null
                : () => _createLink(context, prefersEnglish),
            icon: const Icon(Icons.add_link_rounded),
          ),
          SizedBox(width: tokens.spacing.sm),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading() when data == null => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          AsyncError(:final error) when data == null => _ErrorBody(
            prefersEnglish: prefersEnglish,
            message: error.toString(),
            onRetry: () => ref.invalidate(_viewModel),
          ),
          _ => _Body(
            prefersEnglish: prefersEnglish,
            state: data!,
            onRefresh: () => ref.invoke(_viewModel.refresh()),
            onTapLink: (link) =>
                _showLinkActions(context, link, prefersEnglish),
            onRevoke: (link) => _confirmRevoke(context, link, prefersEnglish),
            onShowHistory: () =>
                _showHistory(context, data.historyLinks, prefersEnglish),
          ),
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.sm,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: FilledButton.icon(
            icon: data?.isCreating == true
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      backgroundColor: tokens.colors.onPrimary.withValues(
                        alpha: 0.24,
                      ),
                    ),
                  )
                : const Icon(Icons.add_link_rounded),
            onPressed: data == null || data.isCreating
                ? null
                : () => _createLink(context, prefersEnglish),
            label: Text(prefersEnglish ? 'New link' : '新しいリンク'),
          ),
        ),
      ),
    );
  }

  void _handleFeedback(LibraryDesignSharesState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    final message = _feedbackLabel(feedback, prefersEnglish);
    if (message == null) return;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), message);
  }

  String? _feedbackLabel(String raw, bool prefersEnglish) {
    if (raw.startsWith('created:')) {
      return prefersEnglish ? 'Share link created' : '共有リンクを作成しました';
    }
    if (raw.startsWith('revoked:')) {
      return prefersEnglish ? 'Link revoked' : 'リンクを無効化しました';
    }
    if (raw.startsWith('extended:')) {
      return prefersEnglish ? 'Expiry extended' : '有効期限を延長しました';
    }
    return null;
  }

  Future<void> _createLink(BuildContext context, bool prefersEnglish) async {
    final selection = await showModalBottomSheet<_ExpiryOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExpirySheet(prefersEnglish: prefersEnglish),
    );
    if (selection == null) return;

    final analytics = ref.container.read(analyticsClientProvider);
    unawaited(
      analytics.track(
        const PrimaryActionTappedEvent(label: 'library_share_link_create'),
      ),
    );

    final created = await ref.invoke(_viewModel.create(ttl: selection.ttl));

    if (!context.mounted) return;
    await _copyToClipboard(context, created.url, prefersEnglish);
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    DesignShareLink link,
    bool prefersEnglish,
  ) async {
    final tokens = DesignTokensTheme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prefersEnglish ? 'Revoke link?' : 'リンクを無効化しますか？'),
        content: Text(
          prefersEnglish
              ? 'Anyone with this URL will no longer be able to access it.'
              : 'このURLを持っている人はアクセスできなくなります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.colors.error,
              foregroundColor: tokens.colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(prefersEnglish ? 'Revoke' : '無効化'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final analytics = ref.container.read(analyticsClientProvider);
    unawaited(
      analytics.track(
        const PrimaryActionTappedEvent(label: 'library_share_link_revoke'),
      ),
    );

    await ref.invoke(_viewModel.revoke(link.id));
  }

  Future<void> _showLinkActions(
    BuildContext context,
    DesignShareLink link,
    bool prefersEnglish,
  ) async {
    final action = await showModalBottomSheet<_LinkAction>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _LinkActionsSheet(link: link, prefersEnglish: prefersEnglish),
    );

    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case _LinkAction.copy:
        await _copyToClipboard(context, link.url, prefersEnglish);
        return;
      case _LinkAction.share:
        final analytics = ref.container.read(analyticsClientProvider);
        unawaited(
          analytics.track(
            const SecondaryActionTappedEvent(label: 'library_share_link_share'),
          ),
        );
        await Share.share(link.url);
        return;
      case _LinkAction.extend7Days:
        final analytics = ref.container.read(analyticsClientProvider);
        unawaited(
          analytics.track(
            const SecondaryActionTappedEvent(
              label: 'library_share_link_extend',
            ),
          ),
        );
        await ref.invoke(
          _viewModel.extend(link.id, extendBy: const Duration(days: 7)),
        );
        return;
      case _LinkAction.revoke:
        await _confirmRevoke(context, link, prefersEnglish);
        return;
    }
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value,
    bool prefersEnglish,
  ) async {
    final analytics = ref.container.read(analyticsClientProvider);
    unawaited(
      analytics.track(
        const SecondaryActionTappedEvent(label: 'library_share_link_copy'),
      ),
    );
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Copied to clipboard' : 'コピーしました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showHistory(
    BuildContext context,
    List<DesignShareLink> history,
    bool prefersEnglish,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _HistorySheet(history: history, prefersEnglish: prefersEnglish),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.prefersEnglish,
    required this.state,
    required this.onRefresh,
    required this.onTapLink,
    required this.onRevoke,
    required this.onShowHistory,
  });

  final bool prefersEnglish;
  final LibraryDesignSharesState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<DesignShareLink> onTapLink;
  final ValueChanged<DesignShareLink> onRevoke;
  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final active = state.activeLinks;
    final history = state.historyLinks;
    final revokedCount = history.where((e) => e.isRevoked).length;
    final expiredCount = history.length - revokedCount;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.md,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        children: [
          Text(
            prefersEnglish ? 'Active links' : '有効なリンク',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          if (active.isEmpty)
            AppCard(
              child: Text(
                prefersEnglish
                    ? 'No active links yet. Create one to share this design.'
                    : '有効なリンクはありません。作成して共有しましょう。',
              ),
            )
          else
            ...active.map(
              (link) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                child: AppListTile(
                  onTap: () => onTapLink(link),
                  title: Text(_titleFor(link, prefersEnglish)),
                  subtitle: Text(_subtitleFor(link, prefersEnglish)),
                  trailing: _TrailingActions(
                    link: link,
                    prefersEnglish: prefersEnglish,
                    isBusy: state.busyLinkIds.contains(link.id),
                    onRevoke: () => onRevoke(link),
                  ),
                ),
              ),
            ),
          SizedBox(height: tokens.spacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'History' : '履歴',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'Expired: $expiredCount • Revoked: $revokedCount'
                      : '期限切れ：$expiredCount • 無効化：$revokedCount',
                ),
                if (history.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.md),
                  _HistoryPreview(
                    items: history.take(2).toList(growable: false),
                    prefersEnglish: prefersEnglish,
                  ),
                ],
                SizedBox(height: tokens.spacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: history.isEmpty ? null : onShowHistory,
                    child: Text(prefersEnglish ? 'View more' : 'もっと見る'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(DesignShareLink link, bool prefersEnglish) {
    final prefix = prefersEnglish ? 'Link' : 'リンク';
    final suffix = link.id.length >= 6
        ? link.id.substring(link.id.length - 6)
        : link.id;
    return '$prefix • $suffix';
  }

  String _subtitleFor(DesignShareLink link, bool prefersEnglish) {
    final expiresAt = link.expiresAt;
    final expiry = expiresAt == null
        ? (prefersEnglish ? 'No expiry' : '期限なし')
        : _formatShortDate(expiresAt);
    final usage = prefersEnglish
        ? '${link.openCount} opens'
        : '${link.openCount}回';
    return prefersEnglish ? 'Expires: $expiry • $usage' : '期限：$expiry • $usage';
  }
}

class _TrailingActions extends StatelessWidget {
  const _TrailingActions({
    required this.link,
    required this.prefersEnglish,
    required this.isBusy,
    required this.onRevoke,
  });

  final DesignShareLink link;
  final bool prefersEnglish;
  final bool isBusy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionChip(
          label: Text(_expiryLabel(link, prefersEnglish)),
          onPressed: null,
        ),
        SizedBox(width: tokens.spacing.sm),
        IconButton(
          tooltip: prefersEnglish ? 'Revoke' : '無効化',
          onPressed: isBusy ? null : onRevoke,
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Icon(Icons.block_rounded, color: tokens.colors.error),
        ),
      ],
    );
  }

  String _expiryLabel(DesignShareLink link, bool prefersEnglish) {
    if (link.isRevoked) return prefersEnglish ? 'Revoked' : '無効';
    if (link.isExpired) return prefersEnglish ? 'Expired' : '期限切れ';
    final expiry = link.expiresAt;
    if (expiry == null) return prefersEnglish ? 'No expiry' : '期限なし';
    final days = expiry.difference(DateTime.now()).inDays;
    final safeDays = days < 0 ? 0 : days;
    return prefersEnglish ? 'In ${safeDays}d' : 'あと$safeDays日';
  }
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.items, required this.prefersEnglish});

  final List<DesignShareLink> items;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      children: [
        for (final link in items)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _historyLabel(link, prefersEnglish),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  _formatShortDate(link.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _historyLabel(DesignShareLink link, bool prefersEnglish) {
    final status = link.isRevoked
        ? (prefersEnglish ? 'Revoked' : '無効')
        : (prefersEnglish ? 'Expired' : '期限切れ');
    final suffix = link.id.length >= 6
        ? link.id.substring(link.id.length - 6)
        : link.id;
    return '${prefersEnglish ? 'Link' : 'リンク'} • $suffix • $status';
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.prefersEnglish,
    required this.message,
    required this.onRetry,
  });

  final bool prefersEnglish;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off_rounded, color: tokens.colors.error, size: 44),
          SizedBox(height: tokens.spacing.md),
          Text(
            prefersEnglish ? 'Failed to load links' : 'リンクを読み込めませんでした',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.lg),
          FilledButton(
            onPressed: onRetry,
            child: Text(prefersEnglish ? 'Retry' : '再試行'),
          ),
        ],
      ),
    );
  }
}

enum _ExpiryOption {
  oneDay(Duration(days: 1)),
  sevenDays(Duration(days: 7)),
  thirtyDays(Duration(days: 30));

  const _ExpiryOption(this.ttl);
  final Duration ttl;
}

class _ExpirySheet extends StatelessWidget {
  const _ExpirySheet({required this.prefersEnglish});

  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Link expiry' : '有効期限',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          _OptionTile(
            title: prefersEnglish ? '1 day' : '1日',
            subtitle: prefersEnglish ? 'Short-lived share' : '短時間の共有',
            onTap: () => Navigator.of(context).pop(_ExpiryOption.oneDay),
          ),
          _OptionTile(
            title: prefersEnglish ? '7 days' : '7日',
            subtitle: prefersEnglish ? 'Recommended' : 'おすすめ',
            onTap: () => Navigator.of(context).pop(_ExpiryOption.sevenDays),
          ),
          _OptionTile(
            title: prefersEnglish ? '30 days' : '30日',
            subtitle: prefersEnglish ? 'Longer sharing window' : '長めの共有',
            onTap: () => Navigator.of(context).pop(_ExpiryOption.thirtyDays),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sm),
      child: AppListTile(
        onTap: onTap,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        dense: true,
      ),
    );
  }
}

enum _LinkAction { copy, share, extend7Days, revoke }

class _LinkActionsSheet extends StatelessWidget {
  const _LinkActionsSheet({required this.link, required this.prefersEnglish});

  final DesignShareLink link;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final canExtend = !link.isRevoked;
    final canRevoke = !link.isRevoked;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Link actions' : 'リンク操作',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          _ActionTile(
            icon: Icons.copy_rounded,
            label: prefersEnglish ? 'Copy link' : 'リンクをコピー',
            onTap: () => Navigator.of(context).pop(_LinkAction.copy),
          ),
          _ActionTile(
            icon: Icons.ios_share_rounded,
            label: prefersEnglish ? 'Share' : '共有',
            onTap: () => Navigator.of(context).pop(_LinkAction.share),
          ),
          _ActionTile(
            icon: Icons.schedule_rounded,
            label: prefersEnglish ? 'Extend expiry (+7d)' : '期限を延長（+7日）',
            onTap: canExtend
                ? () => Navigator.of(context).pop(_LinkAction.extend7Days)
                : null,
          ),
          _ActionTile(
            icon: Icons.block_rounded,
            label: prefersEnglish ? 'Revoke' : '無効化',
            onTap: canRevoke
                ? () => Navigator.of(context).pop(_LinkAction.revoke)
                : null,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = destructive ? tokens.colors.error : tokens.colors.onSurface;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sm),
      child: AppListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(label),
        dense: true,
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.history, required this.prefersEnglish});

  final List<DesignShareLink> history;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.sm,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Link history' : 'リンク履歴',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          if (history.isEmpty)
            Text(prefersEnglish ? 'No history yet.' : '履歴はありません。')
          else
            ...history.map(
              (link) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                child: AppListTile(
                  title: Text(_titleFor(link, prefersEnglish)),
                  subtitle: Text(_detailFor(link, prefersEnglish)),
                  dense: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _titleFor(DesignShareLink link, bool prefersEnglish) {
    final suffix = link.id.length >= 6
        ? link.id.substring(link.id.length - 6)
        : link.id;
    return '${prefersEnglish ? 'Link' : 'リンク'} • $suffix';
  }

  String _detailFor(DesignShareLink link, bool prefersEnglish) {
    final status = link.isRevoked
        ? (prefersEnglish ? 'Revoked' : '無効')
        : (prefersEnglish ? 'Expired' : '期限切れ');
    final when = link.isRevoked ? link.revokedAt : link.expiresAt;
    final whenLabel = when == null ? '-' : _formatShortDate(when);
    return prefersEnglish ? '$status • $whenLabel' : '$status • $whenLabel';
  }
}

String _formatShortDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}
