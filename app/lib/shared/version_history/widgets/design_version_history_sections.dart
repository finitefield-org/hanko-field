import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:app/shared/version_history/design_version_history_state.dart';
import 'package:flutter/material.dart';

class DesignVersionTimeline extends StatelessWidget {
  const DesignVersionTimeline({
    required this.versions,
    required this.selectedIndex,
    required this.onSelected,
    required this.onRefresh,
    required this.isRefreshing,
    required this.l10n,
    super.key,
  });

  final List<DesignVersion> versions;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.designVersionHistoryTimelineTitle),
            subtitle: Text(l10n.designVersionHistoryTimelineSubtitle),
            trailing: IconButton(
              tooltip: l10n.designVersionHistoryRefreshTooltip,
              onPressed: isRefreshing ? null : onRefresh,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppTokens.spaceM,
              horizontal: AppTokens.spaceM,
            ),
            child: Column(
              children: [
                for (final (index, version) in versions.indexed) ...[
                  _TimelineEntry(
                    version: version,
                    isCurrent: index == 0,
                    isSelected: index == selectedIndex,
                    onSelected: () => onSelected(index),
                    l10n: l10n,
                  ),
                  if (index != versions.length - 1)
                    const SizedBox(height: AppTokens.spaceS),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DesignVersionDiffViewer extends StatelessWidget {
  const DesignVersionDiffViewer({
    required this.current,
    required this.selected,
    required this.diffEntries,
    required this.showEmptyDiffMessage,
    required this.highlightChanges,
    required this.onRestore,
    required this.onDuplicate,
    required this.restoring,
    required this.duplicating,
    required this.l10n,
    super.key,
  });

  final DesignVersion current;
  final DesignVersion selected;
  final List<DesignVersionDiffEntry> diffEntries;
  final bool showEmptyDiffMessage;
  final bool highlightChanges;
  final VoidCallback onRestore;
  final VoidCallback onDuplicate;
  final bool restoring;
  final bool duplicating;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final previews = [
              Expanded(
                child: DesignVersionPreviewCard(
                  title: l10n.designVersionHistoryCurrentLabel,
                  version: current,
                ),
              ),
              const SizedBox(width: AppTokens.spaceM),
              Expanded(
                child: DesignVersionPreviewCard(
                  title: l10n.designVersionHistorySelectedLabel(
                    selected.version,
                  ),
                  version: selected,
                ),
              ),
            ];
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: previews,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      previews[0],
                      const SizedBox(height: AppTokens.spaceM),
                      previews[2],
                    ],
                  );
          },
        ),
        const SizedBox(height: AppTokens.spaceL),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.compare_arrows_outlined),
                title: Text(l10n.designVersionHistoryDiffTitle),
                subtitle: Text(
                  highlightChanges
                      ? l10n.designVersionHistoryDiffHighlightSubtitle
                      : l10n.designVersionHistoryDiffAllSubtitle,
                ),
              ),
              const Divider(height: 1),
              if (diffEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppTokens.spaceL),
                  child: Text(
                    showEmptyDiffMessage
                        ? l10n.designVersionHistoryDiffNoChanges
                        : l10n.designVersionHistoryDiffNotAvailable,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: diffEntries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: AppTokens.spaceL),
                  itemBuilder: (context, index) {
                    final entry = diffEntries[index];
                    final changed = entry.changed;
                    final labelStyle = Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: changed && highlightChanges
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        );
                    return ListTile(
                      title: Text(entry.label, style: labelStyle),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.designVersionHistoryDiffCurrent(
                              entry.currentValue,
                            ),
                          ),
                          Text(
                            l10n.designVersionHistoryDiffSelected(
                              entry.comparedValue,
                            ),
                          ),
                        ],
                      ),
                      leading: changed && highlightChanges
                          ? const Icon(Icons.trending_flat)
                          : const Icon(Icons.drag_handle, color: Colors.grey),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: duplicating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_all_outlined),
                label: Text(l10n.designVersionHistoryDuplicateCta),
                onPressed: duplicating ? null : onDuplicate,
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: FilledButton.icon(
                icon: restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.restore),
                label: Text(l10n.designVersionHistoryRestoreCta),
                onPressed: restoring ? null : onRestore,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DesignVersionPreviewCard extends StatelessWidget {
  const DesignVersionPreviewCard({
    required this.title,
    required this.version,
    super.key,
  });

  final String title;
  final DesignVersion version;

  @override
  Widget build(BuildContext context) {
    final previewUrl =
        version.snapshot.assets?.stampMockUrl ??
        version.snapshot.assets?.previewPngUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(title),
            subtitle: Text(
              '${version.versionLabel} • ${_formatDateTime(version.createdAt)}',
            ),
          ),
          const Divider(height: 1),
          AspectRatio(
            aspectRatio: 1.4,
            child: previewUrl != null
                ? Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) {
                      return const _PreviewFallback(
                        icon: Icons.image_not_supported,
                      );
                    },
                  )
                : const _PreviewFallback(icon: Icons.image_outlined),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.snapshot.input?.kanji?.value ??
                      version.snapshot.input?.rawName ??
                      '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  '${version.snapshot.style.templateRef ?? '—'} · '
                  '${version.snapshot.style.fontRef ?? '—'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class DesignVersionHistoryEmptyState extends StatelessWidget {
  const DesignVersionHistoryEmptyState({
    required this.message,
    required this.onRetry,
    required this.l10n,
    super.key,
  });

  final String message;
  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 48),
            const SizedBox(height: AppTokens.spaceM),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceL),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.homeRetryButtonLabel),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.version,
    required this.isCurrent,
    required this.isSelected,
    required this.onSelected,
    required this.l10n,
  });

  final DesignVersion version;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final statusLabel = isCurrent
        ? l10n.designVersionHistoryStatusCurrent
        : l10n.designVersionHistoryStatusArchived;
    final colorScheme = Theme.of(context).colorScheme;
    final baseBorder = Theme.of(context).dividerColor;
    final borderColor = isSelected ? colorScheme.primary : baseBorder;
    final background = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.28)
        : Colors.transparent;

    return InkWell(
      borderRadius: AppTokens.radiusM,
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppTokens.spaceM),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTokens.radiusM,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isCurrent
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              child: Text(
                'v${version.version}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isCurrent
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDateTime(version.snapshot.updatedAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          isCurrent ? Icons.star : Icons.inventory_2_outlined,
                          size: 16,
                        ),
                        label: Text(statusLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (version.changeNote != null) ...[
                    const SizedBox(height: AppTokens.spaceS),
                    Text(
                      version.changeNote!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        icon,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

extension on DesignVersion {
  String get versionLabel => 'v$version';
}
