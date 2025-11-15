import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/features/profile/application/profile_export_controller.dart';
import 'package:app/features/profile/domain/data_export.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ProfileExportScreen extends ConsumerWidget {
  const ProfileExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileExportControllerProvider);
    final controller = ref.read(profileExportControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ProfileExportError(
            message: l10n.profileExportLoadError,
            actionLabel: l10n.profileExportRetryLabel,
            onRetry: controller.reload,
          ),
          data: (state) => _ProfileExportBody(
            state: state,
            l10n: l10n,
            onRefresh: controller.reload,
            onToggleAssets: controller.setIncludeAssets,
            onToggleOrders: controller.setIncludeOrders,
            onToggleHistory: controller.setIncludeHistory,
            onStartExport: () => _handleStartExport(context, controller, l10n),
            onDownloadArchive: (archiveId) =>
                _handleDownloadArchive(context, controller, l10n, archiveId),
            onViewHistory: () => _showHistorySheet(context),
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartExport(
    BuildContext context,
    ProfileExportController controller,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await controller.startExport();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileExportRequestStarted)),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileExportRequestError),
            backgroundColor: errorColor,
          ),
        );
    }
  }

  Future<void> _handleDownloadArchive(
    BuildContext context,
    ProfileExportController controller,
    AppLocalizations l10n,
    String archiveId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final uri = await controller.downloadArchive(archiveId);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.profileExportDownloadStarted(uri.host))),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.profileExportDownloadError),
            backgroundColor: errorColor,
          ),
        );
    }
  }

  Future<void> _showHistorySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final asyncState = ref.watch(profileExportControllerProvider);
            final controller = ref.read(
              profileExportControllerProvider.notifier,
            );
            final l10n = AppLocalizations.of(context);
            final state = asyncState.value;
            if (state == null) {
              return const Padding(
                padding: EdgeInsets.all(AppTokens.spaceL),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _ExportHistorySheet(
              state: state,
              l10n: l10n,
              onDownloadArchive: (archiveId) =>
                  _handleDownloadArchive(context, controller, l10n, archiveId),
            );
          },
        );
      },
    );
  }
}

class _ProfileExportBody extends StatelessWidget {
  const _ProfileExportBody({
    required this.state,
    required this.l10n,
    required this.onRefresh,
    required this.onToggleAssets,
    required this.onToggleOrders,
    required this.onToggleHistory,
    required this.onStartExport,
    required this.onDownloadArchive,
    required this.onViewHistory,
  });

  final ProfileExportState state;
  final AppLocalizations l10n;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onToggleAssets;
  final ValueChanged<bool> onToggleOrders;
  final ValueChanged<bool> onToggleHistory;
  final Future<void> Function() onStartExport;
  final Future<void> Function(String archiveId) onDownloadArchive;
  final Future<void> Function() onViewHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: AppTokens.spaceL,
      displacement: AppTokens.spaceXL,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            centerTitle: true,
            pinned: true,
            title: Text(l10n.profileExportTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppTokens.spaceM),
                child: _ExportStatusBadge(state: state, l10n: l10n),
              ),
            ],
            bottom: state.isRefreshing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceL,
              AppTokens.spaceXL,
            ),
            sliver: SliverList.list(
              children: [
                _ExportSummaryCard(state: state, l10n: l10n),
                const SizedBox(height: AppTokens.spaceL),
                _LatestArchiveCard(
                  state: state,
                  l10n: l10n,
                  onDownloadArchive: onDownloadArchive,
                ),
                const SizedBox(height: AppTokens.spaceL),
                _ExportPreferencesCard(
                  state: state,
                  l10n: l10n,
                  onToggleAssets: onToggleAssets,
                  onToggleOrders: onToggleOrders,
                  onToggleHistory: onToggleHistory,
                ),
                const SizedBox(height: AppTokens.spaceL),
                _ExportCtaSection(
                  state: state,
                  l10n: l10n,
                  onStartExport: onStartExport,
                  onViewHistory: onViewHistory,
                ),
                const SizedBox(height: AppTokens.spaceXL),
                Text(
                  l10n.profileExportSupportNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportStatusBadge extends StatelessWidget {
  const _ExportStatusBadge({required this.state, required this.l10n});

  final ProfileExportState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final archive = state.latestArchive;
    final badge = _StatusBadge(
      label: archive == null
          ? l10n.profileExportStatusNever
          : switch (archive.status) {
              DataExportStatus.preparing => l10n.profileExportStatusPreparing,
              DataExportStatus.ready => l10n.profileExportStatusReady,
              DataExportStatus.expired => l10n.profileExportStatusExpired,
              DataExportStatus.failed => l10n.profileExportStatusFailed,
            },
      color: archive == null
          ? scheme.outlineVariant
          : switch (archive.status) {
              DataExportStatus.preparing => scheme.tertiary,
              DataExportStatus.ready => scheme.primary,
              DataExportStatus.expired => scheme.error,
              DataExportStatus.failed => scheme.error,
            },
    );
    final child = Icon(
      Icons.cloud_download_outlined,
      color: scheme.onSurfaceVariant,
    );
    return Badge(
      backgroundColor: badge.color,
      textColor: scheme.onPrimary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceS,
        vertical: AppTokens.spaceXS,
      ),
      largeSize: 28,
      label: Text(
        badge.label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onPrimary),
      ),
      child: child,
    );
  }
}

class _StatusBadge {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;
}

class _ExportSummaryCard extends StatelessWidget {
  const _ExportSummaryCard({required this.state, required this.l10n});

  final ProfileExportState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final estimated = state.snapshot.estimatedDuration;
    final minutes = estimated.inMinutes.clamp(1, 90);
    return AppCard(
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppTokens.radiusS,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(AppTokens.spaceS),
                  child: Icon(Icons.file_present_outlined),
                ),
              ),
              const SizedBox(width: AppTokens.spaceM),
              Expanded(
                child: Text(
                  l10n.profileExportSummaryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.profileExportSummaryDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppTokens.spaceS),
              Expanded(
                child: Text(
                  l10n.profileExportEstimatedDuration(minutes),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceS),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTokens.spaceS),
              Expanded(
                child: Text(
                  l10n.profileExportSecurityNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestArchiveCard extends StatelessWidget {
  const _LatestArchiveCard({
    required this.state,
    required this.l10n,
    required this.onDownloadArchive,
  });

  final ProfileExportState state;
  final AppLocalizations l10n;
  final Future<void> Function(String archiveId) onDownloadArchive;

  @override
  Widget build(BuildContext context) {
    final archive = state.latestArchive;
    if (archive == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileExportLatestEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Text(
              l10n.profileExportLatestEmptySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final isProcessing = archive.status == DataExportStatus.preparing;
    final isReady = archive.status == DataExportStatus.ready;
    final isExpired = archive.status == DataExportStatus.expired;
    final scheme = Theme.of(context).colorScheme;
    final requestedAt = archive.completedAt ?? archive.requestedAt;
    final locale = l10n.localeName;
    final requestedLabel = _formatDateTime(requestedAt, locale);
    final expiresLabel = archive.expiresAt == null
        ? null
        : _formatDateTime(archive.expiresAt!, locale);
    final sizeLabel = _formatFileSize(archive.sizeBytes);
    final isDownloading = state.isDownloading(archive.id);
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.profileExportLatestArchiveTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _StatusChip(
                label: switch (archive.status) {
                  DataExportStatus.preparing =>
                    l10n.profileExportStatusPreparing,
                  DataExportStatus.ready => l10n.profileExportStatusReady,
                  DataExportStatus.expired => l10n.profileExportStatusExpired,
                  DataExportStatus.failed => l10n.profileExportStatusFailed,
                },
                color: switch (archive.status) {
                  DataExportStatus.preparing => scheme.tertiaryContainer,
                  DataExportStatus.ready => scheme.secondaryContainer,
                  DataExportStatus.expired => scheme.errorContainer,
                  DataExportStatus.failed => scheme.errorContainer,
                },
                textColor: switch (archive.status) {
                  DataExportStatus.preparing => scheme.onTertiaryContainer,
                  DataExportStatus.ready => scheme.onSecondaryContainer,
                  DataExportStatus.expired => scheme.onErrorContainer,
                  DataExportStatus.failed => scheme.onErrorContainer,
                },
              ),
            ],
          ),
          if (isProcessing) ...[
            const SizedBox(height: AppTokens.spaceS),
            LinearProgressIndicator(
              minHeight: 4,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.tertiary),
            ),
          ],
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.profileExportLastRequestedLabel(requestedLabel),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTokens.spaceXS),
          Text(
            l10n.profileExportArchiveSizeLabel(sizeLabel),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (expiresLabel != null) ...[
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              l10n.profileExportArchiveExpiresLabel(expiresLabel),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppTokens.spaceS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS / 2,
            children: archive.bundles
                .map((bundle) => Chip(label: Text(_bundleLabel(bundle, l10n))))
                .toList(),
          ),
          const SizedBox(height: AppTokens.spaceM),
          FilledButton.icon(
            onPressed: isReady && !isExpired && !isDownloading
                ? () => onDownloadArchive(archive.id)
                : null,
            icon: isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(
              isDownloading
                  ? l10n.profileExportDownloadInProgress
                  : l10n.profileExportDownloadLatest,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPreferencesCard extends StatelessWidget {
  const _ExportPreferencesCard({
    required this.state,
    required this.l10n,
    required this.onToggleAssets,
    required this.onToggleOrders,
    required this.onToggleHistory,
  });

  final ProfileExportState state;
  final AppLocalizations l10n;
  final ValueChanged<bool> onToggleAssets;
  final ValueChanged<bool> onToggleOrders;
  final ValueChanged<bool> onToggleHistory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _PreferenceTile(
            icon: Icons.palette_outlined,
            title: l10n.profileExportIncludeAssetsTitle,
            subtitle: l10n.profileExportIncludeAssetsSubtitle,
            value: state.options.includeAssets,
            onChanged: onToggleAssets,
          ),
          const Divider(height: 0),
          _PreferenceTile(
            icon: Icons.receipt_long_outlined,
            title: l10n.profileExportIncludeOrdersTitle,
            subtitle: l10n.profileExportIncludeOrdersSubtitle,
            value: state.options.includeOrders,
            onChanged: onToggleOrders,
          ),
          const Divider(height: 0),
          _PreferenceTile(
            icon: Icons.history_outlined,
            title: l10n.profileExportIncludeHistoryTitle,
            subtitle: l10n.profileExportIncludeHistorySubtitle,
            value: state.options.includeHistory,
            onChanged: onToggleHistory,
          ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: AppTokens.spaceS),
          Expanded(child: Text(title)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: AppTokens.spaceXXL),
        child: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _ExportCtaSection extends StatelessWidget {
  const _ExportCtaSection({
    required this.state,
    required this.l10n,
    required this.onStartExport,
    required this.onViewHistory,
  });

  final ProfileExportState state;
  final AppLocalizations l10n;
  final Future<void> Function() onStartExport;
  final Future<void> Function() onViewHistory;

  @override
  Widget build(BuildContext context) {
    final canSubmit = state.options.hasSelection && !state.isGenerating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(
          onPressed: canSubmit ? onStartExport : null,
          child: state.isGenerating
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppTokens.spaceS),
                    Text(l10n.profileExportGeneratingLabel),
                  ],
                )
              : Text(l10n.profileExportGenerateButton),
        ),
        if (!state.options.hasSelection)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceXS),
            child: Text(
              l10n.profileExportNoSelectionWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        TextButton(
          onPressed: onViewHistory,
          child: Text(l10n.profileExportViewHistory),
        ),
      ],
    );
  }
}

class _ExportHistorySheet extends StatelessWidget {
  const _ExportHistorySheet({
    required this.state,
    required this.l10n,
    required this.onDownloadArchive,
  });

  final ProfileExportState state;
  final AppLocalizations l10n;
  final Future<void> Function(String archiveId) onDownloadArchive;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileExportHistoryTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (!state.snapshot.hasArchives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceL),
                child: Text(
                  l10n.profileExportHistoryEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.snapshot.archives.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.spaceS),
                  itemBuilder: (context, index) {
                    final archive = state.snapshot.archives[index];
                    return _HistoryTile(
                      archive: archive,
                      l10n: l10n,
                      isDownloading: state.isDownloading(archive.id),
                      onDownloadArchive: () => onDownloadArchive(archive.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.archive,
    required this.l10n,
    required this.isDownloading,
    required this.onDownloadArchive,
  });

  final DataExportArchive archive;
  final AppLocalizations l10n;
  final bool isDownloading;
  final Future<void> Function() onDownloadArchive;

  @override
  Widget build(BuildContext context) {
    final ready = archive.status == DataExportStatus.ready;
    final statusText = switch (archive.status) {
      DataExportStatus.preparing => l10n.profileExportStatusPreparing,
      DataExportStatus.ready => l10n.profileExportStatusReady,
      DataExportStatus.expired => l10n.profileExportStatusExpired,
      DataExportStatus.failed => l10n.profileExportStatusFailed,
    };
    final scheme = Theme.of(context).colorScheme;
    final locale = l10n.localeName;
    final requested = _formatDateTime(archive.requestedAt, locale);
    final expires = archive.expiresAt == null
        ? null
        : _formatDateTime(archive.expiresAt!, locale);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ready ? Icons.shield_outlined : Icons.timelapse,
        color: ready ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        l10n.profileExportArchiveSizeLabel(_formatFileSize(archive.sizeBytes)),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileExportHistoryRequested(requested)),
          if (expires != null)
            Text(l10n.profileExportArchiveExpiresLabel(expires)),
          const SizedBox(height: AppTokens.spaceXS),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS / 2,
            children: archive.bundles
                .map(
                  (bundle) => Chip(
                    label: Text(_bundleLabel(bundle, l10n)),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ),
      trailing: ready
          ? TextButton.icon(
              onPressed: isDownloading ? null : onDownloadArchive,
              icon: isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                isDownloading
                    ? l10n.profileExportDownloadInProgress
                    : l10n.profileExportHistoryDownload,
              ),
            )
          : Text(
              statusText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: AppTokens.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceS,
          vertical: AppTokens.spaceXS,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: textColor),
        ),
      ),
    );
  }
}

class _ProfileExportError extends StatelessWidget {
  const _ProfileExportError({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 MB';
  }
  const unit = 1024;
  final mb = bytes / (unit * unit);
  return '${mb.toStringAsFixed(1)} MB';
}

String _formatDateTime(DateTime timestamp, String locale) {
  final formatter = DateFormat.yMMMd(locale).add_jm();
  return formatter.format(timestamp);
}

String _bundleLabel(DataExportBundle bundle, AppLocalizations l10n) {
  return switch (bundle) {
    DataExportBundle.assets => l10n.profileExportBundleAssets,
    DataExportBundle.orders => l10n.profileExportBundleOrders,
    DataExportBundle.history => l10n.profileExportBundleHistory,
  };
}
