import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/stone_listing.dart';

class StonesHomeScreen extends StatelessWidget {
  const StonesHomeScreen({
    super.key,
    this.result,
    this.isLoading = false,
    this.loadError,
    this.onRetry,
    this.onSelectStone,
  });

  final StoneListingsResult? result;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback? onRetry;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listings = result?.listings ?? const <StoneListing>[];

    return HankoFeaturePage(
      title: l10n.stones,
      children: [
        Text(l10n.browseStonesDescription, style: HankoTextStyles.body),
        const SizedBox(height: HankoSpacing.sm),
        if (isLoading)
          HankoStateView.loading(
            title: l10n.stonesLoadingTitle,
            message: l10n.stonesLoadingMessage,
          )
        else if (loadError != null)
          HankoStateView.error(
            title: l10n.stonesLoadErrorTitle,
            message: l10n.stonesLoadErrorMessage,
            actionLabel: l10n.tryAgain,
            onAction: onRetry,
          )
        else if (listings.isEmpty)
          HankoStateView.empty(
            title: l10n.noStonesLoaded,
            message: l10n.noStonesLoadedMessage,
          )
        else
          for (var index = 0; index < listings.length; index++) ...[
            _StoneListingCard(
              listing: listings[index],
              onSelectStone: onSelectStone,
            ),
            if (index < listings.length - 1)
              const SizedBox(height: HankoSpacing.md),
          ],
      ],
    );
  }
}

class _StoneListingCard extends StatelessWidget {
  const _StoneListingCard({required this.listing, required this.onSelectStone});

  final StoneListing listing;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoSurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StoneListingImage(listing: listing),
          const SizedBox(height: HankoSpacing.md),
          Text(
            _labelFromToken(listing.materialKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HankoTextStyles.compactBody,
          ),
          const SizedBox(height: HankoSpacing.xs),
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HankoTextStyles.cardTitle,
          ),
          const SizedBox(height: HankoSpacing.sm),
          Text(_formatMoney(listing.price), style: HankoTextStyles.label),
          const SizedBox(height: HankoSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _StoneAttributeChip(
                icon: Icons.palette_outlined,
                label: _labelFromToken(listing.facets.colorFamily),
              ),
              _StoneAttributeChip(
                icon: Icons.grain,
                label: _labelFromToken(listing.facets.patternPrimary),
              ),
              _StoneAttributeChip(
                icon: Icons.straighten,
                label: listing.sizeLabel,
              ),
              _StoneAvailabilityChip(listing: listing),
            ],
          ),
          const SizedBox(height: HankoSpacing.md),
          HankoPrimaryButton(
            label: l10n.selectStone,
            icon: Icons.arrow_forward,
            onPressed: listing.isOrderable && onSelectStone != null
                ? () => onSelectStone?.call(listing)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StoneListingImage extends StatelessWidget {
  const _StoneListingImage({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = _primaryPhoto(listing.photos);
    final fallback = _StoneImageFallback(title: listing.title);

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        child: primaryPhoto == null || primaryPhoto.assetUrl.trim().isEmpty
            ? fallback
            : Image.network(
                primaryPhoto.assetUrl,
                fit: BoxFit.cover,
                semanticLabel: primaryPhoto.alt,
                errorBuilder: (context, error, stackTrace) => fallback,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return fallback;
                },
              ),
      ),
    );
  }

  StoneListingPhoto? _primaryPhoto(List<StoneListingPhoto> photos) {
    if (photos.isEmpty) {
      return null;
    }
    for (final photo in photos) {
      if (photo.isPrimary) {
        return photo;
      }
    }
    final sorted = [...photos]
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return sorted.first;
  }
}

class _StoneImageFallback extends StatelessWidget {
  const _StoneImageFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: HankoColors.medallion),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          color: HankoColors.gold,
          size: 54,
          semanticLabel: title,
        ),
      ),
    );
  }
}

class _StoneAvailabilityChip extends StatelessWidget {
  const _StoneAvailabilityChip({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAvailable = listing.isOrderable;
    return _StoneAttributeChip(
      icon: isAvailable ? Icons.check_circle_outline : Icons.block,
      label: isAvailable ? l10n.stoneAvailable : l10n.stoneUnavailable,
      color: isAvailable ? HankoColors.gold : HankoColors.error,
    );
  }
}

class _StoneAttributeChip extends StatelessWidget {
  const _StoneAttributeChip({
    required this.icon,
    required this.label,
    this.color = HankoColors.body,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 6),
        Text(label, style: HankoTextStyles.compactBody),
      ],
    );
  }
}

String _formatMoney(Money money) {
  final display = money.display?.trim();
  if (display != null && display.isNotEmpty) {
    return display;
  }
  final formattedAmount = _formatWholeNumber(money.amount);
  return switch (money.currency.toUpperCase()) {
    'JPY' => '¥$formattedAmount',
    'USD' => '\$$formattedAmount',
    _ => '${money.currency.toUpperCase()} $formattedAmount',
  };
}

String _formatWholeNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer(sign);
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _labelFromToken(String token) {
  final words = token
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return token;
  }
  return words
      .map((word) {
        if (word.length == 1) {
          return word.toUpperCase();
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}
