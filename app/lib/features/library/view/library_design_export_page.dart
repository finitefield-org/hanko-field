// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_export_view_model.dart';
import 'package:app/features/library/view_model/library_design_export_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class LibraryDesignExportPage extends ConsumerStatefulWidget {
  const LibraryDesignExportPage({
    super.key,
    required this.designId,
    this.designOverride,
  });

  final String designId;
  final Design? designOverride;

  @override
  ConsumerState<LibraryDesignExportPage> createState() =>
      _LibraryDesignExportPageState();
}

class _LibraryDesignExportPageState
    extends ConsumerState<LibraryDesignExportPage> {
  int? _lastFeedbackId;
  late LibraryDesignExportViewModel _viewModel;
  late final ProviderSubscription<AsyncValue<LibraryDesignExportState>>
  _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _viewModel = LibraryDesignExportViewModel(
      designId: widget.designId,
      designOverride: widget.designOverride,
    );
    _feedbackCancel = ref.container
        .listen<AsyncValue<LibraryDesignExportState>>(_viewModel, (_, next) {
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
    final export = ref.watch(_viewModel);

    late final Widget body;
    switch (export) {
      case AsyncData(:final value):
        body = _LoadedBody(
          state: value,
          prefersEnglish: prefersEnglish,
          onFormatChanged: (format) => ref.invoke(_viewModel.setFormat(format)),
          onScaleChanged: (scale) => ref.invoke(_viewModel.setScale(scale)),
          onToggleWatermark: (enabled) =>
              ref.invoke(_viewModel.toggleWatermark(enabled)),
          onToggleExpiry: (enabled) =>
              ref.invoke(_viewModel.toggleExpiry(enabled)),
          onPickExpiryDays: () => _pickExpiryDays(
            context: context,
            prefersEnglish: prefersEnglish,
            selected: value.permissions.expiryDays,
            onSelected: (days) => ref.invoke(_viewModel.setExpiryDays(days)),
          ),
          onToggleDownload: (enabled) =>
              ref.invoke(_viewModel.toggleDownloadAllowed(enabled)),
          onCopyActiveLink: value.activeLink == null
              ? null
              : () => _copyToClipboard(
                  context,
                  value.activeLink!,
                  prefersEnglish ? 'Link copied' : 'リンクをコピーしました',
                ),
          onShareActiveLink: value.activeLink == null
              ? null
              : () => Share.share(value.activeLink!),
        );
      case AsyncLoading():
        body = _ExportSkeleton(prefersEnglish: prefersEnglish);
      case AsyncError(:final error):
        body = _ExportError(
          prefersEnglish: prefersEnglish,
          error: error,
          onRetry: () => ref.invalidate(_viewModel),
        );
    }

    Widget? bottomBar;
    switch (export) {
      case AsyncData(:final value):
        bottomBar = _ExportActions(
          state: value,
          prefersEnglish: prefersEnglish,
          onGenerate: () => ref.invoke(_viewModel.generateLink()),
          onRevokeAll: () => ref.invoke(_viewModel.revokeAll()),
        );
      default:
        bottomBar = null;
    }

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: _ExportAppBar(
        prefersEnglish: prefersEnglish,
        onOpenHistory: export.valueOrNull == null
            ? null
            : () => _openHistory(
                context: context,
                state: export.valueOrNull!,
                prefersEnglish: prefersEnglish,
              ),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomBar,
    );
  }

  void _handleFeedback(LibraryDesignExportState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), feedback);
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value,
    String message,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openHistory({
    required BuildContext context,
    required LibraryDesignExportState state,
    required bool prefersEnglish,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final tokens = DesignTokensTheme.of(sheetContext);
        final history = state.history;
        if (history.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.md),
            child: AppEmptyState(
              title: prefersEnglish ? 'No links yet' : 'リンク履歴はありません',
              message: prefersEnglish
                  ? 'Generate a link to see it here.'
                  : 'リンクを生成すると、ここに履歴が表示されます。',
              icon: Icons.history_toggle_off_rounded,
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Recent links' : '最近のリンク',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...history.map((record) {
              final subtitle = [
                record.format.label(prefersEnglish),
                record.scale.label(prefersEnglish),
                _permissionsLabel(record.permissions, prefersEnglish),
                _timeLabel(record.createdAt, prefersEnglish),
              ].where((part) => part.isNotEmpty).join(' • ');

              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(record.shortCode),
                  subtitle: Text(subtitle),
                  leading: const Icon(Icons.link_rounded),
                  trailing: IconButton(
                    tooltip: prefersEnglish ? 'Copy' : 'コピー',
                    onPressed: () => _copyToClipboard(
                      context,
                      record.url,
                      prefersEnglish ? 'Link copied' : 'リンクをコピーしました',
                    ),
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _pickExpiryDays({
    required BuildContext context,
    required bool prefersEnglish,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    const options = [1, 7, 14, 30, 90];
    return showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final tokens = DesignTokensTheme.of(sheetContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Expiry' : '有効期限',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...options.map((days) {
              final isSelected = days == selected;
              final label = prefersEnglish ? '$days days' : '$days 日';
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(label),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.schedule,
                  ),
                  trailing: isSelected ? const Icon(Icons.check_rounded) : null,
                  onTap: () {
                    onSelected(days);
                    Navigator.of(sheetContext).pop();
                  },
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
  const _ExportAppBar({required this.prefersEnglish, this.onOpenHistory});

  final bool prefersEnglish;
  final VoidCallback? onOpenHistory;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppBar(
      centerTitle: false,
      leading: const BackButton(),
      title: Text(prefersEnglish ? 'Export' : '出力'),
      actions: [
        IconButton(
          tooltip: prefersEnglish ? 'History' : '履歴',
          onPressed: onOpenHistory,
          icon: const Icon(Icons.history_toggle_off_rounded),
        ),
        SizedBox(width: tokens.spacing.sm),
      ],
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.state,
    required this.prefersEnglish,
    required this.onFormatChanged,
    required this.onScaleChanged,
    required this.onToggleWatermark,
    required this.onToggleExpiry,
    required this.onPickExpiryDays,
    required this.onToggleDownload,
    required this.onCopyActiveLink,
    required this.onShareActiveLink,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<ExportFormat> onFormatChanged;
  final ValueChanged<ExportScale> onScaleChanged;
  final ValueChanged<bool> onToggleWatermark;
  final ValueChanged<bool> onToggleExpiry;
  final VoidCallback onPickExpiryDays;
  final ValueChanged<bool> onToggleDownload;
  final VoidCallback? onCopyActiveLink;
  final VoidCallback? onShareActiveLink;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final basePx = exportPixelSize(state.design, state.format);
    final scaledPx = (basePx * state.scale.multiplier).round();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.xxl,
      ),
      children: [
        _SummaryCard(
          state: state,
          prefersEnglish: prefersEnglish,
          basePx: basePx,
          scaledPx: scaledPx,
        ),
        SizedBox(height: tokens.spacing.md),
        _FormatCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onChanged: onFormatChanged,
        ),
        SizedBox(height: tokens.spacing.md),
        _ScaleCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onChanged: onScaleChanged,
        ),
        SizedBox(height: tokens.spacing.md),
        _PermissionsCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onToggleWatermark: onToggleWatermark,
          onToggleExpiry: onToggleExpiry,
          onPickExpiryDays: onPickExpiryDays,
          onToggleDownload: onToggleDownload,
        ),
        SizedBox(height: tokens.spacing.md),
        _LinkCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onCopy: onCopyActiveLink,
          onShare: onShareActiveLink,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.state,
    required this.prefersEnglish,
    required this.basePx,
    required this.scaledPx,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final int basePx;
  final int scaledPx;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.design.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: [
              _InfoChip(
                icon: Icons.straighten,
                label: '${state.design.sizeMm.toStringAsFixed(1)} mm',
              ),
              _InfoChip(
                icon: Icons.texture,
                label: _shapeLabel(state.design.shape, prefersEnglish),
              ),
              _InfoChip(
                icon: Icons.font_download_outlined,
                label: _writingLabel(state.design.writingStyle, prefersEnglish),
              ),
              _InfoChip(
                icon: Icons.layers_outlined,
                label: state.format.label(prefersEnglish),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Render target: $scaledPx px ($basePx × ${state.scale.label(prefersEnglish)})'
                : '書き出し解像度: $scaledPx px（$basePx × ${state.scale.label(prefersEnglish)}）',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.state,
    required this.prefersEnglish,
    required this.onChanged,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<ExportFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final chips = _formatChips(state.format, prefersEnglish);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Format' : 'フォーマット',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          SegmentedButton<ExportFormat>(
            segments: ExportFormat.values.map((format) {
              return ButtonSegment(
                value: format,
                icon: _formatIcon(format),
                label: Text(format.label(prefersEnglish)),
              );
            }).toList(),
            selected: {state.format},
            onSelectionChanged: (selection) {
              final value = selection.isNotEmpty
                  ? selection.first
                  : state.format;
              onChanged(value);
            },
          ),
          if (chips.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.sm),
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

class _ScaleCard extends StatelessWidget {
  const _ScaleCard({
    required this.state,
    required this.prefersEnglish,
    required this.onChanged,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<ExportScale> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Scale' : 'スケール',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          SegmentedButton<ExportScale>(
            segments: ExportScale.values.map((scale) {
              return ButtonSegment(
                value: scale,
                icon: const Icon(Icons.aspect_ratio_outlined),
                label: Text(scale.label(prefersEnglish)),
              );
            }).toList(),
            selected: {state.scale},
            onSelectionChanged: (selection) {
              final value = selection.isNotEmpty
                  ? selection.first
                  : state.scale;
              onChanged(value);
            },
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Higher scale increases file size and clarity.'
                : 'スケールを上げると、ファイルサイズと解像度が上がります。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.state,
    required this.prefersEnglish,
    required this.onToggleWatermark,
    required this.onToggleExpiry,
    required this.onPickExpiryDays,
    required this.onToggleDownload,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<bool> onToggleWatermark;
  final ValueChanged<bool> onToggleExpiry;
  final VoidCallback onPickExpiryDays;
  final ValueChanged<bool> onToggleDownload;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final perms = state.permissions;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Permissions' : '権限',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          AppListTile(
            title: Text(prefersEnglish ? 'Watermark' : '透かし'),
            subtitle: Text(
              prefersEnglish
                  ? 'Show a light preview watermark.'
                  : 'プレビュー用の薄い透かしを表示します。',
            ),
            leading: const Icon(Icons.water_drop_outlined),
            trailing: Switch(
              value: perms.watermark,
              onChanged: onToggleWatermark,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          AppListTile(
            title: Text(prefersEnglish ? 'Expiry' : '有効期限'),
            subtitle: Text(
              prefersEnglish
                  ? 'Automatically expires shared links.'
                  : '共有リンクを自動で期限切れにします。',
            ),
            leading: const Icon(Icons.schedule_rounded),
            trailing: Switch(
              value: perms.expiryEnabled,
              onChanged: onToggleExpiry,
            ),
          ),
          if (perms.expiryEnabled) ...[
            SizedBox(height: tokens.spacing.xs),
            AppListTile(
              title: Text(prefersEnglish ? 'Expires after' : '期限'),
              subtitle: Text(
                prefersEnglish
                    ? '${perms.expiryDays} days'
                    : '${perms.expiryDays} 日',
              ),
              leading: const Icon(Icons.timelapse_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickExpiryDays,
            ),
          ],
          SizedBox(height: tokens.spacing.xs),
          AppListTile(
            title: Text(prefersEnglish ? 'Allow download' : 'ダウンロードを許可'),
            subtitle: Text(
              prefersEnglish
                  ? 'Let viewers download the file.'
                  : '閲覧者がファイルを保存できます。',
            ),
            leading: const Icon(Icons.download_outlined),
            trailing: Switch(
              value: perms.downloadAllowed,
              onChanged: onToggleDownload,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.state,
    required this.prefersEnglish,
    required this.onCopy,
    required this.onShare,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final link = state.activeLink;
    final subtitle = _permissionsLabel(state.permissions, prefersEnglish);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Share link' : '共有リンク',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          if (link == null) ...[
            Text(
              prefersEnglish
                  ? 'Generate a link to share this export.'
                  : 'リンクを生成して、この書き出しを共有できます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ] else ...[
            SelectableText(link, style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: tokens.spacing.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(prefersEnglish ? 'Copy' : 'コピー'),
                ),
                SizedBox(width: tokens.spacing.sm),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(prefersEnglish ? 'Share' : '共有'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.state,
    required this.prefersEnglish,
    required this.onGenerate,
    required this.onRevokeAll,
  });

  final LibraryDesignExportState state;
  final bool prefersEnglish;
  final VoidCallback onGenerate;
  final VoidCallback onRevokeAll;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final generating = state.isGenerating;
    final revoking = state.isRevoking;
    final busy = state.isBusy;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.lg,
          tokens.spacing.sm,
          tokens.spacing.lg,
          tokens.spacing.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : onGenerate,
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(prefersEnglish ? 'Generate link' : 'リンクを生成'),
              ),
            ),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || state.history.isEmpty ? null : onRevokeAll,
                icon: revoking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.block_rounded),
                label: Text(prefersEnglish ? 'Revoke all' : 'すべて無効化'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSkeleton extends StatelessWidget {
  const _ExportSkeleton({required this.prefersEnglish});

  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator.adaptive(),
            SizedBox(height: tokens.spacing.md),
            Text(prefersEnglish ? 'Loading…' : '読み込み中…'),
          ],
        ),
      ),
    );
  }
}

class _ExportError extends StatelessWidget {
  const _ExportError({
    required this.prefersEnglish,
    required this.error,
    required this.onRetry,
  });

  final bool prefersEnglish;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: AppEmptyState(
        title: prefersEnglish ? 'Failed to load export' : '出力の読み込みに失敗しました',
        message: error.toString(),
        icon: Icons.error_outline_rounded,
        actionLabel: prefersEnglish ? 'Retry' : '再試行',
        onAction: onRetry,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.sm,
          vertical: tokens.spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.colors.onSurface),
            SizedBox(width: tokens.spacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Icon _formatIcon(ExportFormat format) => switch (format) {
  ExportFormat.png => const Icon(Icons.image_outlined),
  ExportFormat.svg => const Icon(Icons.format_shapes_outlined),
  ExportFormat.pdf => const Icon(Icons.picture_as_pdf_outlined),
};

List<Widget> _formatChips(ExportFormat format, bool prefersEnglish) {
  final (label, icon) = switch (format) {
    ExportFormat.png => (
      prefersEnglish ? 'Best for chat' : 'チャット向け',
      Icons.chat_bubble_outline,
    ),
    ExportFormat.svg => (
      prefersEnglish ? 'Best for vector' : 'ベクター向け',
      Icons.insights_outlined,
    ),
    ExportFormat.pdf => (
      prefersEnglish ? 'Best for print' : '印刷向け',
      Icons.local_printshop_outlined,
    ),
  };

  return [
    ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {},
    ),
  ];
}

String _shapeLabel(SealShape shape, bool prefersEnglish) => switch (shape) {
  SealShape.round => prefersEnglish ? 'Round' : '丸印',
  SealShape.square => prefersEnglish ? 'Square' : '角印',
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

String _permissionsLabel(ExportLinkPermissions perms, bool prefersEnglish) {
  final parts = <String>[
    perms.watermark ? (prefersEnglish ? 'watermark' : '透かし') : '',
    perms.expiryEnabled
        ? (prefersEnglish
              ? 'expires in ${perms.expiryDays}d'
              : '${perms.expiryDays}日で期限切れ')
        : (prefersEnglish ? 'no expiry' : '期限なし'),
    perms.downloadAllowed
        ? (prefersEnglish ? 'download on' : 'DL許可')
        : (prefersEnglish ? 'download off' : 'DL不可'),
  ].where((part) => part.isNotEmpty).toList();
  return parts.join(' • ');
}

String _timeLabel(DateTime timestamp, bool prefersEnglish) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return prefersEnglish ? 'just now' : 'たった今';
  if (diff.inMinutes < 60) {
    return prefersEnglish ? '${diff.inMinutes}m ago' : '${diff.inMinutes}分前';
  }
  if (diff.inHours < 24) {
    return prefersEnglish ? '${diff.inHours}h ago' : '${diff.inHours}時間前';
  }
  return prefersEnglish ? '${diff.inDays}d ago' : '${diff.inDays}日前';
}
