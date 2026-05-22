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
            label: l10n.chooseSavedSeal,
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
  const _SavedSealPreview({required this.design});

  final LocalSealDesign design;

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
      dimension: 104,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        child: preview,
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
