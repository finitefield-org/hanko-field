import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/local_seal_design.dart';

class MySealsHomeScreen extends StatelessWidget {
  const MySealsHomeScreen({
    super.key,
    this.designs = const [],
    this.isLoading = false,
    this.loadError,
    this.onStartDesigning,
    this.onExploreStones,
    this.onChooseSeal,
  });

  final List<LocalSealDesign> designs;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback? onStartDesigning;
  final VoidCallback? onExploreStones;
  final ValueChanged<LocalSealDesign>? onChooseSeal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoFeaturePage(
      title: l10n.mySeals,
      children: [
        Text(l10n.savedOnThisDevice, style: HankoTextStyles.body),
        const SizedBox(height: HankoSpacing.sm),
        if (isLoading)
          HankoStateView.loading(
            title: l10n.savedSealsLoadingTitle,
            message: l10n.savedSealsLoadingMessage,
          )
        else if (loadError != null)
          HankoStateView.error(
            title: l10n.savedSealsLoadErrorTitle,
            message: l10n.savedSealsLoadErrorMessage,
          )
        else if (designs.isEmpty)
          _MySealsEmptyState(
            onStartDesigning: onStartDesigning,
            onExploreStones: onExploreStones,
          )
        else
          for (var index = 0; index < designs.length; index++) ...[
            _SavedSealCard(
              design: designs[index],
              onChoose: onChooseSeal == null
                  ? null
                  : () => onChooseSeal?.call(designs[index]),
            ),
            if (index < designs.length - 1)
              const SizedBox(height: HankoSpacing.md),
          ],
      ],
    );
  }
}

class _MySealsEmptyState extends StatelessWidget {
  const _MySealsEmptyState({
    required this.onStartDesigning,
    required this.onExploreStones,
  });

  final VoidCallback? onStartDesigning;
  final VoidCallback? onExploreStones;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HankoStateView.empty(
          title: l10n.noSavedSeals,
          message: l10n.noSavedSealsMessage,
          actionLabel: l10n.startDesigning,
          onAction: onStartDesigning,
        ),
        if (onExploreStones != null) ...[
          const SizedBox(height: HankoSpacing.sm),
          TextButton.icon(
            onPressed: onExploreStones,
            style: TextButton.styleFrom(
              foregroundColor: HankoColors.gold,
              textStyle: HankoTextStyles.label,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.diamond_outlined, size: 18),
            label: Text(l10n.browseStones),
          ),
        ],
      ],
    );
  }
}

class _SavedSealCard extends StatelessWidget {
  const _SavedSealCard({required this.design, required this.onChoose});

  final LocalSealDesign design;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SavedSealPreview(design: design),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            design.selectedKanji,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HankoTextStyles.sectionTitle.copyWith(
                              fontFamily: HankoFonts.serif,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FavoriteBadge(isFavorite: design.isFavorite),
                      ],
                    ),
                    const SizedBox(height: HankoSpacing.xs),
                    Text(
                      _sealMeaningText(design),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HankoTextStyles.body,
                    ),
                    const SizedBox(height: HankoSpacing.md),
                    _SavedSealAttributes(design: design),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HankoSpacing.md),
          const Divider(color: HankoColors.surfaceBorder, height: 1),
          const SizedBox(height: HankoSpacing.md),
          HankoPrimaryButton(
            label: l10n.viewSealDetails,
            icon: Icons.arrow_forward,
            onPressed: onChoose,
          ),
        ],
      ),
    );
  }

  String _sealMeaningText(LocalSealDesign design) {
    final meaning = design.meaning?.trim();
    if (meaning != null && meaning.isNotEmpty) {
      return meaning;
    }
    return design.reading;
  }
}

class _SavedSealPreview extends StatelessWidget {
  const _SavedSealPreview({required this.design, this.dimension = 104});

  final LocalSealDesign design;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final localPath = design.localImagePath.trim();
    final localFile = localPath.isEmpty ? null : File(localPath);
    final previewUrl = design.previewImageDownloadUrl.trim();
    final fallback = _SavedSealMedallion(text: design.selectedKanji);

    final Widget preview;
    if (localFile != null && localFile.existsSync()) {
      preview = Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    } else if (previewUrl.isNotEmpty) {
      preview = Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return fallback;
        },
      );
    } else {
      preview = fallback;
    }

    return SizedBox.square(
      dimension: dimension,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        child: preview,
      ),
    );
  }
}

class SealDetailScreen extends StatelessWidget {
  const SealDetailScreen({
    super.key,
    required this.design,
    this.isSelectedForOrder = false,
    this.onChooseForOrder,
    this.onDelete,
    this.onBack,
  });

  final LocalSealDesign design;
  final bool isSelectedForOrder;
  final ValueChanged<LocalSealDesign>? onChooseForOrder;
  final Future<void> Function(LocalSealDesign design)? onDelete;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: HankoColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, HankoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SealDetailHeader(title: l10n.sealDetailTitle, onBack: onBack),
              const SizedBox(height: HankoSpacing.lg),
              _SealDetailHeroCard(design: design),
              const SizedBox(height: HankoSpacing.lg),
              _SealDetailInfoRows(design: design),
              const SizedBox(height: HankoSpacing.lg),
              _SealDetailStyleGrid(design: design),
              const SizedBox(height: HankoSpacing.lg),
              if (isSelectedForOrder) ...[
                HankoStateView(
                  kind: HankoStateKind.success,
                  title: l10n.sealSelectedForOrderTitle,
                  message: l10n.sealSelectedForOrderMessage,
                ),
                const SizedBox(height: HankoSpacing.lg),
              ],
              _SealDetailActions(
                design: design,
                isSelectedForOrder: isSelectedForOrder,
                onChooseForOrder: onChooseForOrder,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SealDetailActions extends StatelessWidget {
  const _SealDetailActions({
    required this.design,
    required this.isSelectedForOrder,
    required this.onChooseForOrder,
    required this.onDelete,
  });

  final LocalSealDesign design;
  final bool isSelectedForOrder;
  final ValueChanged<LocalSealDesign>? onChooseForOrder;
  final Future<void> Function(LocalSealDesign design)? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HankoPrimaryButton(
          label: isSelectedForOrder
              ? l10n.sealSelectedForOrderAction
              : l10n.chooseSealForOrder,
          icon: isSelectedForOrder ? Icons.check : Icons.arrow_forward,
          onPressed: onChooseForOrder == null || isSelectedForOrder
              ? null
              : () => onChooseForOrder?.call(design),
        ),
        const SizedBox(height: HankoSpacing.sm),
        OutlinedButton.icon(
          onPressed: onDelete == null
              ? null
              : () => _confirmDelete(context, design, onDelete!),
          style: OutlinedButton.styleFrom(
            foregroundColor: HankoColors.error,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: HankoColors.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HankoRadii.sm),
            ),
          ),
          icon: const Icon(Icons.delete_outline),
          label: Text(
            l10n.deleteSavedSeal,
            style: HankoTextStyles.label.copyWith(color: HankoColors.error),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LocalSealDesign design,
    Future<void> Function(LocalSealDesign design) deleteDesign,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: HankoColors.surface,
          title: Text(l10n.deleteSealTitle, style: HankoTextStyles.cardTitle),
          content: Text(l10n.deleteSealMessage, style: HankoTextStyles.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: HankoColors.error),
              child: Text(l10n.deleteSealConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await deleteDesign(design);
  }
}

class _SealDetailHeader extends StatelessWidget {
  const _SealDetailHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: context.l10n.back,
              onPressed: onBack,
              color: HankoColors.red,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HankoTextStyles.pageTitle.copyWith(fontSize: 31),
          ),
        ],
      ),
    );
  }
}

class _SealDetailHeroCard extends StatelessWidget {
  const _SealDetailHeroCard({required this.design});

  final LocalSealDesign design;

  @override
  Widget build(BuildContext context) {
    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Center(child: _SavedSealPreview(design: design, dimension: 216)),
    );
  }
}

class _SealDetailInfoRows extends StatelessWidget {
  const _SealDetailInfoRows({required this.design});

  final LocalSealDesign design;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meaning = design.meaning?.trim();
    final rows = [
      _DetailInfoRowData(
        iconLabel: design.selectedKanji,
        label: l10n.kanjiLabel,
        value: design.selectedKanji,
      ),
      _DetailInfoRowData(
        iconLabel: _leadingCharacter(design.reading),
        label: l10n.kanjiReadingLabel,
        value: design.reading,
      ),
      _DetailInfoRowData(
        icon: Icons.auto_awesome,
        label: l10n.kanjiMeaningLabel,
        value: meaning == null || meaning.isEmpty ? design.reading : meaning,
      ),
      _DetailInfoRowData(
        icon: Icons.event_outlined,
        label: l10n.createdAtLabel,
        value: _formatSavedSealDate(design.createdAt),
      ),
    ];

    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _SealDetailInfoRow(data: rows[index]),
            if (index < rows.length - 1)
              const Divider(color: HankoColors.surfaceBorder, height: 1),
          ],
        ],
      ),
    );
  }
}

class _DetailInfoRowData {
  const _DetailInfoRowData({
    required this.label,
    required this.value,
    this.icon,
    this.iconLabel,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? iconLabel;
}

class _SealDetailInfoRow extends StatelessWidget {
  const _SealDetailInfoRow({required this.data});

  final _DetailInfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _DetailBadge(icon: data.icon, label: data.iconLabel),
          const SizedBox(width: HankoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: HankoTextStyles.compactBody),
                const SizedBox(height: 7),
                Text(
                  data.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HankoTextStyles.cardTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SealDetailStyleGrid extends StatelessWidget {
  const _SealDetailStyleGrid({required this.design});

  final LocalSealDesign design;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      _StyleDetailTileData(
        icon: Icons.crop_square,
        label: l10n.sealShapeLabel,
        value: _sealShapeLabel(l10n, design.shape),
      ),
      _StyleDetailTileData(
        icon: Icons.auto_awesome_outlined,
        label: l10n.sealStyleNameLabel,
        value: _sealStyleNameLabel(l10n, design.style),
      ),
      _StyleDetailTileData(
        icon: Icons.line_weight,
        label: l10n.sealStrokeWeightLabel,
        value: _sealStrokeWeightLabel(l10n, design.strokeWeight),
      ),
      _StyleDetailTileData(
        icon: Icons.balance_outlined,
        label: l10n.sealBalanceLabel,
        value: _sealBalanceLabel(l10n, design.balance),
      ),
    ];

    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: HankoSpacing.md,
        mainAxisSpacing: HankoSpacing.md,
        childAspectRatio: 2.85,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final item in items) _SealDetailStyleTile(data: item)],
      ),
    );
  }
}

class _StyleDetailTileData {
  const _StyleDetailTileData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _SealDetailStyleTile extends StatelessWidget {
  const _SealDetailStyleTile({required this.data});

  final _StyleDetailTileData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DetailBadge(icon: data.icon),
        const SizedBox(width: HankoSpacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.compactBody,
              ),
              const SizedBox(height: 6),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.label.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({this.icon, this.label});

  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HankoColors.medallion,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 52,
        child: Center(
          child: icon == null
              ? Text(
                  label ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HankoTextStyles.label.copyWith(
                    color: HankoColors.red,
                    fontFamily: HankoFonts.serif,
                    fontSize: 17,
                  ),
                )
              : Icon(icon, color: HankoColors.gold, size: 24),
        ),
      ),
    );
  }
}

class _SavedSealMedallion extends StatelessWidget {
  const _SavedSealMedallion({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: HankoColors.medallion),
      child: Center(
        child: SizedBox.square(
          dimension: 82,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HankoColors.red,
              shape: BoxShape.circle,
              border: Border.all(color: HankoColors.gold, width: 1.3),
            ),
            child: Center(
              child: Text(
                text,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.cardTitle.copyWith(
                  color: Colors.white,
                  fontFamily: HankoFonts.serif,
                  fontSize: 28,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({required this.isFavorite});

  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HankoColors.medallion,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(
          isFavorite ? Icons.star : Icons.favorite_border,
          color: isFavorite ? HankoColors.gold : HankoColors.ink,
          size: 20,
        ),
      ),
    );
  }
}

class _SavedSealAttributes extends StatelessWidget {
  const _SavedSealAttributes({required this.design});

  final LocalSealDesign design;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final values = [
      (Icons.auto_awesome_outlined, _sealStyleNameLabel(l10n, design.style)),
      (Icons.line_weight, _sealStrokeWeightLabel(l10n, design.strokeWeight)),
      (Icons.balance_outlined, _sealBalanceLabel(l10n, design.balance)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final value in values)
          _AttributeChip(icon: value.$1, label: value.$2),
      ],
    );
  }
}

class _AttributeChip extends StatelessWidget {
  const _AttributeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: HankoColors.body, size: 17),
        const SizedBox(width: 6),
        Text(label, style: HankoTextStyles.compactBody),
      ],
    );
  }
}

String _sealStyleNameLabel(HankoLocalizations l10n, String style) {
  return switch (style) {
    'traditional' => l10n.sealStyleTraditional,
    'elegant' => l10n.sealStyleElegant,
    'soft' => l10n.sealStyleSoft,
    'bold' => l10n.sealStyleBold,
    _ => style,
  };
}

String _sealShapeLabel(HankoLocalizations l10n, String shape) {
  return switch (shape) {
    'square' => l10n.sealShapeSquare,
    'round' => l10n.sealShapeRound,
    _ => shape,
  };
}

String _sealStrokeWeightLabel(HankoLocalizations l10n, String strokeWeight) {
  return switch (strokeWeight) {
    'standard' => l10n.sealStrokeStandard,
    'bold' => l10n.sealStrokeBold,
    _ => strokeWeight,
  };
}

String _sealBalanceLabel(HankoLocalizations l10n, String balance) {
  return switch (balance) {
    'airy' => l10n.sealBalanceAiry,
    'balanced' => l10n.sealBalanceBalanced,
    'dense' => l10n.sealBalanceDense,
    _ => balance,
  };
}

String _formatSavedSealDate(DateTime date) {
  final local = date.toLocal();
  final day = [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('-');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $hour:$minute';
}

String _leadingCharacter(String value) {
  if (value.isEmpty) {
    return '';
  }
  return String.fromCharCode(value.runes.first);
}
