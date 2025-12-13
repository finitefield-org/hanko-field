// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/library/view/library_shared.dart';
import 'package:app/features/library/view_model/library_design_detail_view_model.dart';
import 'package:app/features/library/view_model/library_list_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
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
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final state = ref.watch(
      LibraryDesignDetailViewModel(designId: widget.designId),
    );

    final title = prefersEnglish ? 'Design detail' : '印鑑詳細';
    final subtitle = prefersEnglish ? 'Library' : 'マイ印鑑';

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
                    tooltip: prefersEnglish ? 'Edit' : '編集',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: state.valueOrNull == null
                        ? null
                        : () => _handleEdit(context, state.valueOrNull!.design),
                  ),
                  IconButton(
                    tooltip: prefersEnglish ? 'Export' : '出力',
                    icon: const Icon(Icons.cloud_download_outlined),
                    onPressed: state.valueOrNull == null
                        ? null
                        : () =>
                              _handleExport(context, state.valueOrNull!.design),
                  ),
                ],
                bottom: TabBar(
                  tabs: [
                    Tab(text: prefersEnglish ? 'Details' : '詳細'),
                    Tab(text: prefersEnglish ? 'Activity' : '履歴'),
                    Tab(text: prefersEnglish ? 'Files' : 'ファイル'),
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
                prefersEnglish: prefersEnglish,
                onRetry: () => ref.invalidate(
                  LibraryDesignDetailViewModel(designId: widget.designId),
                ),
              ),
            _ => TabBarView(
              children: [
                _DetailsTab(
                  subtitle: subtitle,
                  state: state.valueOrNull!,
                  prefersEnglish: prefersEnglish,
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
                  prefersEnglish: prefersEnglish,
                  onRefresh: () => ref.invoke(
                    LibraryDesignDetailViewModel(
                      designId: widget.designId,
                    ).refresh(),
                  ),
                ),
                _FilesTab(
                  subtitle: subtitle,
                  state: state.valueOrNull!,
                  prefersEnglish: prefersEnglish,
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
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    final messenger = ScaffoldMessenger.of(context);
    final id = design.id ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(prefersEnglish ? 'Archive design?' : 'アーカイブしますか？'),
          content: Text(
            prefersEnglish
                ? 'This removes the design from your library (mocked local data).'
                : 'この印鑑をライブラリから削除します（ローカルモック）。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.error,
                foregroundColor: tokens.colors.onError,
              ),
              child: Text(prefersEnglish ? 'Archive' : 'アーカイブ'),
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
        content: Text(prefersEnglish ? 'Archived' : 'アーカイブしました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.mounted) GoRouter.of(context).pop();
  }

  void _handleReorder(BuildContext context, Design design) {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          prefersEnglish
              ? 'Pick a product, then attach this design (mock)'
              : '商品を選んで、この印鑑を選択してください（モック）',
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
    final prefersEnglish = ref.container
        .read(appExperienceGatesProvider)
        .prefersEnglish;

    try {
      await ref.container.read(designCreationViewModel.future);
      await ref.invoke(designCreationViewModel.hydrateFromDesign(design));
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish
                ? 'Failed to prepare editor: $e'
                : '編集の準備に失敗しました: $e',
          ),
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
    required this.prefersEnglish,
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
  final bool prefersEnglish;
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
            prefersEnglish: prefersEnglish,
            onVersions: onVersions,
            onDuplicate: onDuplicate,
            onShare: onShare,
            onShareLinks: onShareLinks,
            onArchive: onArchive,
            onReorder: onReorder,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: prefersEnglish ? 'Metadata' : 'メタデータ'),
          SizedBox(height: tokens.spacing.sm),
          _metadataCard(context, design, prefersEnglish),
        ],
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.subtitle,
    required this.state,
    required this.prefersEnglish,
    required this.onRefresh,
  });

  final String subtitle;
  final LibraryDesignDetailState state;
  final bool prefersEnglish;
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
            prefersEnglish: prefersEnglish,
            onVersions: null,
            onDuplicate: null,
            onShare: null,
            onShareLinks: null,
            onArchive: null,
            onReorder: null,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: prefersEnglish ? 'Usage history' : '使用履歴'),
          SizedBox(height: tokens.spacing.sm),
          if (state.activity.isEmpty)
            AppCard(
              child: Text(prefersEnglish ? 'No activity yet.' : 'まだ履歴がありません。'),
            )
          else
            ...state.activity.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                child: _ActivityTile(
                  item: item,
                  prefersEnglish: prefersEnglish,
                ),
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
    required this.prefersEnglish,
    required this.onExport,
    required this.onRefresh,
  });

  final String subtitle;
  final LibraryDesignDetailState state;
  final bool prefersEnglish;
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
            prefersEnglish: prefersEnglish,
            onVersions: null,
            onDuplicate: null,
            onShare: null,
            onShareLinks: null,
            onArchive: null,
            onReorder: null,
          ),
          SizedBox(height: tokens.spacing.lg),
          _SectionTitle(title: prefersEnglish ? 'Files' : 'ファイル'),
          SizedBox(height: tokens.spacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FileRow(
                  prefersEnglish: prefersEnglish,
                  label: prefersEnglish ? 'Preview PNG' : 'プレビューPNG',
                  value: design.assets?.previewPngUrl,
                ),
                SizedBox(height: tokens.spacing.sm),
                _FileRow(
                  prefersEnglish: prefersEnglish,
                  label: prefersEnglish ? 'Vector SVG' : 'ベクターSVG',
                  value: design.assets?.vectorSvg,
                ),
                SizedBox(height: tokens.spacing.md),
                FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(prefersEnglish ? 'Export' : '出力'),
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
    required this.prefersEnglish,
    this.onVersions,
    required this.onDuplicate,
    required this.onShare,
    required this.onShareLinks,
    required this.onArchive,
    required this.onReorder,
  });

  final String subtitle;
  final Design design;
  final bool prefersEnglish;
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
        ? (prefersEnglish ? 'Untitled' : '名称未設定')
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
                        label: _statusLabel(design.status, prefersEnglish),
                        icon: Icons.bookmark_outline,
                      ),
                      _InfoChip(
                        label: '${design.size.mm.round()}mm',
                        icon: Icons.straighten_outlined,
                      ),
                      _InfoChip(
                        label: _shapeLabel(design.shape, prefersEnglish),
                        icon: Icons.radio_button_checked_outlined,
                      ),
                      _InfoChip(
                        label: _writingLabel(
                          design.style.writing,
                          prefersEnglish,
                        ),
                        icon: Icons.font_download_outlined,
                      ),
                      _InfoChip(
                        label: aiScore == null
                            ? (prefersEnglish ? 'AI score: -' : 'AIスコア: -')
                            : (prefersEnglish
                                  ? 'AI score: ${(aiScore * 100).round()}'
                                  : 'AIスコア: ${(aiScore * 100).round()}'),
                        icon: Icons.auto_awesome_outlined,
                      ),
                      _InfoChip(
                        label: registrable == null
                            ? (prefersEnglish ? 'Registrability: -' : '登録可否: -')
                            : (registrable
                                  ? (prefersEnglish ? 'Registrable' : '登録可')
                                  : (prefersEnglish
                                        ? 'Not registrable'
                                        : '登録不可')),
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
                      label: Text(prefersEnglish ? 'Versions' : 'バージョン'),
                      onPressed: onVersions,
                    ),
                  if (onShare != null)
                    ActionChip(
                      avatar: const Icon(Icons.share_outlined),
                      label: Text(prefersEnglish ? 'Share' : '共有'),
                      onPressed: onShare,
                    ),
                  if (onShareLinks != null)
                    ActionChip(
                      avatar: const Icon(Icons.link_rounded),
                      label: Text(prefersEnglish ? 'Links' : 'リンク'),
                      onPressed: onShareLinks,
                    ),
                  if (onDuplicate != null)
                    ActionChip(
                      avatar: const Icon(Icons.copy_outlined),
                      label: Text(prefersEnglish ? 'Duplicate' : '複製'),
                      onPressed: onDuplicate,
                    ),
                  if (onReorder != null)
                    ActionChip(
                      avatar: const Icon(Icons.shopping_bag_outlined),
                      label: Text(prefersEnglish ? 'Reorder' : '再注文'),
                      onPressed: onReorder,
                    ),
                  if (onArchive != null)
                    ActionChip(
                      avatar: const Icon(Icons.archive_outlined),
                      label: Text(prefersEnglish ? 'Archive' : 'アーカイブ'),
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
  const _ActivityTile({required this.item, required this.prefersEnglish});

  final LibraryDesignActivityItem item;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      LibraryDesignActivityKind.created => Icons.add_circle_outline,
      LibraryDesignActivityKind.updated => Icons.edit_outlined,
      LibraryDesignActivityKind.ordered => Icons.shopping_bag_outlined,
    };
    return AppListTile(
      leading: Icon(icon),
      title: Text(prefersEnglish ? item.title : _activityTitleJa(item.kind)),
      subtitle: Text(
        '${_formatShortDate(item.timestamp)} • ${prefersEnglish ? item.detail : _activityDetailJa(item.kind)}',
      ),
      dense: true,
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.prefersEnglish,
    required this.label,
    required this.value,
  });

  final bool prefersEnglish;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final resolved = value == null || value!.trim().isEmpty
        ? (prefersEnglish ? 'Not available' : '未生成')
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
    required this.prefersEnglish,
    required this.onRetry,
  });

  final String subtitle;
  final String message;
  final bool prefersEnglish;
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
                prefersEnglish ? 'Failed to load' : '読み込みに失敗しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
              Text(subtitle),
              SizedBox(height: tokens.spacing.sm),
              Text(message),
              SizedBox(height: tokens.spacing.md),
              FilledButton(
                onPressed: onRetry,
                child: Text(prefersEnglish ? 'Retry' : '再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _metadataCard(BuildContext context, Design design, bool prefersEnglish) {
  final tokens = DesignTokensTheme.of(context);
  final id = design.id ?? (prefersEnglish ? 'Unknown' : '不明');
  final aiScore = design.ai?.qualityScore;
  final registrable = design.ai?.registrable;

  String registrabilityText() {
    if (registrable == null) return prefersEnglish ? 'Unknown' : '不明';
    return registrable
        ? (prefersEnglish ? 'Registrable' : '登録可')
        : (prefersEnglish ? 'Not registrable' : '登録不可');
  }

  String aiText() {
    if (aiScore == null) return prefersEnglish ? 'Unknown' : '不明';
    return '${(aiScore * 100).round()} / 100';
  }

  return Column(
    children: [
      AppListTile(
        title: Text(prefersEnglish ? 'Design ID' : 'デザインID'),
        subtitle: Text(id),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'Status' : 'ステータス'),
        subtitle: Text(_statusLabel(design.status, prefersEnglish)),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'AI score' : 'AIスコア'),
        subtitle: Text(aiText()),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'Registrability' : '登録可否'),
        subtitle: Text(registrabilityText()),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'Created' : '作成日'),
        subtitle: Text(_formatShortDate(design.createdAt)),
        dense: true,
      ),
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'Updated' : '更新日'),
        subtitle: Text(_formatShortDate(design.updatedAt)),
        dense: true,
      ),
      if (design.lastOrderedAt != null) ...[
        SizedBox(height: tokens.spacing.sm),
        AppListTile(
          title: Text(prefersEnglish ? 'Last used' : '最終使用'),
          subtitle: Text(_formatShortDate(design.lastOrderedAt!)),
          dense: true,
        ),
      ],
      SizedBox(height: tokens.spacing.sm),
      AppListTile(
        title: Text(prefersEnglish ? 'Version' : 'バージョン'),
        subtitle: Text('v${design.version}'),
        dense: true,
      ),
    ],
  );
}

String _shapeLabel(SealShape shape, bool prefersEnglish) => switch (shape) {
  SealShape.round => prefersEnglish ? 'Round' : '丸',
  SealShape.square => prefersEnglish ? 'Square' : '角',
};

String _writingLabel(WritingStyle style, bool prefersEnglish) =>
    switch (style) {
      WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
      WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
      WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
      WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
      WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
      WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
    };

String _statusLabel(DesignStatus status, bool prefersEnglish) =>
    switch (status) {
      DesignStatus.draft => prefersEnglish ? 'Draft' : '下書き',
      DesignStatus.ready => prefersEnglish ? 'Ready' : '準備完了',
      DesignStatus.ordered => prefersEnglish ? 'Ordered' : '注文済み',
      DesignStatus.locked => prefersEnglish ? 'Locked' : 'ロック',
    };

String _formatShortDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

String _activityTitleJa(LibraryDesignActivityKind kind) => switch (kind) {
  LibraryDesignActivityKind.created => '作成',
  LibraryDesignActivityKind.updated => '更新',
  LibraryDesignActivityKind.ordered => '注文で使用',
};

String _activityDetailJa(LibraryDesignActivityKind kind) => switch (kind) {
  LibraryDesignActivityKind.created => '保存しました',
  LibraryDesignActivityKind.updated => '編集内容を反映しました',
  LibraryDesignActivityKind.ordered => '再注文できます',
};
