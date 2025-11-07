import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/features/library/application/library_entry_detail_provider.dart';
import 'package:app/features/library/application/library_export_controller.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class LibraryExportPage extends ConsumerStatefulWidget {
  const LibraryExportPage({required this.designId, super.key});

  final String designId;

  @override
  ConsumerState<LibraryExportPage> createState() => _LibraryExportPageState();
}

class _LibraryExportPageState extends ConsumerState<LibraryExportPage> {
  ProviderSubscription<LibraryExportState>? _subscription;

  LibraryExportController get _controller =>
      ref.read(libraryExportControllerProvider(widget.designId).notifier);

  @override
  void initState() {
    super.initState();
    final provider = libraryExportControllerProvider(widget.designId);
    _subscription = ref.listenManual<LibraryExportState>(provider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        _controller.clearError();
      }
      if (next.activeLink != null && next.activeLink != previous?.activeLink) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryExportLinkReadySnack)),
        );
      }
      final revoked = previous?.hasLinks == true && next.hasLinks == false;
      if (revoked && !next.isRevoking) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryExportRevokedSnack)),
        );
      }
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
    final provider = libraryExportControllerProvider(widget.designId);
    final state = ref.watch(provider);
    final detailAsync = ref.watch(libraryDesignDetailProvider(widget.designId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryExportTitle),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.libraryExportHistoryTooltip,
            icon: const Icon(Icons.history_outlined),
            onPressed: state.history.isEmpty
                ? null
                : () => _showHistorySheet(state.history, l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: detailAsync.when(
          data: (detail) => _ExportContent(
            state: state,
            detail: detail,
            onScaleSelected: _controller.selectScale,
            onFormatSelected: _controller.selectFormat,
            onWatermarkChanged: _controller.toggleWatermark,
            onExpiryToggle: _controller.toggleLinkExpiry,
            onDownloadsChanged: _controller.toggleDownloads,
            onExpiryDaysChanged: _controller.updateExpiryDays,
            onCopyLink: _copyLink,
            onShareLink: _shareLink,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: AppEmptyState(
              icon: const Icon(Icons.download_outlined),
              title: l10n.libraryDetailErrorTitle,
              message: l10n.libraryLoadError,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.spaceL,
          AppTokens.spaceM,
          AppTokens.spaceL,
          AppTokens.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              icon: state.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_outlined),
              label: Text(l10n.libraryExportGenerateCta),
              onPressed: state.isGenerating ? null : _handleGenerateLink,
            ),
            const SizedBox(height: AppTokens.spaceS),
            OutlinedButton.icon(
              icon: state.isRevoking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(l10n.libraryExportRevokeCta),
              onPressed: state.isRevoking || !state.hasLinks
                  ? null
                  : () => _controller.revokeLinks(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerateLink() async {
    final link = await _controller.generateLink();
    if (!mounted || link == null) {
      return;
    }
    await _shareLink(link);
  }

  Future<void> _shareLink(LibraryExportLink link) async {
    final l10n = AppLocalizations.of(context);
    final subject = l10n.libraryExportShareSubject(widget.designId);
    await Share.share(link.url, subject: subject);
  }

  Future<void> _copyLink(LibraryExportLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.libraryExportCopySnack)));
  }

  void _showHistorySheet(
    List<LibraryExportLink> history,
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
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTokens.spaceM),
                Text(
                  l10n.libraryExportHistoryTitle,
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
                      final descriptor = _linkDescriptor(link, l10n);
                      return ListTile(
                        dense: true,
                        title: Text(descriptor),
                        subtitle: Text(_linkTimestamp(link.createdAt)),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: l10n.libraryExportCopySnack,
                          onPressed: () => _copyLink(link),
                        ),
                        onTap: () => _shareLink(link),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTokens.spaceL),
              ],
            ),
          ),
        );
      },
    );
  }

  String _linkDescriptor(LibraryExportLink link, AppLocalizations l10n) {
    final format = _formatLabel(link.format, l10n);
    final scaleLabel = l10n.libraryExportScaleChip(link.scale);
    return '$format · $scaleLabel';
  }

  String _linkTimestamp(DateTime timestamp) {
    final format = DateFormat('MMM d, HH:mm');
    return format.format(timestamp);
  }
}

class _ExportContent extends StatelessWidget {
  const _ExportContent({
    required this.state,
    required this.detail,
    required this.onFormatSelected,
    required this.onScaleSelected,
    required this.onWatermarkChanged,
    required this.onExpiryToggle,
    required this.onDownloadsChanged,
    required this.onExpiryDaysChanged,
    required this.onCopyLink,
    required this.onShareLink,
  });

  final LibraryExportState state;
  final LibraryDesignDetail detail;
  final ValueChanged<LibraryExportFormat> onFormatSelected;
  final ValueChanged<int> onScaleSelected;
  final ValueChanged<bool> onWatermarkChanged;
  final ValueChanged<bool> onExpiryToggle;
  final ValueChanged<bool> onDownloadsChanged;
  final ValueChanged<int> onExpiryDaysChanged;
  final Future<void> Function(LibraryExportLink) onCopyLink;
  final Future<void> Function(LibraryExportLink) onShareLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesignSummary(detail: detail, l10n: l10n),
          const SizedBox(height: AppTokens.spaceL),
          _FormatSection(
            state: state,
            onFormatSelected: onFormatSelected,
            l10n: l10n,
          ),
          const SizedBox(height: AppTokens.spaceL),
          _ScaleSection(
            state: state,
            onScaleSelected: onScaleSelected,
            l10n: l10n,
          ),
          const SizedBox(height: AppTokens.spaceL),
          _PermissionsSection(
            state: state,
            onWatermarkChanged: onWatermarkChanged,
            onExpiryToggle: onExpiryToggle,
            onDownloadsChanged: onDownloadsChanged,
            onExpiryDaysChanged: onExpiryDaysChanged,
            l10n: l10n,
          ),
          const SizedBox(height: AppTokens.spaceL),
          _LinkSection(
            state: state,
            l10n: l10n,
            onCopyLink: onCopyLink,
            onShareLink: onShareLink,
          ),
        ],
      ),
    );
  }
}

class _DesignSummary extends StatelessWidget {
  const _DesignSummary({required this.detail, required this.l10n});

  final LibraryDesignDetail detail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final design = detail.design;
    final chips = [
      _statusLabel(design.status, l10n),
      _personaLabel(design.persona, l10n),
      _shapeLabel(design.shape, l10n, design.size),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceXS),
            Text(
              '${l10n.libraryDetailMetadataId}: ${design.id}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            Wrap(
              spacing: AppTokens.spaceS,
              runSpacing: AppTokens.spaceS,
              children: [
                for (final chip in chips)
                  Chip(
                    label: Text(chip),
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatSection extends StatelessWidget {
  const _FormatSection({
    required this.state,
    required this.onFormatSelected,
    required this.l10n,
  });

  final LibraryExportState state;
  final ValueChanged<LibraryExportFormat> onFormatSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final recommendations = _formatRecommendations(state.format, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.libraryExportFormatLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        SegmentedButton<LibraryExportFormat>(
          segments: [
            ButtonSegment(
              value: LibraryExportFormat.png,
              label: Text(l10n.libraryExportFormatPng),
              icon: const Icon(Icons.image_outlined),
            ),
            ButtonSegment(
              value: LibraryExportFormat.svg,
              label: Text(l10n.libraryExportFormatSvg),
              icon: const Icon(Icons.layers_outlined),
            ),
            ButtonSegment(
              value: LibraryExportFormat.pdf,
              label: Text(l10n.libraryExportFormatPdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          selected: {state.format},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onFormatSelected(values.first),
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final hint in recommendations)
              ActionChip(label: Text(hint), onPressed: () {}),
          ],
        ),
      ],
    );
  }
}

class _ScaleSection extends StatelessWidget {
  const _ScaleSection({
    required this.state,
    required this.onScaleSelected,
    required this.l10n,
  });

  final LibraryExportState state;
  final ValueChanged<int> onScaleSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const options = LibraryExportController.scaleOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.libraryExportScaleLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.libraryExportScaleSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        SegmentedButton<int>(
          segments: [
            for (final option in options)
              ButtonSegment(
                value: option,
                label: Text(l10n.libraryExportScaleChip(option)),
              ),
          ],
          selected: {state.scale},
          onSelectionChanged: (values) => onScaleSelected(values.first),
        ),
      ],
    );
  }
}

class _PermissionsSection extends StatelessWidget {
  const _PermissionsSection({
    required this.state,
    required this.onWatermarkChanged,
    required this.onExpiryToggle,
    required this.onDownloadsChanged,
    required this.onExpiryDaysChanged,
    required this.l10n,
  });

  final LibraryExportState state;
  final ValueChanged<bool> onWatermarkChanged;
  final ValueChanged<bool> onExpiryToggle;
  final ValueChanged<bool> onDownloadsChanged;
  final ValueChanged<int> onExpiryDaysChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            title: Text(l10n.libraryExportWatermarkLabel),
            subtitle: Text(l10n.libraryExportWatermarkDescription),
            value: state.watermark,
            onChanged: onWatermarkChanged,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: Text(l10n.libraryExportExpiryLabel),
            subtitle: Text(
              state.linkExpires
                  ? l10n.libraryExportExpiryDescription(state.expiryDays)
                  : l10n.libraryExportExpiryDisabled,
            ),
            value: state.linkExpires,
            onChanged: onExpiryToggle,
          ),
          if (state.linkExpires)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceS,
              ),
              child: DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: l10n.libraryExportExpiryPicker,
                ),
                initialValue: state.expiryDays,
                items: [
                  for (final days
                      in LibraryExportController.expiryOptionsInDays)
                    DropdownMenuItem(
                      value: days,
                      child: Text(l10n.libraryExportExpiryDays(days)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onExpiryDaysChanged(value);
                  }
                },
              ),
            ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            title: Text(l10n.libraryExportDownloadsLabel),
            subtitle: Text(l10n.libraryExportDownloadsDescription),
            value: state.allowDownloads,
            onChanged: onDownloadsChanged,
          ),
        ],
      ),
    );
  }
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.state,
    required this.l10n,
    required this.onCopyLink,
    required this.onShareLink,
  });

  final LibraryExportState state;
  final AppLocalizations l10n;
  final Future<void> Function(LibraryExportLink) onCopyLink;
  final Future<void> Function(LibraryExportLink) onShareLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.libraryExportLinkTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceS),
            if (state.activeLink == null)
              AppEmptyState(
                icon: const Icon(Icons.link_off_outlined),
                title: l10n.libraryExportLinkEmptyTitle,
                message: l10n.libraryExportLinkEmptyMessage,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    state.activeLink!.url,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  Text(
                    _linkMeta(state.activeLink!, l10n),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceS),
                  Wrap(
                    spacing: AppTokens.spaceS,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.ios_share_outlined),
                        label: Text(l10n.libraryExportShareLink),
                        onPressed: () => onShareLink(state.activeLink!),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(l10n.libraryExportCopyLink),
                        onPressed: () => onCopyLink(state.activeLink!),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _linkMeta(LibraryExportLink link, AppLocalizations l10n) {
    final expiresLabel = link.expiresAt == null
        ? l10n.libraryExportExpiryDisabled
        : l10n.libraryExportExpiresOn(
            DateFormat.yMMMd().format(link.expiresAt!),
          );
    final formatLabel = l10n.libraryExportLinkMeta(
      _formatLabel(link.format, l10n),
      l10n.libraryExportScaleChip(link.scale),
    );
    return '$formatLabel · $expiresLabel';
  }
}

String _statusLabel(DesignStatus status, AppLocalizations l10n) {
  return switch (status) {
    DesignStatus.draft => l10n.homeDesignStatusDraft,
    DesignStatus.ready => l10n.homeDesignStatusReady,
    DesignStatus.ordered => l10n.homeDesignStatusOrdered,
    DesignStatus.locked => l10n.homeDesignStatusLocked,
  };
}

String _personaLabel(UserPersona? persona, AppLocalizations l10n) {
  return switch (persona) {
    UserPersona.japanese => l10n.libraryPersonaJapanese,
    UserPersona.foreigner => l10n.libraryPersonaForeigner,
    null => l10n.libraryPersonaAll,
  };
}

String _shapeLabel(DesignShape shape, AppLocalizations l10n, DesignSize size) {
  final label = switch (shape) {
    DesignShape.round => l10n.libraryDetailShapeRound,
    DesignShape.square => l10n.libraryDetailShapeSquare,
  };
  return '$label · ${size.mm.toStringAsFixed(0)}mm';
}

List<String> _formatRecommendations(
  LibraryExportFormat format,
  AppLocalizations l10n,
) {
  return switch (format) {
    LibraryExportFormat.png => [
      l10n.libraryExportFormatPngUseMessaging,
      l10n.libraryExportFormatPngUseTransparent,
    ],
    LibraryExportFormat.svg => [
      l10n.libraryExportFormatSvgUseVector,
      l10n.libraryExportFormatSvgUseCnc,
    ],
    LibraryExportFormat.pdf => [
      l10n.libraryExportFormatPdfUsePrint,
      l10n.libraryExportFormatPdfUseArchive,
    ],
  };
}

String _formatLabel(LibraryExportFormat format, AppLocalizations l10n) {
  return switch (format) {
    LibraryExportFormat.png => l10n.libraryExportFormatPng,
    LibraryExportFormat.svg => l10n.libraryExportFormatSvg,
    LibraryExportFormat.pdf => l10n.libraryExportFormatPdf,
  };
}
