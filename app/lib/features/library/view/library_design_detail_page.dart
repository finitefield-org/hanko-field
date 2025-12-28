// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/library/view/library_shared.dart';
import 'package:app/features/library/view_model/library_design_detail_view_model.dart';
import 'package:app/features/library/view_model/library_list_view_model.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryDesignDetailPage extends ConsumerStatefulWidget {
  const LibraryDesignDetailPage({super.key, required this.designId});

  final String designId;

  @override
  ConsumerState<LibraryDesignDetailPage> createState() =>
      _LibraryDesignDetailPageState();
}

class _LibraryDesignDetailPageState
    extends ConsumerState<LibraryDesignDetailPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(
      LibraryDesignDetailViewModel(designId: widget.designId),
    );

    final title = l10n.libraryDesignDetailTitle;
    final subtitle = l10n.libraryDesignDetailSubtitle;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: tokens.colors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) {
            return [
              SliverAppBar.medium(
                backgroundColor: tokens.colors.background,
                title: Text(title),
                centerTitle: false,
                actions: [
                  IconButton(
                    tooltip: l10n.libraryDesignDetailEditTooltip,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: state.valueOrNull == null
                        ? null
                        : () => _handleEdit(context, state.valueOrNull!.design),
                  ),
                  IconButton(
                    tooltip: l10n.libraryDesignDetailExportTooltip,
                    icon: const Icon(Icons.cloud_download_outlined),
                    onPressed: state.valueOrNull == null
                        ? null
                        : () =>
                              _handleExport(context, state.valueOrNull!.design),
                  ),
                ],
                bottom: TabBar(
                  tabs: [
                    Tab(text: l10n.libraryDesignDetailTabDetails),
                    Tab(text: l10n.libraryDesignDetailTabActivity),
                    Tab(text: l10n.libraryDesignDetailTabFiles),
                  ],
                ),
              ),
            ];
          },
          body: switch (state) {
            AsyncLoading<LibraryDesignDetailState>() => Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.lg),
                child: const CircularProgressIndicator.adaptive(),
              ),
            ),
            AsyncError(:final error) when state.valueOrNull == null =>
              _ErrorBody(
                subtitle: subtitle,
                message: error.toString(),
                l10n: l10n,
                onRetry: () => ref.invalidate(
                  LibraryDesignDetailViewModel(designId: widget.designId),
                ),
              ),
            _ => TabBarView(
              children: [
                _DetailsTab(
                  subtitle: subtitle,
                  state: state.valueOrNull!,
                  l10n: l10n,
                  onVersions: () => GoRouter.of(
                    context,
                  ).go('${AppRoutePaths.library}/${widget.designId}/versions'),
                  onDuplicate: () => _handleDuplicate(context),
                  onShare: () =>
                      _handleShare(context, state.valueOrNull!.design),
                  onShareLinks: () => GoRouter.of(
                    context,
                  ).go('${AppRoutePaths.library}/${widget.designId}/shares'),
                  onArchive: () =>
                      _handleArchive(context, state.valueOrNull!.design),
                  onReorder: () =>
                      _handleReorder(context, state.valueOrNull!.design),
                  onRefresh: () => ref.invoke(
                    LibraryDesignDetailViewModel(
                      designId: widget.designId,
                    ).refresh(),
                  ),
                ),
                _ActivityTab(
                  subtitle: subtitle,
                  state: state.valueOrNull!,
                  l10n: l10n,
                  onRefresh: () => ref.invoke(
                    LibraryDesignDetailViewModel(
                      designId: widget.designId,
                    ).refresh(),
                  ),
                ),
                _FilesTab(
                  subtitle: subtitle,
                  state: state.valueOrNull!,
                  l10n: l10n,
                  onExport: () =>
                      _handleExport(context, state.valueOrNull!.design),
                  onRefresh: () => ref.invoke(
                    LibraryDesignDetailViewModel(
                      designId: widget.designId,
                    ).refresh(),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context, Design design) async {
    final router = GoRouter.of(context);
    if (!await _hydrateCreationFromDesign(context, design)) return;
    router.go(AppRoutePaths.designEditor);
  }

  Future<void> _handleExport(BuildContext context, Design design) async {
    final router = GoRouter.of(context);
    router.go(
      '${AppRoutePaths.library}/${widget.designId}/export',
      extra: design,
    );
  }

  Future<void> _handleShare(BuildContext context, Design design) async {
    final router = GoRouter.of(context);
    if (!await _hydrateCreationFromDesign(context, design)) return;
    router.go(AppRoutePaths.designShare);
  }

  Future<void> _handleDuplicate(BuildContext context) async {
    final router = GoRouter.of(context);
    router.go('${AppRoutePaths.library}/${widget.designId}/duplicate');
  }

  Future<void> _handleArchive(BuildContext context, Design design) async {
    final tokens = DesignTokensTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = design.id ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.libraryDesignDetailArchiveTitle),
          content: Text(l10n.libraryDesignDetailArchiveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.libraryDesignDetailArchiveCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.error,
                foregroundColor: tokens.colors.onError,
              ),
              child: Text(l10n.libraryDesignDetailArchiveConfirm),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (id.isEmpty) return;

    await ref.invoke(
      LibraryDesignDetailViewModel(designId: widget.designId).delete(),
    );
    unawaited(ref.invoke(libraryListViewModel.refresh()));
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.libraryDesignDetailArchived),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.mounted) GoRouter.of(context).pop();
  }

  void _handleReorder(BuildContext context, Design design) {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).libraryDesignDetailReorderHint,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    router.go(AppRoutePaths.shop);
  }

  Future<bool> _hydrateCreationFromDesign(
    BuildContext context,
    Design design,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    try {
      await ref.container.read(designCreationViewModel.future);
      await ref.invoke(designCreationViewModel.hydrateFromDesign(design));
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.libraryDesignDetailHydrateFailed(e.toString())),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.subtitle,
    required this.state,
    required this.l10n,
    required this.onVersions,
    required this.onDuplicate,
    required this.onShare,
    required this.onShareLinks,
    required this.onArchive,
    required this.onReorder,
    required this.onRefresh,
  });

  final String subtitle;
  final LibraryDesignDetailState state;
  final AppLocalizations l10n;
  final VoidCallback onVersions;
  final VoidCallback onDuplicate;
  final VoidCallback onShare;
  final VoidCallback onShareLinks;
  final VoidCallback onArchive;
  final VoidCallback onReorder;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final design = state.design;

    return RefreshIndicator.adaptive(
      displacement: tokens.spacing.xl,
      edgeOffset: tokens.spacing.md,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        children: [
          _HeaderCard(
            subtitle: subtitle,
            design: design,
            l10n: l10n,
            onVersions: onVersions,
            onDuplicate: onDuplicate,
            onShare: onShare,
            onShareLinks: onShareLinks,
            onArchive: onArchive,
            onReorder: onReorder,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: l10n.libraryDesignDetailMetadataTitle),
          SizedBox(height: tokens.spacing.sm),
          _metadataCard(context, design, l10n),
        ],
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.subtitle,
    required this.state,
    required this.l10n,
    required this.onRefresh,
  });

  final String subtitle;
  final LibraryDesignDetailState state;
  final AppLocalizations l10n;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return RefreshIndicator.adaptive(
      displacement: tokens.spacing.xl,
      edgeOffset: tokens.spacing.md,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        children: [
          _HeaderCard(
            subtitle: subtitle,
            design: state.design,
            l10n: l10n,
            onVersions: null,
            onDuplicate: null,
            onShare: null,
            onShareLinks: null,
            onArchive: null,
            onReorder: null,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: l10n.libraryDesignDetailUsageHistoryTitle),
          SizedBox(height: tokens.spacing.sm),
          if (state.activity.isEmpty)
            AppCard(child: Text(l10n.libraryDesignDetailNoActivity))
          else
            ...state.activity.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                child: _ActivityTile(item: item, l10n: l10n),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.subtitle,
    required this.state,
    required this.l10n,
    required this.onExport,
    required this.onRefresh,
  });

  final String subtitle;
  final LibraryDesignDetailState state;
  final AppLocalizations l10n;
  final VoidCallback onExport;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final design = state.design;

    return RefreshIndicator.adaptive(
      displacement: tokens.spacing.xl,
      edgeOffset: tokens.spacing.md,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.lg,
          tokens.spacing.xl,
        ),
        children: [
          _HeaderCard(
            subtitle: subtitle,
            design: design,
            l10n: l10n,
            onVersions: null,
            onDuplicate: null,
            onShare: null,
            onShareLinks: null,
            onArchive: null,
            onReorder: null,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: l10n.libraryDesignDetailFilesTitle),
          SizedBox(height: tokens.spacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FileRow(
                  l10n: l10n,
                  label: l10n.libraryDesignDetailPreviewPngLabel,
                  value: design.assets?.previewPngUrl,
                ),
                SizedBox(height: tokens.spacing.sm),
                _FileRow(
                  l10n: l10n,
                  label: l10n.libraryDesignDetailVectorSvgLabel,
                  value: design.assets?.vectorSvg,
                ),
                SizedBox(height: tokens.spacing.md),
                FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.libraryDesignDetailExportAction),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.subtitle,
    required this.design,
    required this.l10n,
    this.onVersions,
    required this.onDuplicate,
    required this.onShare,
    required this.onShareLinks,
    required this.onArchive,
    required this.onReorder,
  });

  final String subtitle;
  final Design design;
  final AppLocalizations l10n;
  final VoidCallback? onVersions;
  final VoidCallback? onDuplicate;
  final VoidCallback? onShare;
  final VoidCallback? onShareLinks;
  final VoidCallback? onArchive;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final name = design.input?.rawName.trim();
    final displayName = (name == null || name.isEmpty)
        ? l10n.libraryDesignDetailUntitled
        : name;
    final previewUrl =
        design.assets?.previewPngUrl ?? design.assets?.stampMockUrl;

    final aiScore = design.ai?.qualityScore;
    final registrable = design.ai?.registrable;

    return Card(
      elevation: 1.2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(displayName, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radii.md),
                    child: Hero(
                      tag: libraryDesignHeroTag(design),
                      child: previewUrl == null
                          ? Container(
                              color: tokens.colors.surfaceVariant,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined),
                            )
                          : Image.network(previewUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.lg),
                Expanded(
                  child: Wrap(
                    spacing: tokens.spacing.sm,
                    runSpacing: tokens.spacing.sm,
                    children: [
                      _InfoChip(
                        label: _statusLabel(design.status, l10n),
                        icon: Icons.bookmark_outline,
                      ),
                      _InfoChip(
                        label: '${design.size.mm.round()}mm',
                        icon: Icons.straighten_outlined,
                      ),
                      _InfoChip(
                        label: _shapeLabel(design.shape, l10n),
                        icon: Icons.radio_button_checked_outlined,
                      ),
                      _InfoChip(
                        label: _writingLabel(design.style.writing, l10n),
                        icon: Icons.font_download_outlined,
                      ),
                      _InfoChip(
                        label: aiScore == null
                            ? l10n.libraryDesignDetailAiScoreUnknown
                            : l10n.libraryDesignDetailAiScoreLabel(
                                (aiScore * 100).round().toString(),
                              ),
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _InfoChip(
                        label: registrable == null
                            ? l10n.libraryDesignDetailRegistrabilityUnknown
                            : (registrable
                                  ? l10n.libraryDesignDetailRegistrable
                                  : l10n.libraryDesignDetailNotRegistrable),
                        icon: registrable == true
                            ? Icons.verified_outlined
                            : Icons.report_problem_outlined,
                        tone: registrable == null
                            ? null
                            : (registrable
                                  ? tokens.colors.primary
                                  : tokens.colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onDuplicate != null ||
                onVersions != null ||
                onShare != null ||
                onShareLinks != null ||
                onArchive != null ||
                onReorder != null) ...[
              SizedBox(height: tokens.spacing.md),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  if (onVersions != null)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded),
                      label: Text(l10n.libraryDesignDetailActionVersions),
                      onPressed: onVersions,
                    ),
                  if (onShare != null)
                    ActionChip(
                      avatar: const Icon(Icons.share_outlined),
                      label: Text(l10n.libraryDesignDetailActionShare),
                      onPressed: onShare,
                    ),
                  if (onShareLinks != null)
                    ActionChip(
                      avatar: const Icon(Icons.link_rounded),
                      label: Text(l10n.libraryDesignDetailActionLinks),
                      onPressed: onShareLinks,
                    ),
                  if (onDuplicate != null)
                    ActionChip(
                      avatar: const Icon(Icons.copy_outlined),
                      label: Text(l10n.libraryDesignDetailActionDuplicate),
                      onPressed: onDuplicate,
                    ),
                  if (onReorder != null)
                    ActionChip(
                      avatar: const Icon(Icons.shopping_bag_outlined),
                      label: Text(l10n.libraryDesignDetailActionReorder),
                      onPressed: onReorder,
                    ),
                  if (onArchive != null)
                    ActionChip(
                      avatar: const Icon(Icons.archive_outlined),
                      label: Text(l10n.libraryDesignDetailActionArchive),
                      onPressed: onArchive,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon, this.tone});

  final String label;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = tone ?? tokens.colors.onSurface.withValues(alpha: 0.75);
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.l10n});

  final LibraryDesignActivityItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      LibraryDesignActivityKind.created => Icons.add_circle_outline,
      LibraryDesignActivityKind.updated => Icons.edit_outlined,
      LibraryDesignActivityKind.ordered => Icons.shopping_bag_outlined,
    };
    return AppListTile(
      leading: Icon(icon),
      title: Text(_activityTitle(item.kind, l10n)),
      subtitle: Text(
        '${_formatShortDate(item.timestamp)} • ${_activityDetail(item.kind, l10n)}',
      ),
      dense: true,
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.l10n,
    required this.label,
    required this.value,
  });

  final AppLocalizations l10n;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final resolved = value == null || value!.trim().isEmpty
        ? l10n.libraryDesignDetailFileNotAvailable
        : value!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.md),
        Expanded(flex: 7, child: Text(resolved)),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.subtitle,
    required this.message,
    required this.l10n,
    required this.onRetry,
  });

  final String subtitle;
  final String message;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.commonLoadFailed,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(subtitle),
              SizedBox(height: tokens.spacing.sm),
              Text(message),
              SizedBox(height: tokens.spacing.md),
              FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _metadataCard(
  BuildContext context,
  Design design,
  AppLocalizations l10n,
) {
  final tokens = DesignTokensTheme.of(context);
  final id = design.id ?? l10n.commonUnknown;
  final aiScore = design.ai?.qualityScore;
  final registrable = design.ai?.registrable;

  String registrabilityText() {
    if (registrable == null) return l10n.commonUnknown;
    return registrable
        ? l10n.libraryDesignDetailRegistrable
        : l10n.libraryDesignDetailNotRegistrable;
  }

  String aiText() {
    if (aiScore == null) return l10n.commonUnknown;
    return '${(aiScore * 100).round()} / 100';
  }

  return Column(
    children: [
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataDesignId),
        subtitle: Text(id),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataStatus),
        subtitle: Text(_statusLabel(design.status, l10n)),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataAiScore),
        subtitle: Text(aiText()),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataRegistrability),
        subtitle: Text(registrabilityText()),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataCreated),
        subtitle: Text(_formatShortDate(design.createdAt)),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataUpdated),
        subtitle: Text(_formatShortDate(design.updatedAt)),
        dense: true,
      ),
      if (design.lastOrderedAt != null) ...[
        SizedBox(height: tokens.spacing.sm),
        AppListTile(
          title: Text(l10n.libraryDesignDetailMetadataLastUsed),
          subtitle: Text(_formatShortDate(design.lastOrderedAt!)),
          dense: true,
        ),
      ],
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(l10n.libraryDesignDetailMetadataVersion),
        subtitle: Text('v${design.version}'),
        dense: true,
      ),
    ],
  );
}

String _shapeLabel(SealShape shape, AppLocalizations l10n) => switch (shape) {
  SealShape.round => l10n.homeShapeRound,
  SealShape.square => l10n.homeShapeSquare,
};

String _writingLabel(WritingStyle style, AppLocalizations l10n) =>
    switch (style) {
      WritingStyle.tensho => l10n.homeWritingTensho,
      WritingStyle.reisho => l10n.homeWritingReisho,
      WritingStyle.kaisho => l10n.homeWritingKaisho,
      WritingStyle.gyosho => l10n.homeWritingGyosho,
      WritingStyle.koentai => l10n.homeWritingKoentai,
      WritingStyle.custom => l10n.homeWritingCustom,
    };

String _statusLabel(DesignStatus status, AppLocalizations l10n) =>
    switch (status) {
      DesignStatus.draft => l10n.homeStatusDraft,
      DesignStatus.ready => l10n.homeStatusReady,
      DesignStatus.ordered => l10n.homeStatusOrdered,
      DesignStatus.locked => l10n.homeStatusLocked,
    };

String _formatShortDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

String _activityTitle(LibraryDesignActivityKind kind, AppLocalizations l10n) =>
    switch (kind) {
      LibraryDesignActivityKind.created =>
        l10n.libraryDesignDetailActivityCreatedTitle,
      LibraryDesignActivityKind.updated =>
        l10n.libraryDesignDetailActivityUpdatedTitle,
      LibraryDesignActivityKind.ordered =>
        l10n.libraryDesignDetailActivityOrderedTitle,
    };

String _activityDetail(LibraryDesignActivityKind kind, AppLocalizations l10n) =>
    switch (kind) {
      LibraryDesignActivityKind.created =>
        l10n.libraryDesignDetailActivityCreatedDetail,
      LibraryDesignActivityKind.updated =>
        l10n.libraryDesignDetailActivityUpdatedDetail,
      LibraryDesignActivityKind.ordered =>
        l10n.libraryDesignDetailActivityOrderedDetail,
    };
