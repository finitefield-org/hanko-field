import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/core_widgets.dart';
import '../data/stone_listings_repository.dart';
import '../domain/stone_listing.dart';

class StoneDetailScreen extends StatefulWidget {
  const StoneDetailScreen({
    super.key,
    required this.listing,
    this.locale,
    this.loadStoneListing,
    this.onBack,
  });

  final StoneListing listing;
  final String? locale;
  final StoneListingDetailLoader? loadStoneListing;
  final VoidCallback? onBack;

  @override
  State<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends State<StoneDetailScreen> {
  late StoneListing _listing;
  var _isRefreshing = false;
  var _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
    unawaited(_refreshListing());
  }

  @override
  void didUpdateWidget(covariant StoneDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id ||
        oldWidget.locale != widget.locale ||
        oldWidget.loadStoneListing != widget.loadStoneListing) {
      _listing = widget.listing;
      unawaited(_refreshListing());
    }
  }

  Future<void> _refreshListing() async {
    final serial = ++_loadSerial;
    final loadStoneListing = widget.loadStoneListing;
    if (loadStoneListing == null) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      final listing = await loadStoneListing(
        StoneListingDetailQuery(
          listingId: widget.listing.id,
          locale: widget.locale,
        ),
      );
      if (!mounted || serial != _loadSerial) {
        return;
      }
      setState(() {
        _listing = listing;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted || serial != _loadSerial) {
        return;
      }
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listing = _listing;

    return Material(
      color: HankoColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, HankoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StoneDetailHeader(
                title: l10n.stoneDetailTitle,
                onBack: widget.onBack,
              ),
              const SizedBox(height: HankoSpacing.md),
              if (_isRefreshing) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: HankoSpacing.md),
              ],
              _StoneDetailHero(listing: listing),
              const SizedBox(height: HankoSpacing.lg),
              _StoneDetailSummary(listing: listing),
              const SizedBox(height: HankoSpacing.lg),
              _StoneDetailTextSection(
                title: l10n.stoneDetailDescriptionTitle,
                body: listing.description,
              ),
              const SizedBox(height: HankoSpacing.md),
              _StoneDetailTextSection(
                title: l10n.stoneDetailStoryTitle,
                body: listing.story,
              ),
              const SizedBox(height: HankoSpacing.lg),
              _StoneDetailSpecs(listing: listing),
              const SizedBox(height: HankoSpacing.lg),
              _StoneDetailNotes(message: l10n.stoneDetailNotesMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoneDetailHeader extends StatelessWidget {
  const _StoneDetailHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: HankoTextStyles.pageTitle.copyWith(fontSize: 31),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: context.l10n.back,
              onPressed: onBack,
              color: HankoColors.red,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoneDetailHero extends StatelessWidget {
  const _StoneDetailHero({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = _primaryPhoto(listing.photos);
    final thumbnails = _sortedPhotos(listing.photos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(HankoRadii.sm),
            child: primaryPhoto == null || primaryPhoto.assetUrl.trim().isEmpty
                ? _StoneDetailImageFallback(title: listing.title)
                : _StoneDetailImage(photo: primaryPhoto, title: listing.title),
          ),
        ),
        if (thumbnails.length > 1) ...[
          const SizedBox(height: HankoSpacing.sm),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final photo = thumbnails[index];
                return AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(HankoRadii.sm),
                    child: photo.assetUrl.trim().isEmpty
                        ? _StoneDetailImageFallback(title: listing.title)
                        : _StoneDetailImage(photo: photo, title: listing.title),
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(width: HankoSpacing.xs),
              itemCount: thumbnails.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _StoneDetailImage extends StatelessWidget {
  const _StoneDetailImage({required this.photo, required this.title});

  final StoneListingPhoto photo;
  final String title;

  @override
  Widget build(BuildContext context) {
    final fallback = _StoneDetailImageFallback(title: title);
    return Image.network(
      photo.assetUrl,
      fit: BoxFit.cover,
      semanticLabel: photo.alt,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return fallback;
      },
    );
  }
}

class _StoneDetailImageFallback extends StatelessWidget {
  const _StoneDetailImageFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: HankoColors.medallion),
      child: Center(
        child: Icon(
          Icons.diamond_outlined,
          color: HankoColors.gold,
          size: 58,
          semanticLabel: title,
        ),
      ),
    );
  }
}

class _StoneDetailSummary extends StatelessWidget {
  const _StoneDetailSummary({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_materialLabel(listing), style: HankoTextStyles.compactBody),
          const SizedBox(height: HankoSpacing.xs),
          Text(listing.title, style: HankoTextStyles.cardTitle),
          const SizedBox(height: HankoSpacing.sm),
          Text(_formatMoney(listing.price), style: HankoTextStyles.label),
          const SizedBox(height: HankoSpacing.md),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _StoneDetailAttribute(
                icon: Icons.sell_outlined,
                label: listing.code,
              ),
              _StoneDetailAttribute(
                icon: listing.isOrderable
                    ? Icons.check_circle_outline
                    : Icons.block,
                label: listing.isOrderable
                    ? l10n.stoneAvailable
                    : l10n.stoneUnavailable,
                color: listing.isOrderable
                    ? HankoColors.gold
                    : HankoColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoneDetailTextSection extends StatelessWidget {
  const _StoneDetailTextSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: HankoTextStyles.label),
          const SizedBox(height: HankoSpacing.sm),
          Text(trimmed, style: HankoTextStyles.body),
        ],
      ),
    );
  }
}

class _StoneDetailSpecs extends StatelessWidget {
  const _StoneDetailSpecs({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = [
      _StoneDetailRowData(
        icon: Icons.category_outlined,
        label: l10n.stoneDetailMaterialLabel,
        value: _materialLabel(listing),
      ),
      _StoneDetailRowData(
        icon: Icons.straighten,
        label: l10n.stoneDetailSizeLabel,
        value: listing.sizeLabel,
      ),
      _StoneDetailRowData(
        icon: Icons.palette_outlined,
        label: l10n.stoneDetailColorLabel,
        value: _labelFromToken(listing.facets.colorFamily),
      ),
      _StoneDetailRowData(
        icon: Icons.grain,
        label: l10n.stoneDetailPatternLabel,
        value: _labelFromToken(listing.facets.patternPrimary),
      ),
      _StoneDetailRowData(
        icon: Icons.crop_square,
        label: l10n.stoneDetailShapeLabel,
        value: _labelFromToken(listing.facets.stoneShape),
      ),
      _StoneDetailRowData(
        icon: Icons.water_drop_outlined,
        label: l10n.stoneDetailTextureLabel,
        value: _labelFromToken(listing.facets.translucency),
      ),
      _StoneDetailRowData(
        icon: listing.isOrderable ? Icons.check : Icons.block,
        label: l10n.stoneDetailStatusLabel,
        value: listing.isOrderable
            ? l10n.stoneAvailable
            : l10n.stoneUnavailable,
      ),
    ];

    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Text(
              l10n.stoneDetailSpecsTitle,
              style: HankoTextStyles.label,
            ),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            _StoneDetailRow(data: rows[index]),
            if (index < rows.length - 1)
              const Divider(color: HankoColors.surfaceBorder, height: 1),
          ],
        ],
      ),
    );
  }
}

class _StoneDetailRowData {
  const _StoneDetailRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StoneDetailRow extends StatelessWidget {
  const _StoneDetailRow({required this.data});

  final _StoneDetailRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: HankoColors.gold),
          const SizedBox(width: HankoSpacing.md),
          Expanded(child: Text(data.label, style: HankoTextStyles.compactBody)),
          const SizedBox(width: HankoSpacing.sm),
          Flexible(
            child: Text(
              data.value,
              textAlign: TextAlign.end,
              style: HankoTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoneDetailNotes extends StatelessWidget {
  const _StoneDetailNotes({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: HankoColors.gold, size: 21),
          const SizedBox(width: HankoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stoneDetailNotesTitle, style: HankoTextStyles.label),
                const SizedBox(height: HankoSpacing.xs),
                Text(message, style: HankoTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoneDetailAttribute extends StatelessWidget {
  const _StoneDetailAttribute({
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

StoneListingPhoto? _primaryPhoto(List<StoneListingPhoto> photos) {
  if (photos.isEmpty) {
    return null;
  }
  for (final photo in photos) {
    if (photo.isPrimary) {
      return photo;
    }
  }
  return _sortedPhotos(photos).first;
}

List<StoneListingPhoto> _sortedPhotos(List<StoneListingPhoto> photos) {
  return [...photos]..sort((left, right) {
    final order = left.sortOrder.compareTo(right.sortOrder);
    return order == 0 ? left.assetId.compareTo(right.assetId) : order;
  });
}

String _materialLabel(StoneListing listing) {
  final label = listing.materialLabel.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return _labelFromToken(listing.materialKey);
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
