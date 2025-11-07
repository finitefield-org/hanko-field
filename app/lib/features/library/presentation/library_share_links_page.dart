import 'dart:async';

import 'package:app/core/monitoring/analytics_controller.dart';
import 'package:app/core/monitoring/analytics_events.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/features/library/application/library_entry_detail_provider.dart';
import 'package:app/features/library/application/library_share_links_controller.dart';
import 'package:app/features/library/domain/library_share_link.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class LibraryShareLinksPage extends ConsumerStatefulWidget {
  const LibraryShareLinksPage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<LibraryShareLinksPage> createState() =>
      _LibraryShareLinksPageState();
}

class _LibraryShareLinksPageState extends ConsumerState<LibraryShareLinksPage> {
  ProviderSubscription<LibraryShareLinksState>? _subscription;

  LibraryShareLinksController get _controller =>
      ref.read(libraryShareLinksControllerProvider(widget.designId).notifier);

  @override
  void initState() {
    super.initState();
    final provider = libraryShareLinksControllerProvider(widget.designId);
    _subscription = ref.listenManual(provider, (previous, next) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final l10n = AppLocalizations.of(context);
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryShareLinksErrorGeneric)),
        );
        _controller.clearFeedback();
      }
      final feedback = next.feedback;
      if (feedback != null && feedback != previous?.feedback) {
        final message = switch (feedback.type) {
          LibraryShareLinksFeedbackType.created =>
            l10n.libraryShareLinksCreatedSnack,
          LibraryShareLinksFeedbackType.extended =>
            l10n.libraryShareLinksExtendSnack,
          LibraryShareLinksFeedbackType.revoked =>
            l10n.libraryShareLinksRevokeSnack,
        };
        messenger.showSnackBar(SnackBar(content: Text(message)));
        _controller.clearFeedback();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = ref.read(analyticsControllerProvider.notifier);
      unawaited(
        analytics.logScreenView(
          const ScreenViewAnalyticsEvent(
            screenName: 'library_shares',
            screenClass: 'LibraryShareLinksPage',
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = libraryShareLinksControllerProvider(widget.designId);
    final state = ref.watch(provider);
    final designAsync = ref.watch(libraryDesignProvider(widget.designId));
    final designName = designAsync.maybeWhen(
      data: (design) => design.input?.rawName ?? design.id,
      orElse: () => widget.designId,
    );

    final body = state.isLoading && state.links.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            displacement: 72,
            onRefresh: () => _controller.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTokens.spaceL),
              children: [
                _DesignSummaryCard(
                  designName: designName,
                  designId: widget.designId,
                ),
                const SizedBox(height: AppTokens.spaceL),
                _buildActiveSection(context, state, l10n),
                const SizedBox(height: AppTokens.spaceL),
                _HistoryCard(
                  history: state.historyLinks,
                  onViewHistory: state.historyLinks.isEmpty
                      ? null
                      : () => _showHistorySheet(state.historyLinks, l10n),
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryShareLinksTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.libraryShareLinksCreateTooltip,
            icon: state.isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link_outlined),
            onPressed: state.isCreating ? null : _handleCreateLink,
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: FilledButton.icon(
          icon: state.isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_link_outlined),
          label: Text(l10n.libraryShareLinksCreateCta),
          onPressed: state.isCreating ? null : _handleCreateLink,
        ),
      ),
    );
  }

  Widget _buildActiveSection(
    BuildContext context,
    LibraryShareLinksState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final active = state.activeLinks;
    if (active.isEmpty) {
      return AppEmptyState(
        icon: const Icon(Icons.ios_share_outlined),
        title: l10n.libraryShareLinksEmptyTitle,
        message: l10n.libraryShareLinksEmptySubtitle,
        primaryAction: AppButton(
          label: l10n.libraryShareLinksCreateCta,
          onPressed: state.isCreating ? null : _handleCreateLink,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.libraryShareLinksSectionActive,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        ...active.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
            child: _ShareLinkTile(
              link: link,
              l10n: l10n,
              extending: state.extending.contains(link.id),
              revoking: state.revoking.contains(link.id),
              onCopy: () => _handleCopyLink(link),
              onShare: () => _handleShareLink(link),
              onExtend: () => _handleExtendLink(link),
              onRevoke: () => _controller.revokeLink(link.id),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateLink() async {
    await _controller.createLink();
  }

  Future<void> _handleCopyLink(LibraryShareLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.libraryExportCopySnack)));
    _logLinkAction(link, 'copy');
  }

  Future<void> _handleShareLink(LibraryShareLink link) async {
    final l10n = AppLocalizations.of(context);
    await Share.share(
      link.url,
      subject: l10n.libraryShareLinksShareSubject(widget.designId),
    );
    _logLinkAction(link, 'share');
  }

  Future<void> _handleExtendLink(LibraryShareLink link) async {
    final l10n = AppLocalizations.of(context);
    final durationDays = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.libraryShareLinksExtendSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                ...[7, 30, 90].map(
                  (days) => ListTile(
                    title: Text(l10n.libraryShareLinksExtendOptionDays(days)),
                    onTap: () => Navigator.of(context).pop(days),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (durationDays == null) {
      return;
    }
    await _controller.extendLink(
      link.id,
      extension: Duration(days: durationDays),
    );
  }

  void _showHistorySheet(
    List<LibraryShareLink> history,
    AppLocalizations l10n,
  ) {
    if (history.isEmpty) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.libraryShareLinksHistorySheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final link = history[index];
                      return ListTile(
                        leading: Icon(
                          link.status == LibraryShareLinkStatus.revoked
                              ? Icons.shield_outlined
                              : Icons.timer_off,
                        ),
                        title: Text(link.label ?? link.id),
                        subtitle: Text(_historySubtitle(link, l10n)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _historySubtitle(LibraryShareLink link, AppLocalizations l10n) {
    final timestamp = _formatTimestamp(
      link.status == LibraryShareLinkStatus.revoked
          ? (link.revokedAt ?? link.expiresAt ?? link.createdAt)
          : (link.expiresAt ?? link.createdAt),
      l10n,
    );
    if (link.status == LibraryShareLinkStatus.revoked) {
      return l10n.libraryShareLinksRevokedOn(timestamp);
    }
    return l10n.libraryShareLinksExpiredOn(timestamp);
  }

  void _logLinkAction(LibraryShareLink link, String action) {
    final analytics = ref.read(analyticsControllerProvider.notifier);
    unawaited(
      analytics.logEvent(
        LibraryShareLinkActionEvent(
          designId: widget.designId,
          linkId: link.id,
          action: action,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value, AppLocalizations l10n) {
    return DateFormat.yMMMd(l10n.localeName).add_Hm().format(value);
  }
}

class _DesignSummaryCard extends StatelessWidget {
  const _DesignSummaryCard({required this.designName, required this.designId});

  final String designName;
  final String designId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.library_books_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(designName),
        subtitle: Text(designId),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.onViewHistory});

  final List<LibraryShareLink> history;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = history.length;
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.libraryShareLinksHistoryTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              count > 0
                  ? l10n.libraryShareLinksHistorySummary(count)
                  : l10n.libraryShareLinksHistoryEmpty,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewHistory,
                child: Text(l10n.libraryShareLinksHistoryAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLinkTile extends StatelessWidget {
  const _ShareLinkTile({
    required this.link,
    required this.l10n,
    required this.extending,
    required this.revoking,
    required this.onCopy,
    required this.onShare,
    required this.onExtend,
    required this.onRevoke,
  });

  final LibraryShareLink link;
  final AppLocalizations l10n;
  final bool extending;
  final bool revoking;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onExtend;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.link_outlined)),
              title: Text(link.label ?? link.id),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.url,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTokens.spaceXS),
                  Text(_usageLabel(l10n)),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    avatar: const Icon(Icons.timelapse_outlined, size: 18),
                    label: Text(_expiryLabel(l10n)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: l10n.libraryShareLinksRevokeTooltip,
                    icon: revoking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shield_outlined),
                    onPressed: revoking ? null : onRevoke,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceS),
            Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l10n.libraryShareLinksCopyAction),
                  onPressed: onCopy,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(l10n.libraryShareLinksShareAction),
                  onPressed: onShare,
                ),
                TextButton.icon(
                  icon: extending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_outlined),
                  label: Text(l10n.libraryShareLinksExtendAction),
                  onPressed: extending ? null : onExtend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(AppLocalizations l10n) {
    final expires = link.expiresAt;
    if (expires == null) {
      return l10n.libraryShareLinksExpiryNever;
    }
    final formatted = DateFormat.MMMd(l10n.localeName).add_Hm().format(expires);
    return l10n.libraryShareLinksExpiryLabel(formatted);
  }

  String _usageLabel(AppLocalizations l10n) {
    final visits = l10n.libraryShareLinksVisitsLabel(link.accessCount);
    final buffer = StringBuffer(visits);
    if (link.maxAccessCount != null) {
      buffer.write(' • ');
      buffer.write(l10n.libraryShareLinksUsageCap(link.maxAccessCount!));
    }
    if (link.lastAccessedAt != null) {
      buffer.write(' • ');
      final timestamp = DateFormat.MMMd(
        l10n.localeName,
      ).add_Hm().format(link.lastAccessedAt!);
      buffer.write(l10n.libraryShareLinksLastOpened(timestamp));
    }
    return buffer.toString();
  }
}
