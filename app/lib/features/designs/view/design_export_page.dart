// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message_helpers.dart';
import 'package:app/core/feedback/app_message_provider.dart';
import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/view_model/design_export_view_model.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

class DesignExportPage extends ConsumerStatefulWidget {
  const DesignExportPage({super.key});

  @override
  ConsumerState<DesignExportPage> createState() => _DesignExportPageState();
}

class _DesignExportPageState extends ConsumerState<DesignExportPage> {
  int? _lastFeedbackId;
  late final ProviderSubscription<AsyncValue<DesignExportState>>
  _feedbackCancel;

  @override
  void initState() {
    super.initState();
    _feedbackCancel = ref.container.listen<AsyncValue<DesignExportState>>(
      designExportViewModel,
      (_, next) {
        if (next case AsyncData(:final value)) {
          _handleFeedback(value);
        }
      },
    );
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
    final export = ref.watch(designExportViewModel);

    late final Widget body;
    switch (export) {
      case AsyncData(:final value):
        body = _buildLoadedBody(
          context: context,
          state: value,
          prefersEnglish: prefersEnglish,
        );
      case AsyncLoading():
        body = _ExportSkeleton(prefersEnglish: prefersEnglish);
      case AsyncError(:final error):
        body = _ExportError(
          prefersEnglish: prefersEnglish,
          error: error,
          onRetry: () => ref.invalidate(designExportViewModel),
        );
    }

    Widget? bottomBar;
    switch (export) {
      case AsyncData(:final value):
        bottomBar = _ExportActions(
          state: value,
          prefersEnglish: prefersEnglish,
          onExport: () => _handleExport(context, value, prefersEnglish),
          onShare: () => _handleShare(context, value, prefersEnglish),
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

  Widget _buildLoadedBody({
    required BuildContext context,
    required DesignExportState state,
    required bool prefersEnglish,
  }) {
    return _ExportBody(
      state: state,
      prefersEnglish: prefersEnglish,
      onExport: () => _handleExport(context, state, prefersEnglish),
      onShare: () => _handleShare(context, state, prefersEnglish),
      onRequestPermission: () =>
          ref.invoke(designExportViewModel.ensurePermission()),
      onFormatChanged: (format) =>
          ref.invoke(designExportViewModel.setFormat(format)),
      onTransparentChanged: (enabled) =>
          ref.invoke(designExportViewModel.toggleTransparent(enabled)),
      onBleedChanged: (enabled) =>
          ref.invoke(designExportViewModel.toggleBleed(enabled)),
      onMetadataChanged: (enabled) =>
          ref.invoke(designExportViewModel.toggleMetadata(enabled)),
      onWatermarkChanged: (enabled) =>
          ref.invoke(designExportViewModel.toggleWatermark(enabled)),
    );
  }

  void _handleFeedback(DesignExportState state) {
    final feedback = state.feedbackMessage;
    if (feedback == null) return;
    if (state.feedbackId == _lastFeedbackId) return;
    _lastFeedbackId = state.feedbackId;
    emitMessageFromText(ref.container.read(appMessageSinkProvider), feedback);
  }

  Future<void> _handleExport(
    BuildContext context,
    DesignExportState state,
    bool prefersEnglish,
  ) async {
    if (state.isExporting || state.isSharing) return;
    final destination = await _pickDestination(context, prefersEnglish);
    if (destination == null) return;
    await ref.invoke(
      designExportViewModel.export(destination: destination.title),
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    DesignExportState state,
    bool prefersEnglish,
  ) async {
    if (state.isExporting || state.isSharing) return;
    final target = await _pickShareTarget(context, prefersEnglish);
    if (target == null) return;
    await ref.invoke(designExportViewModel.share(target: target.title));
  }

  Future<_SheetOption?> _pickDestination(
    BuildContext context,
    bool prefersEnglish,
  ) {
    final options = [
      _SheetOption(
        title: prefersEnglish ? 'Downloads' : 'ダウンロード',
        subtitle: prefersEnglish
            ? 'Keep locally with offline access'
            : 'オフラインでも使える端末保存',
        icon: Icons.download_rounded,
      ),
      _SheetOption(
        title: prefersEnglish ? 'Files / iCloud Drive' : 'ファイル / iCloud Drive',
        subtitle: prefersEnglish ? 'Sync across devices' : 'デバイス間で同期',
        icon: Icons.cloud_upload_outlined,
      ),
      _SheetOption(
        title: prefersEnglish ? 'Photos / Gallery' : '写真・ギャラリー',
        subtitle: prefersEnglish ? 'Show in camera roll' : 'カメラロールに追加',
        icon: Icons.photo_library_outlined,
      ),
    ];

    return showAppBottomSheet<_SheetOption>(
      context: context,
      builder: (sheetContext) {
        final tokens = DesignTokensTheme.of(sheetContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Choose save location' : '保存先を選択',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...options.map((option) {
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  leading: Icon(option.icon),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<_SheetOption?> _pickShareTarget(
    BuildContext context,
    bool prefersEnglish,
  ) {
    final options = [
      _SheetOption(
        title: prefersEnglish ? 'Messages' : 'メッセージ',
        subtitle: prefersEnglish ? 'Send chat-ready preview' : 'チャット向けプレビュー',
        icon: Icons.chat_bubble_outline,
      ),
      _SheetOption(
        title: prefersEnglish ? 'Mail' : 'メール',
        subtitle: prefersEnglish ? 'Attach PNG + SVG' : 'PNG + SVG を添付',
        icon: Icons.alternate_email_rounded,
      ),
      _SheetOption(
        title: prefersEnglish ? 'AirDrop / Nearby' : 'AirDrop / 近くにシェア',
        subtitle: prefersEnglish ? 'Send lossless file' : '無劣化ファイルを送信',
        icon: Icons.wifi_tethering,
      ),
      _SheetOption(
        title: prefersEnglish ? 'Copy link' : 'リンクをコピー',
        subtitle: prefersEnglish ? 'Shared from cloud workspace' : 'クラウドから共有',
        icon: Icons.link_rounded,
      ),
      _SheetOption(
        title: prefersEnglish ? 'Slack / Teams' : 'Slack / Teams',
        subtitle: prefersEnglish ? 'Hand-off to teammates' : 'チームに引き継ぎ',
        icon: Icons.send_outlined,
      ),
    ];

    return showAppBottomSheet<_SheetOption>(
      context: context,
      builder: (sheetContext) {
        final tokens = DesignTokensTheme.of(sheetContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Share with' : '共有先を選択',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...options.map((option) {
              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  leading: Icon(option.icon),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _openHistory({
    required BuildContext context,
    required DesignExportState state,
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
              title: prefersEnglish ? 'No exports yet' : '書き出し履歴はありません',
              message: prefersEnglish
                  ? 'Run an export to see it here.'
                  : 'ここに最近の書き出しが並びます。',
              icon: Icons.download_done_rounded,
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prefersEnglish ? 'Recent exports' : '最近の書き出し',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            ...history.map((record) {
              final timeLabel = _timeLabel(record.createdAt, prefersEnglish);
              final sizeLabel = '${record.fileSizeMb.toStringAsFixed(2)} MB';
              final watermarked = record.watermarked
                  ? (prefersEnglish ? 'watermarked' : '透かし入り')
                  : '';
              final subtitle = [
                record.destination,
                sizeLabel,
                if (record.sharedVia != null) record.sharedVia!,
                if (watermarked.isNotEmpty) watermarked,
                timeLabel,
              ].where((part) => part.isNotEmpty).join(' • ');

              return Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: AppListTile(
                  title: Text(record.label),
                  subtitle: Text(subtitle),
                  leading: Icon(
                    record.sharedVia == null
                        ? Icons.download_done_rounded
                        : Icons.ios_share_rounded,
                  ),
                  trailing: Text(record.format.label(prefersEnglish)),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _ExportBody extends StatelessWidget {
  const _ExportBody({
    required this.state,
    required this.prefersEnglish,
    required this.onExport,
    required this.onShare,
    required this.onRequestPermission,
    required this.onFormatChanged,
    required this.onTransparentChanged,
    required this.onBleedChanged,
    required this.onMetadataChanged,
    required this.onWatermarkChanged,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final VoidCallback onExport;
  final VoidCallback onShare;
  final VoidCallback onRequestPermission;
  final ValueChanged<ExportFormat> onFormatChanged;
  final ValueChanged<bool> onTransparentChanged;
  final ValueChanged<bool> onBleedChanged;
  final ValueChanged<bool> onMetadataChanged;
  final ValueChanged<bool> onWatermarkChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final px = exportPixelSize(state.design, state.format);
    final estimatedSize = estimateExportSizeMb(state);

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
          _PermissionCard(
            prefersEnglish: prefersEnglish,
            status: state.storageStatus,
            onRequest: onRequestPermission,
          ),
          SizedBox(height: tokens.spacing.md),
        ],
        _DesignSummaryCard(
          state: state,
          prefersEnglish: prefersEnglish,
          pixelSize: px,
        ),
        SizedBox(height: tokens.spacing.md),
        _FormatCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onChanged: onFormatChanged,
        ),
        SizedBox(height: tokens.spacing.md),
        _OptionsCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onTransparentChanged: onTransparentChanged,
          onBleedChanged: onBleedChanged,
          onMetadataChanged: onMetadataChanged,
          onWatermarkChanged: onWatermarkChanged,
        ),
        SizedBox(height: tokens.spacing.md),
        _ProfileCard(
          state: state,
          prefersEnglish: prefersEnglish,
          pixelSize: px,
          estimatedSize: estimatedSize,
        ),
        SizedBox(height: tokens.spacing.md),
        _StatusCard(
          state: state,
          prefersEnglish: prefersEnglish,
          onExport: onExport,
          onShare: onShare,
        ),
      ],
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
      centerTitle: true,
      leading: const BackButton(),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prefersEnglish ? 'Digital export' : 'デジタル書き出し'),
          Text(
            prefersEnglish
                ? 'Color-managed PNG / SVG / PDF'
                : 'カラー管理された PNG / SVG / PDF',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
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

class _DesignSummaryCard extends StatelessWidget {
  const _DesignSummaryCard({
    required this.state,
    required this.prefersEnglish,
    required this.pixelSize,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final int pixelSize;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final chips = [
      _InfoChip(
        icon: Icons.straighten,
        label: '${state.design.sizeMm.toStringAsFixed(1)} mm',
      ),
      _InfoChip(
        icon: Icons.font_download_outlined,
        label: _writingLabel(state.design.writingStyle, prefersEnglish),
      ),
      _InfoChip(
        icon: Icons.texture,
        label: _shapeLabel(state.design.shape, prefersEnglish),
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.design.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: chips,
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Render target: $pixelSize px square'
                : '書き出し解像度: $pixelSize px 四方',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (state.design.templateName != null) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              prefersEnglish
                  ? 'Template: ${state.design.templateName}'
                  : 'テンプレート: ${state.design.templateName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
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

  final DesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<ExportFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
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
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: tokens.colors.outline,
              ),
              SizedBox(width: tokens.spacing.xs),
              Expanded(
                child: Text(
                  prefersEnglish
                      ? 'Color profile: ${state.colorProfile}'
                      : 'カラープロファイル: ${state.colorProfile}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
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

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.state,
    required this.prefersEnglish,
    required this.onTransparentChanged,
    required this.onBleedChanged,
    required this.onMetadataChanged,
    required this.onWatermarkChanged,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final ValueChanged<bool> onTransparentChanged;
  final ValueChanged<bool> onBleedChanged;
  final ValueChanged<bool> onMetadataChanged;
  final ValueChanged<bool> onWatermarkChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            title: Text(prefersEnglish ? 'Transparent background' : '背景を透過'),
            subtitle: Text(
              prefersEnglish
                  ? 'Ideal for overlays and mockups.'
                  : '透過PNGでモック作成に便利です。',
            ),
            leading: const Icon(Icons.grid_off_rounded),
            trailing: Switch(
              value: state.transparentBackground,
              onChanged: onTransparentChanged,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          AppListTile(
            title: Text(
              prefersEnglish ? 'Include bleed (1.5mm)' : '塗り足し 1.5mm を追加',
            ),
            subtitle: Text(
              prefersEnglish
                  ? 'Prevents clipping on print and laser cutting.'
                  : 'レーザー加工や印刷での欠け防止に。',
            ),
            leading: const Icon(Icons.center_focus_strong_outlined),
            trailing: Switch(
              value: state.includeBleed,
              onChanged: onBleedChanged,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          AppListTile(
            title: Text(prefersEnglish ? 'Embed metadata' : 'メタデータを埋め込む'),
            subtitle: Text(
              prefersEnglish
                  ? 'Author, creation method, export intent.'
                  : '作者・生成方法・用途をメタデータ化。',
            ),
            leading: const Icon(Icons.badge_outlined),
            trailing: Switch(
              value: state.includeMetadata,
              onChanged: onMetadataChanged,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          AppListTile(
            title: Text(
              prefersEnglish ? 'Watermark when sharing' : '共有時に透かしを付与',
            ),
            subtitle: Text(
              prefersEnglish
                  ? 'Light social watermark for PNG only.'
                  : 'SNS共有時のみ薄い透かしを付与します。',
            ),
            leading: const Icon(Icons.water_drop_outlined),
            trailing: Switch(
              value: state.watermarkOnShare,
              onChanged: onWatermarkChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.state,
    required this.prefersEnglish,
    required this.pixelSize,
    required this.estimatedSize,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final int pixelSize;
  final double estimatedSize;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final dpi = _ppiFor(state.format);
    final bleed = state.includeBleed
        ? (prefersEnglish ? '+ 1.5mm bleed' : '＋ 塗り足し 1.5mm')
        : (prefersEnglish ? 'Bleed off' : '塗り足しなし');
    final metadata = state.includeMetadata
        ? (prefersEnglish ? 'Metadata embedded' : 'メタデータ埋め込み')
        : (prefersEnglish ? 'No metadata' : 'メタデータなし');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Export profile' : '出力プロファイル',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Icon(Icons.hdr_strong, color: tokens.colors.primary),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: Text(
                  prefersEnglish
                      ? '$pixelSize px @ ${dpi}dpi (${state.format.label(true)})'
                      : '$pixelSize px @ ${dpi}dpi（${state.format.label(false)}）',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            prefersEnglish
                ? '${state.colorProfile} • $bleed • $metadata'
                : '${state.colorProfile}・$bleed・$metadata',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Row(
            children: [
              Icon(
                Icons.storage_outlined,
                size: 18,
                color: tokens.colors.outline,
              ),
              SizedBox(width: tokens.spacing.xs),
              Text(
                prefersEnglish
                    ? 'Est. ${estimatedSize.toStringAsFixed(2)} MB'
                    : '推定 ${estimatedSize.toStringAsFixed(2)} MB',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: tokens.colors.outline,
              ),
              SizedBox(width: tokens.spacing.xs),
              Text(
                prefersEnglish ? 'Aligned color profile' : 'カラーマッチ済み',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.prefersEnglish,
    required this.onExport,
    required this.onShare,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final VoidCallback onExport;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final exporting = state.isExporting || state.isSharing;
    final progressLabel = (state.progress * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);
    final subtitle = state.isSharing
        ? (prefersEnglish ? 'Sharing via sheet…' : '共有シートを開いています…')
        : (prefersEnglish ? 'Rendering high-res export…' : '高解像度で書き出し中…');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Status' : '進行状況',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing.sm),
          if (exporting) ...[
            LinearProgressIndicator(value: state.progress.clamp(0.0, 1.0)),
            SizedBox(height: tokens.spacing.xs),
            Text(
              '$progressLabel% — $subtitle',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else if (state.lastExportPath != null) ...[
            Text(
              prefersEnglish
                  ? 'Last export: ${state.lastExportPath}'
                  : '最後の書き出し: ${state.lastExportPath}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (state.lastSharedVia != null) ...[
              SizedBox(height: tokens.spacing.xs),
              Text(
                prefersEnglish
                    ? 'Shared via ${state.lastSharedVia}'
                    : '${state.lastSharedVia} で共有済み',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ] else ...[
            Text(
              prefersEnglish
                  ? 'Ready to export or share.'
                  : '書き出し・共有の準備ができています。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.prefersEnglish,
    required this.status,
    required this.onRequest,
  });

  final bool prefersEnglish;
  final StoragePermissionStatus status;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final color = tokens.colors.primary.withValues(alpha: 0.08);
    final text = switch (status) {
      StoragePermissionStatus.granted =>
        prefersEnglish ? 'Storage granted' : '保存権限は許可済みです',
      StoragePermissionStatus.denied =>
        prefersEnglish ? 'Storage permission required' : 'ストレージ権限が必要です',
      StoragePermissionStatus.restricted =>
        prefersEnglish ? 'Storage is restricted' : 'ストレージ使用が制限されています',
    };

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        border: Border.all(color: tokens.colors.primary.withValues(alpha: 0.3)),
      ),
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Row(
        children: [
          Icon(Icons.lock_open_rounded, color: tokens.colors.primary),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
          AppButton(
            label: prefersEnglish ? 'Allow' : '許可する',
            dense: true,
            variant: AppButtonVariant.secondary,
            onPressed: onRequest,
          ),
        ],
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.state,
    required this.prefersEnglish,
    required this.onExport,
    required this.onShare,
  });

  final DesignExportState state;
  final bool prefersEnglish;
  final VoidCallback onExport;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final exporting = state.isExporting || state.isSharing;

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
              child: AppButton(
                label: prefersEnglish ? 'Export' : '書き出す',
                onPressed: exporting ? null : onExport,
                isLoading: state.isExporting,
                leading: const Icon(Icons.download_rounded),
                expand: true,
              ),
            ),
            SizedBox(width: tokens.spacing.sm),
            Expanded(
              child: AppButton(
                label: prefersEnglish ? 'Share sheet' : '共有シート',
                onPressed: exporting ? null : onShare,
                isLoading: state.isSharing,
                variant: AppButtonVariant.ghost,
                leading: const Icon(Icons.ios_share_rounded),
                expand: true,
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: const [
        AppSkeletonBlock(height: 120),
        SizedBox(height: 12),
        AppSkeletonBlock(height: 140),
        SizedBox(height: 12),
        AppListSkeleton(items: 3, itemHeight: 80),
        SizedBox(height: 12),
        AppSkeletonBlock(height: 120),
      ],
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
      padding: EdgeInsets.all(tokens.spacing.xl),
      child: AppEmptyState(
        title: prefersEnglish
            ? 'Could not load export tools'
            : '書き出し画面を開けませんでした',
        message: error.toString(),
        icon: Icons.error_outline,
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
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: tokens.colors.surfaceVariant.withValues(alpha: 0.6),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.xs,
        vertical: tokens.spacing.xs / 2,
      ),
    );
  }
}

class _SheetOption {
  _SheetOption({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

String _shapeLabel(SealShape shape, bool prefersEnglish) => switch (shape) {
  SealShape.round => prefersEnglish ? 'Round seal' : '丸印',
  SealShape.square => prefersEnglish ? 'Square seal' : '角印',
};

String _writingLabel(WritingStyle writing, bool prefersEnglish) =>
    switch (writing) {
      WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
      WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
      WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
      WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
      WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
      WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
    };

Icon _formatIcon(ExportFormat format) => switch (format) {
  ExportFormat.png => const Icon(Icons.image_outlined),
  ExportFormat.svg => const Icon(Icons.format_shapes_outlined),
  ExportFormat.pdf => const Icon(Icons.picture_as_pdf_outlined),
};

int _ppiFor(ExportFormat format) => switch (format) {
  ExportFormat.png => 1200,
  ExportFormat.svg => 960,
  ExportFormat.pdf => 900,
};

String _timeLabel(DateTime time, bool prefersEnglish) {
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inMinutes < 1) {
    return prefersEnglish ? 'just now' : 'たった今';
  }
  if (difference.inMinutes < 60) {
    final m = difference.inMinutes;
    return prefersEnglish ? '$m min ago' : '$m 分前';
  }
  if (difference.inHours < 24) {
    final h = difference.inHours;
    return prefersEnglish ? '$h h ago' : '$h 時間前';
  }
  final days = difference.inDays;
  return prefersEnglish ? '$days d ago' : '$days 日前';
}
