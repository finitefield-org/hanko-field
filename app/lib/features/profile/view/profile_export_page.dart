// ignore_for_file: public_member_api_docs

import 'package:app/features/profile/view_model/profile_export_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/feedback/app_empty_state.dart';
import 'package:app/ui/feedback/app_skeleton.dart';
import 'package:app/ui/overlays/app_modal.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfileExportPage extends ConsumerStatefulWidget {
  const ProfileExportPage({super.key});

  @override
  ConsumerState<ProfileExportPage> createState() => _ProfileExportPageState();
}

class _ProfileExportPageState extends ConsumerState<ProfileExportPage> {
  int? _lastFeedbackId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final export = ref.watch(profileExportViewModel);

    late final Widget body;
    switch (export) {
      case AsyncData(:final value):
        _maybeShowFeedback(context, value);
        body = _ExportBody(
          state: value,
          onRequestPermission: () =>
              ref.invoke(profileExportViewModel.ensurePermission()),
          onToggleAssets: (value) =>
              ref.invoke(profileExportViewModel.toggleAssets(value)),
          onToggleOrders: (value) =>
              ref.invoke(profileExportViewModel.toggleOrders(value)),
          onToggleHistory: (value) =>
              ref.invoke(profileExportViewModel.toggleHistory(value)),
          onOpenHistory: () => _openHistory(context, value),
        );
      case AsyncLoading():
        body = const _ExportSkeleton();
      case AsyncError():
        body = AppEmptyState(
          title: l10n.profileExportErrorTitle,
          message: l10n.profileExportErrorBody,
          icon: Icons.download_outlined,
          actionLabel: l10n.profileExportRetry,
          onAction: () => ref.invalidate(profileExportViewModel),
        );
    }

    Widget? bottomBar;
    if (export case AsyncData(:final value)) {
      bottomBar = _ExportActions(
        state: value,
        onExport: () => ref.invoke(profileExportViewModel.export()),
        onOpenHistory: () => _openHistory(context, value),
      );
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _ExportAppBar(
        lastExport: export.valueOrNull?.lastExport,
        onOpenHistory: export.valueOrNull == null
            ? null
            : () => _openHistory(context, export.valueOrNull!),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomBar,
    );
  }

  void _maybeShowFeedback(BuildContext context, ProfileExportState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback)));
    });
  }

  Future<void> _openHistory(BuildContext context, ProfileExportState state) {
    final l10n = AppLocalizations.of(context);
    return showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final tokens = DesignTokensTheme.of(sheetContext);
        if (state.history.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.md),
            child: AppEmptyState(
              title: l10n.profileExportHistoryEmptyTitle,
              message: l10n.profileExportHistoryEmptyBody,
              icon: Icons.archive_outlined,
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileExportHistoryTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...state.history.map((record) {
              final timeLabel = _timeLabel(record.createdAt, l10n);
              final sizeLabel = '${record.fileSizeMb.toStringAsFixed(2)} MB';
              final sections = _sectionsLabel(record.sections, l10n);
              final subtitle = [
                sizeLabel,
                if (sections.isNotEmpty) sections,
                timeLabel,
              ].where((part) => part.isNotEmpty).join(' • ');

              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(record.label),
                  subtitle: Text(subtitle),
                  leading: const Icon(Icons.archive_outlined),
                  trailing: IconButton(
                    tooltip: l10n.profileExportHistoryDownload,
                    icon: const Icon(Icons.download_outlined),
                    onPressed: () =>
                        ref.invoke(profileExportViewModel.share(record)),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ExportAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ExportAppBar({required this.lastExport, this.onOpenHistory});

  final ProfileExportRecord? lastExport;
  final VoidCallback? onOpenHistory;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final badgeLabel = lastExport == null
        ? null
        : _compactTimeLabel(lastExport!.createdAt, l10n);

    final actionIcon = IconButton(
      tooltip: l10n.profileExportHistoryTitle,
      onPressed: onOpenHistory,
      icon: const Icon(Icons.history_toggle_off_rounded),
    );

    return AppBar(
      centerTitle: true,
      leading: const BackButton(),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.profileExportTitle),
          Text(
            l10n.profileExportAppBarSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        if (badgeLabel != null)
          Badge(
            label: Text(badgeLabel),
            backgroundColor: tokens.colors.primary,
            textColor: tokens.colors.onPrimary,
            offset: const Offset(-2, -2),
            child: actionIcon,
          )
        else
          actionIcon,
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _ExportBody extends StatelessWidget {
  const _ExportBody({
    required this.state,
    required this.onRequestPermission,
    required this.onToggleAssets,
    required this.onToggleOrders,
    required this.onToggleHistory,
    required this.onOpenHistory,
  });

  final ProfileExportState state;
  final VoidCallback onRequestPermission;
  final ValueChanged<bool> onToggleAssets;
  final ValueChanged<bool> onToggleOrders;
  final ValueChanged<bool> onToggleHistory;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xxl,
      ),
      children: [
        if (!state.storageStatus.isGranted) ...[
          _PermissionCard(onRequest: onRequestPermission),
          SizedBox(height: tokens.spacing.md),
        ],
        _SummaryCard(state: state),
        SizedBox(height: tokens.spacing.md),
        _PreferenceCard(
          state: state,
          onToggleAssets: onToggleAssets,
          onToggleOrders: onToggleOrders,
          onToggleHistory: onToggleHistory,
        ),
        SizedBox(height: tokens.spacing.md),
        _StatusCard(state: state),
        SizedBox(height: tokens.spacing.md),
        Text(
          l10n.profileExportHistoryTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        _HistoryPreview(state: state, onOpenHistory: onOpenHistory),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final ProfileExportState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);

    final chips = [
      if (state.includeAssets)
        Chip(
          label: Text(l10n.profileExportIncludeAssetsTitle),
          avatar: const Icon(Icons.collections_bookmark_outlined, size: 18),
        ),
      if (state.includeOrders)
        Chip(
          label: Text(l10n.profileExportIncludeOrdersTitle),
          avatar: const Icon(Icons.receipt_long_outlined, size: 18),
        ),
      if (state.includeHistory)
        Chip(
          label: Text(l10n.profileExportIncludeHistoryTitle),
          avatar: const Icon(Icons.timeline_outlined, size: 18),
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileExportSummaryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            l10n.profileExportSummaryBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (chips.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.md),
            Wrap(
              spacing: tokens.spacing.xs,
              runSpacing: tokens.spacing.xs,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.state,
    required this.onToggleAssets,
    required this.onToggleOrders,
    required this.onToggleHistory,
  });

  final ProfileExportState state;
  final ValueChanged<bool> onToggleAssets;
  final ValueChanged<bool> onToggleOrders;
  final ValueChanged<bool> onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final disabled = state.isExporting;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SwitchRow(
            title: l10n.profileExportIncludeAssetsTitle,
            subtitle: l10n.profileExportIncludeAssetsSubtitle,
            value: state.includeAssets,
            onChanged: disabled ? null : onToggleAssets,
            icon: Icons.collections_bookmark_outlined,
          ),
          Divider(
            height: 1,
            color: tokens.colors.outline.withValues(alpha: 0.2),
          ),
          _SwitchRow(
            title: l10n.profileExportIncludeOrdersTitle,
            subtitle: l10n.profileExportIncludeOrdersSubtitle,
            value: state.includeOrders,
            onChanged: disabled ? null : onToggleOrders,
            icon: Icons.receipt_long_outlined,
          ),
          Divider(
            height: 1,
            color: tokens.colors.outline.withValues(alpha: 0.2),
          ),
          _SwitchRow(
            title: l10n.profileExportIncludeHistoryTitle,
            subtitle: l10n.profileExportIncludeHistorySubtitle,
            value: state.includeHistory,
            onChanged: disabled ? null : onToggleHistory,
            icon: Icons.timeline_outlined,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.xs,
      ),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final ProfileExportState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final lastExport = state.lastExport;

    final title = state.isExporting
        ? l10n.profileExportStatusInProgressTitle
        : lastExport == null
        ? l10n.profileExportStatusReadyTitle
        : l10n.profileExportStatusDoneTitle;

    final body = state.isExporting
        ? l10n.profileExportStatusInProgressBody
        : lastExport == null
        ? l10n.profileExportStatusReadyBody
        : l10n.profileExportStatusDoneBody;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.spacing.xs),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.isExporting) ...[
            SizedBox(height: tokens.spacing.md),
            LinearProgressIndicator(value: state.progress),
          ],
          if (lastExport != null) ...[
            SizedBox(height: tokens.spacing.md),
            Text(
              lastExport.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              '${lastExport.fileSizeMb.toStringAsFixed(2)} MB'
              ' • ${_timeLabel(lastExport.createdAt, l10n)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.state, required this.onOpenHistory});

  final ProfileExportState state;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);
    final previews = state.history.take(2).toList();

    if (previews.isEmpty) {
      return AppCard(
        child: Text(
          l10n.profileExportHistoryEmptyBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        ...previews.map((record) {
          final timeLabel = _timeLabel(record.createdAt, l10n);
          final sizeLabel = '${record.fileSizeMb.toStringAsFixed(2)} MB';
          final sections = _sectionsLabel(record.sections, l10n);
          final subtitle = [
            sizeLabel,
            if (sections.isNotEmpty) sections,
            timeLabel,
          ].where((part) => part.isNotEmpty).join(' • ');

          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: AppListTile(
              title: Text(record.label),
              subtitle: Text(subtitle),
              leading: const Icon(Icons.archive_outlined),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenHistory,
            ),
          );
        }),
      ],
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.state,
    required this.onExport,
    required this.onOpenHistory,
  });

  final ProfileExportState state;
  final VoidCallback onExport;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.sm,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: l10n.profileExportCtaStart,
              onPressed: state.isExporting ? null : onExport,
              variant: AppButtonVariant.primary,
              expand: true,
              isLoading: state.isExporting,
            ),
            SizedBox(height: tokens.spacing.sm),
            TextButton(
              onPressed: onOpenHistory,
              child: Text(l10n.profileExportCtaHistory),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileExportPermissionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            l10n.profileExportPermissionBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          AppButton(
            label: l10n.profileExportPermissionCta,
            onPressed: onRequest,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _ExportSkeleton extends StatelessWidget {
  const _ExportSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        AppSkeletonBlock(
          width: 200,
          height: 24,
          borderRadius: BorderRadius.circular(tokens.radii.md),
        ),
        SizedBox(height: tokens.spacing.md),
        const AppSkeletonBlock(height: 120),
        SizedBox(height: tokens.spacing.md),
        const AppSkeletonBlock(height: 180),
        SizedBox(height: tokens.spacing.md),
        const AppSkeletonBlock(height: 140),
      ],
    );
  }
}

String _sectionsLabel(
  List<ProfileExportSection> sections,
  AppLocalizations l10n,
) {
  if (sections.isEmpty) return '';
  final labels = sections.map((section) {
    return switch (section) {
      ProfileExportSection.assets => l10n.profileExportIncludeAssetsTitle,
      ProfileExportSection.orders => l10n.profileExportIncludeOrdersTitle,
      ProfileExportSection.history => l10n.profileExportIncludeHistoryTitle,
    };
  }).toList();
  return labels.join(', ');
}

String _timeLabel(DateTime dateTime, AppLocalizations l10n) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) {
    return l10n.profileExportTimeJustNow;
  }
  if (diff.inHours < 1) {
    return l10n.profileExportTimeMinutes(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.profileExportTimeHours(diff.inHours);
  }
  if (diff.inDays < 30) {
    return l10n.profileExportTimeDays(diff.inDays);
  }
  return l10n.profileExportTimeDate(dateTime);
}

String _compactTimeLabel(DateTime dateTime, AppLocalizations l10n) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) {
    return l10n.profileExportTimeCompactNow;
  }
  if (diff.inHours < 1) {
    return l10n.profileExportTimeCompactMinutes(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.profileExportTimeCompactHours(diff.inHours);
  }
  return l10n.profileExportTimeCompactDays(diff.inDays);
}
