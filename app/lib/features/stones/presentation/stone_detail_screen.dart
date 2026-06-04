import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/core_widgets.dart';
import '../data/stone_listings_repository.dart';
import '../domain/stone_listing.dart';
import 'stone_selection_confirmation.dart';

typedef StoneImageGalleryOpener =
    void Function(StoneListing listing, int initialPhotoIndex);

class StoneDetailScreen extends StatefulWidget {
  const StoneDetailScreen({
    super.key,
    required this.listing,
    this.locale,
    this.loadStoneListing,
    this.onOpenImageGallery,
    this.isSelectedForOrder = false,
    this.onSelectStone,
    this.onBack,
  });

  final StoneListing listing;
  final String? locale;
  final StoneListingDetailLoader? loadStoneListing;
  final StoneImageGalleryOpener? onOpenImageGallery;
  final bool isSelectedForOrder;
  final ValueChanged<StoneListing>? onSelectStone;
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
              _StoneDetailHero(
                listing: listing,
                onOpenGallery: widget.onOpenImageGallery,
              ),
              const SizedBox(height: HankoSpacing.lg),
              _StoneDetailSummary(listing: listing),
              const SizedBox(height: HankoSpacing.lg),
              _StoneOrderStateSection(
                listing: listing,
                isSelectedForOrder:
                    widget.isSelectedForOrder && listing.isOrderable,
                isRefreshing: _isRefreshing,
                onSelectStone: widget.onSelectStone,
              ),
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
  const _StoneDetailHero({required this.listing, required this.onOpenGallery});

  final StoneListing listing;
  final StoneImageGalleryOpener? onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = _primaryPhoto(listing.photos);
    final thumbnails = _sortedPhotos(listing.photos);
    final primaryPhotoIndex = primaryPhoto == null
        ? 0
        : thumbnails.indexWhere(
            (photo) => photo.assetId == primaryPhoto.assetId,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: _StoneDetailGalleryTrigger(
            key: const Key('stone-detail-open-gallery'),
            enabled: primaryPhoto != null && onOpenGallery != null,
            onTap: () => onOpenGallery?.call(listing, primaryPhotoIndex),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HankoRadii.sm),
              child:
                  primaryPhoto == null || primaryPhoto.assetUrl.trim().isEmpty
                  ? _StoneDetailImageFallback(title: listing.title)
                  : _StoneDetailImage(
                      photo: primaryPhoto,
                      title: listing.title,
                    ),
            ),
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
                return _StoneDetailGalleryTrigger(
                  key: Key('stone-detail-gallery-thumbnail-$index'),
                  enabled: onOpenGallery != null,
                  onTap: () => onOpenGallery?.call(listing, index),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HankoRadii.sm),
                      child: photo.assetUrl.trim().isEmpty
                          ? _StoneDetailImageFallback(title: listing.title)
                          : _StoneDetailImage(
                              photo: photo,
                              title: listing.title,
                            ),
                    ),
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

class _StoneDetailGalleryTrigger extends StatelessWidget {
  const _StoneDetailGalleryTrigger({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
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

class StoneImageGalleryScreen extends StatefulWidget {
  const StoneImageGalleryScreen({
    super.key,
    required this.listing,
    this.initialPhotoIndex = 0,
    this.onBack,
  });

  final StoneListing listing;
  final int initialPhotoIndex;
  final VoidCallback? onBack;

  @override
  State<StoneImageGalleryScreen> createState() =>
      _StoneImageGalleryScreenState();
}

class _StoneImageGalleryScreenState extends State<StoneImageGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  List<StoneListingPhoto> get _photos => _sortedPhotos(widget.listing.photos);

  @override
  void initState() {
    super.initState();
    _currentIndex = _clampPhotoIndex(widget.initialPhotoIndex, _photos.length);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final materialL10n = MaterialLocalizations.of(context);
    final photos = _photos;
    final hasPhotos = photos.isNotEmpty;
    final counter = hasPhotos ? '${_currentIndex + 1} / ${photos.length}' : '';

    return Material(
      color: HankoColors.ink,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: widget.onBack,
                    color: HankoColors.surface,
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      widget.listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HankoTextStyles.label.copyWith(
                        color: HankoColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: HankoSpacing.sm),
                  Text(
                    counter,
                    key: const Key('stone-gallery-counter'),
                    style: HankoTextStyles.label.copyWith(
                      color: HankoColors.surface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: hasPhotos
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: photos.length,
                          onPageChanged: (index) =>
                              setState(() => _currentIndex = index),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: HankoSpacing.md,
                                vertical: HankoSpacing.sm,
                              ),
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                child: Center(
                                  child: _StoneGalleryImage(
                                    photo: photos[index],
                                    title: widget.listing.title,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          left: HankoSpacing.sm,
                          child: _StoneGalleryStepButton(
                            key: const Key('stone-gallery-previous'),
                            icon: Icons.chevron_left,
                            tooltip: materialL10n.previousPageTooltip,
                            enabled: _currentIndex > 0,
                            onPressed: () => _showPhoto(_currentIndex - 1),
                          ),
                        ),
                        Positioned(
                          right: HankoSpacing.sm,
                          child: _StoneGalleryStepButton(
                            key: const Key('stone-gallery-next'),
                            icon: Icons.chevron_right,
                            tooltip: materialL10n.nextPageTooltip,
                            enabled: _currentIndex < photos.length - 1,
                            onPressed: () => _showPhoto(_currentIndex + 1),
                          ),
                        ),
                      ],
                    )
                  : _StoneDetailImageFallback(title: widget.listing.title),
            ),
            if (photos.length > 1)
              SizedBox(
                height: 82,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    HankoSpacing.md,
                    0,
                    HankoSpacing.md,
                    HankoSpacing.sm,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return _StoneGalleryThumbnail(
                      key: Key('stone-gallery-thumbnail-$index'),
                      photo: photos[index],
                      title: widget.listing.title,
                      selected: selected,
                      onTap: () => _showPhoto(index),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: HankoSpacing.xs),
                  itemCount: photos.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPhoto(int index) {
    final nextIndex = _clampPhotoIndex(index, _photos.length);
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _StoneGalleryImage extends StatelessWidget {
  const _StoneGalleryImage({required this.photo, required this.title});

  final StoneListingPhoto photo;
  final String title;

  @override
  Widget build(BuildContext context) {
    final fallback = _StoneGalleryImageFallback(title: title);
    if (photo.assetUrl.trim().isEmpty) {
      return fallback;
    }

    return Image.network(
      photo.assetUrl,
      fit: BoxFit.contain,
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

class _StoneGalleryImageFallback extends StatelessWidget {
  const _StoneGalleryImageFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HankoColors.medallion,
          borderRadius: BorderRadius.circular(HankoRadii.sm),
        ),
        child: Center(
          child: Icon(
            Icons.diamond_outlined,
            color: HankoColors.gold,
            size: 72,
            semanticLabel: title,
          ),
        ),
      ),
    );
  }
}

class _StoneGalleryStepButton extends StatelessWidget {
  const _StoneGalleryStepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        backgroundColor: HankoColors.surface.withValues(alpha: 0.92),
        disabledBackgroundColor: HankoColors.surface.withValues(alpha: 0.36),
        foregroundColor: HankoColors.ink,
        disabledForegroundColor: HankoColors.body,
      ),
      icon: Icon(icon),
    );
  }
}

class _StoneGalleryThumbnail extends StatelessWidget {
  const _StoneGalleryThumbnail({
    super.key,
    required this.photo,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final StoneListingPhoto photo;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HankoRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          border: Border.all(
            color: selected ? HankoColors.gold : HankoColors.surfaceBorder,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          child: photo.assetUrl.trim().isEmpty
              ? _StoneDetailImageFallback(title: title)
              : _StoneDetailImage(photo: photo, title: title),
        ),
      ),
    );
  }
}

class _StoneOrderStateSection extends StatelessWidget {
  const _StoneOrderStateSection({
    required this.listing,
    required this.isSelectedForOrder,
    required this.isRefreshing,
    required this.onSelectStone,
  });

  final StoneListing listing;
  final bool isSelectedForOrder;
  final bool isRefreshing;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!listing.isOrderable) {
      return HankoSurfaceCard(
        key: const Key('stone-sold-out-state'),
        radius: HankoRadii.sm,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block, color: HankoColors.error, size: 22),
                const SizedBox(width: HankoSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.soldOutStoneTitle,
                        style: HankoTextStyles.label,
                      ),
                      const SizedBox(height: HankoSpacing.xs),
                      Text(
                        l10n.soldOutStoneMessage,
                        style: HankoTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: HankoSpacing.md),
            HankoPrimaryButton(
              label: l10n.selectStone,
              icon: Icons.block,
              onPressed: null,
            ),
          ],
        ),
      );
    }

    return HankoSurfaceCard(
      key: const Key('stone-selection-state'),
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSelectedForOrder
                ? l10n.stoneSelectedForOrderTitle
                : l10n.selectStoneConfirmationTitle,
            style: HankoTextStyles.label,
          ),
          const SizedBox(height: HankoSpacing.xs),
          Text(
            isSelectedForOrder
                ? l10n.stoneSelectedForOrderMessage
                : l10n.selectStoneConfirmationMessage,
            style: HankoTextStyles.body,
          ),
          const SizedBox(height: HankoSpacing.md),
          HankoPrimaryButton(
            key: const Key('stone-detail-select'),
            label: isSelectedForOrder
                ? l10n.stoneSelectedForOrderAction
                : l10n.selectStone,
            icon: isSelectedForOrder ? Icons.check : Icons.arrow_forward,
            onPressed:
                onSelectStone == null || isSelectedForOrder || isRefreshing
                ? null
                : () async {
                    final confirmed = await confirmStoneSelection(
                      context,
                      listing,
                    );
                    if (confirmed) {
                      onSelectStone?.call(listing);
                    }
                  },
          ),
        ],
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

int _clampPhotoIndex(int index, int photoCount) {
  if (photoCount <= 0 || index < 0) {
    return 0;
  }
  if (index >= photoCount) {
    return photoCount - 1;
  }
  return index;
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
