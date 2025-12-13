// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_versions_view_model.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignVersionsPage extends ConsumerStatefulWidget {
  const DesignVersionsPage({super.key, this.viewModel, this.secondaryAction});

  final DesignVersionsViewModel? viewModel;
  final VersionsSecondaryAction? secondaryAction;

  @override
  ConsumerState<DesignVersionsPage> createState() => _DesignVersionsPageState();
}

class _DesignVersionsPageState extends ConsumerState<DesignVersionsPage> {
  int? _lastFeedbackId;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final viewModel = widget.viewModel ?? designVersionsViewModel;
    final state = ref.watch(viewModel);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppTopBar(
        title: 'バージョン履歴',
        showBack: true,
        actions: [
          IconButton(
            tooltip: '差分を表示',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: state.valueOrNull == null
                ? null
                : () => _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading<DesignVersionsState>() => const _VersionsSkeleton(),
          AsyncError(:final error) when state.valueOrNull == null =>
            _VersionsError(
              message: error.toString(),
              onRetry: () => ref.invalidate(viewModel),
            ),
          _ => RefreshIndicator.adaptive(
            onRefresh: () => ref.invoke(viewModel.refresh()),
            edgeOffset: tokens.spacing.md,
            displacement: tokens.spacing.lg,
            child: _buildBody(
              context: context,
              state: state.valueOrNull!,
              tokens: tokens,
              viewModel: viewModel,
            ),
          ),
        },
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required DesignVersionsState state,
    required DesignTokens tokens,
    required DesignVersionsViewModel viewModel,
  }) {
    _maybeShowFeedback(context, state);
    final diff = state.diff;
    final focus = state.focused ?? state.current;

    final secondary = widget.secondaryAction;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        _DiffHeader(
          current: state.current,
          focus: focus,
          diff: diff,
          isBusy: state.isRollingBack || state.isDuplicating,
          onRollback: () => _confirmRollback(context, state, focus),
          secondaryAction:
              secondary ??
              VersionsSecondaryAction(
                label: 'コピーを作成',
                icon: Icons.copy_all_rounded,
                onPressed: (focused) =>
                    ref.invoke(viewModel.duplicate(_versionId(focused))),
              ),
        ),
        SizedBox(height: tokens.spacing.md),
        if (diff != null) ...[
          _PreviewRow(diff: diff),
          SizedBox(height: tokens.spacing.md),
          _ChangesList(diff: diff),
          SizedBox(height: tokens.spacing.lg),
        ],
        _SectionHeader(
          label: 'タイムライン',
          action: IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '履歴をリフレッシュ',
            onPressed: () => ref.invoke(viewModel.refresh()),
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        ...state.versions.mapIndexed((index, version) {
          final selected = _versionId(version) == state.focusVersionId;
          final isCurrent = index == 0;
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.sm),
            child: _TimelineItem(
              version: version,
              selected: selected,
              isCurrent: isCurrent,
              onSelect: () =>
                  ref.invoke(viewModel.selectVersion(_versionId(version))),
              onRestore: isCurrent
                  ? null
                  : () => _confirmRollback(context, state, version),
            ),
          );
        }),
        SizedBox(height: tokens.spacing.lg),
        const _SectionHeader(label: '監査ログ'),
        SizedBox(height: tokens.spacing.sm),
        if (state.auditTrail.isEmpty)
          const AppEmptyState(
            title: '履歴はありません',
            message: 'このデザインのアクションログがまだありません。',
            icon: Icons.history_toggle_off_rounded,
          )
        else
          Column(
            children: state.auditTrail
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.sm),
                    child: _AuditTile(entry: entry),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  void _maybeShowFeedback(BuildContext context, DesignVersionsState state) {
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

  Future<void> _confirmRollback(
    BuildContext context,
    DesignVersionsState state,
    DesignVersion target,
  ) {
    return showAppModal<void>(
      context: context,
      title: 'v${target.version} にロールバックしますか？',
      body: const Text(
        'この操作で現在の編集中バージョンを置き換えます。'
        '差分は履歴に残ります。',
      ),
      primaryAction: '復元',
      secondaryAction: 'キャンセル',
      onPrimaryPressed: () {
        Navigator.of(context).maybePop();
        ref.invoke(
          (widget.viewModel ?? designVersionsViewModel).rollback(
            _versionId(target),
          ),
        );
      },
    );
  }

  String _versionId(DesignVersion version) =>
      version.id ?? 'v${version.version}';
}

class _DiffHeader extends StatelessWidget {
  const _DiffHeader({
    required this.current,
    required this.focus,
    required this.diff,
    required this.isBusy,
    required this.onRollback,
    required this.secondaryAction,
  });

  final DesignVersion current;
  final DesignVersion focus;
  final VersionDiff? diff;
  final bool isBusy;
  final VoidCallback onRollback;
  final VersionsSecondaryAction secondaryAction;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final similarity = diff?.similarity ?? 1.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '現在: v${current.version}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: tokens.spacing.xs),
                    Text(
                      diff?.summary ?? '差分はありません',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _SimilarityGauge(value: similarity),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Wrap(
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.sm,
            children: [
              Chip(
                label: Text('比較対象 v${focus.version}'),
                avatar: const Icon(Icons.history_edu_rounded, size: 18),
              ),
              Chip(
                label: Text(current.changeNote ?? '最新版'),
                avatar: const Icon(Icons.auto_fix_high_rounded, size: 18),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'ロールバック',
                  variant: AppButtonVariant.secondary,
                  onPressed: isBusy ? null : onRollback,
                  isLoading: isBusy,
                  leading: const Icon(Icons.restore_rounded),
                ),
              ),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: AppButton(
                  label: secondaryAction.label,
                  variant: AppButtonVariant.ghost,
                  onPressed: isBusy
                      ? null
                      : () => secondaryAction.onPressed(focus),
                  leading: Icon(secondaryAction.icon),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VersionsSecondaryAction {
  const VersionsSecondaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final void Function(DesignVersion focused) onPressed;
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.diff});

  final VersionDiff diff;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: _VersionPreviewCard(
            title: '現在',
            version: diff.base,
            background: tokens.colors.surfaceVariant,
          ),
        ),
        SizedBox(width: tokens.spacing.sm),
        Expanded(
          child: _VersionPreviewCard(
            title: '比較対象',
            version: diff.target,
            background: Color.alphaBlend(
              tokens.colors.primary.withValues(alpha: 0.05),
              tokens.colors.surfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _VersionPreviewCard extends StatelessWidget {
  const _VersionPreviewCard({
    required this.title,
    required this.version,
    required this.background,
  });

  final String title;
  final DesignVersion version;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final snapshot = version.snapshot;
    final initials = snapshot.input?.rawName.characters.take(2).toList().join();

    return AppCard(
      backgroundColor: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.spacing.xs),
          Text(
            'v${version.version} • ${_relative(version.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          AspectRatio(
            aspectRatio: snapshot.shape == SealShape.square ? 1 : 1,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.colors.surface,
                shape: snapshot.shape == SealShape.square
                    ? BoxShape.rectangle
                    : BoxShape.circle,
                borderRadius: snapshot.shape == SealShape.square
                    ? BorderRadius.circular(tokens.radii.md)
                    : null,
                border: Border.all(
                  color: tokens.colors.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initials?.isNotEmpty == true ? initials! : '印',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            snapshot.input?.rawName ?? '未設定',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            '${_writingLabel(snapshot.style.writing)}・'
            '${snapshot.style.layout?.grid ?? '自動'}・'
            '${snapshot.style.stroke?.weight?.toStringAsFixed(1) ?? '-'}pt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesList extends StatelessWidget {
  const _ChangesList({required this.diff});

  final VersionDiff diff;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    if (diff.changes.isEmpty) {
      return const AppEmptyState(
        title: '差分はありません',
        message: '最新のバージョンと比較対象に違いはありません。',
        icon: Icons.check_circle_outline_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: diff.changes.map((change) {
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.sm),
          child: _ChangeTile(change: change),
        );
      }).toList(),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});

  final VersionChange change;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final icon = switch (change.kind) {
      VersionChangeKind.layout => Icons.view_week_rounded,
      VersionChangeKind.stroke => Icons.brush_rounded,
      VersionChangeKind.writing => Icons.title_rounded,
      VersionChangeKind.template => Icons.layers_rounded,
      VersionChangeKind.metadata => Icons.tag_rounded,
      VersionChangeKind.size => Icons.straighten_rounded,
    };

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tokens.colors.surfaceVariant,
            child: Icon(icon, color: tokens.colors.primary),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  '${change.before} → ${change.after}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
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

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.version,
    required this.selected,
    required this.isCurrent,
    required this.onSelect,
    this.onRestore,
  });

  final DesignVersion version;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final borderColor = selected
        ? tokens.colors.primary
        : tokens.colors.outline.withValues(alpha: 0.2);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.md),
      onTap: onSelect,
      backgroundColor: selected
          ? tokens.colors.surfaceVariant
          : tokens.colors.surface,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.sm,
              vertical: tokens.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(tokens.radii.sm),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'v${version.version}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.changeNote ?? '変更履歴なし',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  '${_relative(version.createdAt)} • ${version.createdBy}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                if (version.snapshot.style.templateRef != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    'テンプレート: ${version.snapshot.style.templateRef}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InputChip(
                label: Text(
                  isCurrent
                      ? '現在'
                      : selected
                      ? '比較中'
                      : '履歴',
                ),
                onPressed: null,
              ),
              if (onRestore != null) ...[
                SizedBox(height: tokens.spacing.xs),
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('復元'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final VersionAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = switch (entry.level) {
      VersionAuditLevel.success => tokens.colors.primary,
      VersionAuditLevel.warning => tokens.colors.error,
      VersionAuditLevel.info => tokens.colors.outline,
    };

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.event_note_rounded, color: color),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  '${_relative(entry.timestamp)} • ${entry.actor}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.6),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        if (action != null) action!,
      ],
    );
  }
}

class _VersionsSkeleton extends StatelessWidget {
  const _VersionsSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: const [
        AppSkeletonBlock(height: 140),
        SizedBox(height: 16),
        AppListSkeleton(items: 3, itemHeight: 96),
      ],
    );
  }
}

class _VersionsError extends StatelessWidget {
  const _VersionsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: AppEmptyState(
        title: '履歴の読み込みに失敗しました',
        message: message,
        icon: Icons.error_outline_rounded,
        actionLabel: '再試行',
        onAction: onRetry,
      ),
    );
  }
}

class _SimilarityGauge extends StatelessWidget {
  const _SimilarityGauge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation(tokens.colors.primary),
                  backgroundColor: tokens.colors.surfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              Text('${(value * 100).round()}%'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('類似度', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _writingLabel(WritingStyle style) {
  return switch (style) {
    WritingStyle.tensho => '篆書',
    WritingStyle.reisho => '隷書',
    WritingStyle.kaisho => '楷書',
    WritingStyle.gyosho => '行書',
    WritingStyle.koentai => '古印体',
    WritingStyle.custom => 'カスタム',
  };
}

String _relative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  return '${diff.inDays}日前';
}
