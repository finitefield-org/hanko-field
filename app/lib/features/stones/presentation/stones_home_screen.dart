import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/domain/money.dart';
import '../../../core/widgets/core_widgets.dart';
import '../domain/stone_listing.dart';
import 'stone_selection_confirmation.dart';

class StonesHomeScreen extends StatefulWidget {
  const StonesHomeScreen({
    super.key,
    this.result,
    this.isLoading = false,
    this.loadError,
    this.onRetry,
    this.onOpenStoneDetail,
    this.selectedStoneId,
    this.onSelectStone,
  });

  final StoneListingsResult? result;
  final bool isLoading;
  final Object? loadError;
  final VoidCallback? onRetry;
  final ValueChanged<StoneListing>? onOpenStoneDetail;
  final String? selectedStoneId;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  State<StonesHomeScreen> createState() => _StonesHomeScreenState();
}

class _StonesHomeScreenState extends State<StonesHomeScreen> {
  var _filters = const _StoneFilters();
  var _sortOrder = _StoneSortOrder.recommended;

  @override
  void didUpdateWidget(covariant StonesHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _filters = _filters.constrainTo(
        widget.result?.listings ?? const <StoneListing>[],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listings = widget.result?.listings ?? const <StoneListing>[];
    final filteredListings = _filters.apply(listings);
    final sortedListings = _sortOrder.apply(filteredListings);

    return HankoFeaturePage(
      title: l10n.stones,
      children: [
        if (widget.isLoading)
          HankoStateView.loading(
            title: l10n.stonesLoadingTitle,
            message: l10n.stonesLoadingMessage,
          )
        else if (widget.loadError != null)
          HankoErrorStateView(
            error: widget.loadError,
            actionLabel: l10n.tryAgain,
            onAction: widget.onRetry,
          )
        else if (listings.isEmpty)
          HankoStateView.empty(
            title: l10n.noStonesLoaded,
            message: l10n.noStonesLoadedMessage,
          )
        else ...[
          _StoneListToolbar(
            sortOrder: _sortOrder,
            activeFilterCount: _filters.activeCount,
            onOpenSort: _showSortSheet,
            onOpenFilters: () => _showFilterSheet(listings),
          ),
          if (_filters.hasActive) ...[
            const SizedBox(height: HankoSpacing.xs),
            _StoneActiveFiltersBar(
              listings: listings,
              filters: _filters,
              onChanged: (filters) => setState(() => _filters = filters),
            ),
          ],
          const SizedBox(height: HankoSpacing.sm),
          if (sortedListings.isEmpty)
            HankoStateView.empty(
              title: l10n.noStonesMatchFilters,
              message: l10n.noStonesMatchFiltersMessage,
            )
          else
            for (var index = 0; index < sortedListings.length; index++) ...[
              _StoneListingCard(
                listing: sortedListings[index],
                onOpenStoneDetail: widget.onOpenStoneDetail,
                isSelectedForOrder:
                    sortedListings[index].isOrderable &&
                    widget.selectedStoneId == sortedListings[index].id,
                onSelectStone: widget.onSelectStone,
              ),
              if (index < sortedListings.length - 1)
                const SizedBox(height: HankoSpacing.sm),
            ],
        ],
      ],
    );
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_StoneSortOrder>(
      context: context,
      // Shown above the whole app so the scrim also covers the status bar
      // and the tab bar.
      useRootNavigator: true,
      backgroundColor: HankoColors.surface,
      showDragHandle: true,
      builder: (context) => _StoneSortSheet(selected: _sortOrder),
    );
    if (!mounted || selected == null || selected == _sortOrder) {
      return;
    }
    setState(() => _sortOrder = selected);
  }

  Future<void> _showFilterSheet(List<StoneListing> listings) async {
    final applied = await showModalBottomSheet<_StoneFilters>(
      context: context,
      useRootNavigator: true,
      backgroundColor: HankoColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _StoneFilterSheet(listings: listings, initialFilters: _filters),
    );
    if (!mounted || applied == null) {
      return;
    }
    // The listings may have been refreshed while the sheet was open, so drop
    // any choice that is no longer on offer.
    setState(() {
      _filters = applied.constrainTo(
        widget.result?.listings ?? const <StoneListing>[],
      );
    });
  }
}

enum _StoneSortOrder {
  recommended,
  newest,
  priceLowToHigh,
  priceHighToLow;

  List<StoneListing> apply(List<StoneListing> listings) {
    if (this == _StoneSortOrder.recommended) {
      return List.of(listings, growable: false);
    }

    final sorted = [
      for (var index = 0; index < listings.length; index++)
        (index: index, listing: listings[index]),
    ];
    switch (this) {
      case _StoneSortOrder.recommended:
        break;
      case _StoneSortOrder.newest:
        sorted.sort((left, right) {
          final order = right.listing.sortOrder.compareTo(
            left.listing.sortOrder,
          );
          return order == 0 ? left.index.compareTo(right.index) : order;
        });
      case _StoneSortOrder.priceLowToHigh:
        sorted.sort((left, right) {
          final price = left.listing.price.amount.compareTo(
            right.listing.price.amount,
          );
          return price == 0 ? left.index.compareTo(right.index) : price;
        });
      case _StoneSortOrder.priceHighToLow:
        sorted.sort((left, right) {
          final price = right.listing.price.amount.compareTo(
            left.listing.price.amount,
          );
          return price == 0 ? left.index.compareTo(right.index) : price;
        });
    }
    return sorted.map((entry) => entry.listing).toList(growable: false);
  }
}

String _sortLabel(GeneratedHankoLocalizations l10n, _StoneSortOrder sortOrder) {
  return switch (sortOrder) {
    _StoneSortOrder.recommended => l10n.stoneSortRecommended,
    _StoneSortOrder.newest => l10n.stoneSortNewest,
    _StoneSortOrder.priceLowToHigh => l10n.stoneSortPriceLowToHigh,
    _StoneSortOrder.priceHighToLow => l10n.stoneSortPriceHighToLow,
  };
}

String _sortKey(_StoneSortOrder sortOrder) {
  return switch (sortOrder) {
    _StoneSortOrder.recommended => 'recommended',
    _StoneSortOrder.newest => 'newest',
    _StoneSortOrder.priceLowToHigh => 'price-low-to-high',
    _StoneSortOrder.priceHighToLow => 'price-high-to-low',
  };
}

/// Compact header row above the list: the current sort order on the leading
/// side and the filter sheet trigger (with an active-filter count) on the
/// trailing side, so the stones themselves start right below it.
class _StoneListToolbar extends StatelessWidget {
  const _StoneListToolbar({
    required this.sortOrder,
    required this.activeFilterCount,
    required this.onOpenSort,
    required this.onOpenFilters,
  });

  final _StoneSortOrder sortOrder;
  final int activeFilterCount;
  final VoidCallback onOpenSort;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasActiveFilters = activeFilterCount > 0;
    return Row(
      children: [
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _StoneToolbarButton(
              key: const Key('stone-sort-open'),
              semanticsLabel: l10n.stoneSortAction,
              semanticsValue: _sortLabel(l10n, sortOrder),
              icon: Icons.swap_vert,
              label: _sortLabel(l10n, sortOrder),
              onPressed: onOpenSort,
            ),
          ),
        ),
        const SizedBox(width: HankoSpacing.xs),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _StoneToolbarButton(
              key: const Key('stone-filters-open'),
              semanticsLabel: l10n.stoneFiltersTitle,
              semanticsValue: hasActiveFilters
                  ? l10n.stoneFilterActiveCount(activeFilterCount)
                  : null,
              icon: Icons.tune,
              label: l10n.stoneFiltersTitle,
              highlighted: hasActiveFilters,
              badgeCount: hasActiveFilters ? activeFilterCount : null,
              onPressed: onOpenFilters,
            ),
          ),
        ),
      ],
    );
  }
}

class _StoneToolbarButton extends StatelessWidget {
  const _StoneToolbarButton({
    super.key,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
    this.badgeCount,
  });

  final String semanticsLabel;
  final String? semanticsValue;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final count = badgeCount;
    return Semantics(
      button: true,
      label: semanticsLabel,
      value: semanticsValue,
      excludeSemantics: true,
      onTap: onPressed,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HankoColors.ink,
          backgroundColor: highlighted
              ? HankoColors.medallion
              : HankoColors.surface,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(
            color: highlighted ? HankoColors.gold : HankoColors.surfaceBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HankoRadii.sm),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: HankoColors.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.label,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HankoColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: HankoTextStyles.label.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoneSortSheet extends StatelessWidget {
  const _StoneSortSheet({required this.selected});

  final _StoneSortOrder selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = _StoneSortOrder.values;
    return SafeArea(
      // Scrolls when the sheet is shorter than its options, as in landscape.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.stoneSortTitle,
              textAlign: TextAlign.center,
              style: HankoTextStyles.sectionTitle,
            ),
            const SizedBox(height: HankoSpacing.md),
            for (final option in options)
              _StoneSortOptionTile(
                key: Key('stone-sort-${_sortKey(option)}'),
                label: _sortLabel(l10n, option),
                selected: option == selected,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoneSortOptionTile extends StatelessWidget {
  const _StoneSortOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(HankoRadii.sm),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: HankoColors.surfaceBorder, width: 0.7),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.label,
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? HankoColors.gold : HankoColors.body,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoneFilters {
  const _StoneFilters({
    this.materialKey,
    this.colorFamily,
    this.patternPrimary,
    this.availability,
  });

  final String? materialKey;
  final String? colorFamily;
  final String? patternPrimary;
  final String? availability;

  bool get hasActive =>
      materialKey != null ||
      colorFamily != null ||
      patternPrimary != null ||
      availability != null;

  int get activeCount => [
    materialKey,
    colorFamily,
    patternPrimary,
    availability,
  ].where((value) => value != null).length;

  _StoneFilters withMaterialKey(String? value) {
    return _StoneFilters(
      materialKey: _normalizeFilterValue(value),
      colorFamily: colorFamily,
      patternPrimary: patternPrimary,
      availability: availability,
    );
  }

  _StoneFilters withColorFamily(String? value) {
    return _StoneFilters(
      materialKey: materialKey,
      colorFamily: _normalizeFilterValue(value),
      patternPrimary: patternPrimary,
      availability: availability,
    );
  }

  _StoneFilters withPatternPrimary(String? value) {
    return _StoneFilters(
      materialKey: materialKey,
      colorFamily: colorFamily,
      patternPrimary: _normalizeFilterValue(value),
      availability: availability,
    );
  }

  _StoneFilters withAvailability(String? value) {
    return _StoneFilters(
      materialKey: materialKey,
      colorFamily: colorFamily,
      patternPrimary: patternPrimary,
      availability: _normalizeFilterValue(value),
    );
  }

  _StoneFilters constrainTo(List<StoneListing> listings) {
    final materialKeys = listings.map((listing) => listing.materialKey).toSet();
    final colorFamilies = listings
        .map((listing) => listing.facets.colorFamily)
        .toSet();
    final patternPrimaries = listings
        .map((listing) => listing.facets.patternPrimary)
        .toSet();

    return _StoneFilters(
      materialKey: materialKeys.contains(materialKey) ? materialKey : null,
      colorFamily: colorFamilies.contains(colorFamily) ? colorFamily : null,
      patternPrimary: patternPrimaries.contains(patternPrimary)
          ? patternPrimary
          : null,
      availability: availability,
    );
  }

  List<StoneListing> apply(List<StoneListing> listings) {
    return listings
        .where((listing) {
          if (materialKey != null && listing.materialKey != materialKey) {
            return false;
          }
          if (colorFamily != null &&
              listing.facets.colorFamily != colorFamily) {
            return false;
          }
          if (patternPrimary != null &&
              listing.facets.patternPrimary != patternPrimary) {
            return false;
          }
          if (availability == _availableFilterValue && !listing.isOrderable) {
            return false;
          }
          if (availability == _unavailableFilterValue && listing.isOrderable) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}

class _StoneFilterSheet extends StatefulWidget {
  const _StoneFilterSheet({
    required this.listings,
    required this.initialFilters,
  });

  final List<StoneListing> listings;
  final _StoneFilters initialFilters;

  @override
  State<_StoneFilterSheet> createState() => _StoneFilterSheetState();
}

class _StoneFilterSheetState extends State<_StoneFilterSheet> {
  late var _draft = widget.initialFilters;

  void _update(_StoneFilters filters) => setState(() => _draft = filters);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listings = widget.listings;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.stoneFiltersTitle,
                        style: HankoTextStyles.sectionTitle,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('stone-filters-reset'),
                    onPressed: _draft.hasActive
                        ? () => _update(const _StoneFilters())
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: HankoColors.gold,
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(l10n.stoneFilterReset),
                  ),
                ],
              ),
              const SizedBox(height: HankoSpacing.xs),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StoneFilterGroup(
                        keyPrefix: 'material',
                        label: l10n.stoneFilterMaterial,
                        allLabel: l10n.stoneFilterAll,
                        selectedValue: _draft.materialKey,
                        options: _materialOptions(listings),
                        onChanged: (value) =>
                            _update(_draft.withMaterialKey(value)),
                      ),
                      const _StoneFilterDivider(),
                      _StoneFilterGroup(
                        keyPrefix: 'color',
                        label: l10n.stoneFilterColor,
                        allLabel: l10n.stoneFilterAll,
                        selectedValue: _draft.colorFamily,
                        options: _facetOptions(
                          l10n,
                          listings.map((listing) => listing.facets.colorFamily),
                        ),
                        onChanged: (value) =>
                            _update(_draft.withColorFamily(value)),
                      ),
                      const _StoneFilterDivider(),
                      _StoneFilterGroup(
                        keyPrefix: 'pattern',
                        label: l10n.stoneFilterPattern,
                        allLabel: l10n.stoneFilterAll,
                        selectedValue: _draft.patternPrimary,
                        options: _facetOptions(
                          l10n,
                          listings.map(
                            (listing) => listing.facets.patternPrimary,
                          ),
                        ),
                        onChanged: (value) =>
                            _update(_draft.withPatternPrimary(value)),
                      ),
                      const _StoneFilterDivider(),
                      _StoneFilterGroup(
                        keyPrefix: 'availability',
                        label: l10n.stoneFilterAvailability,
                        allLabel: l10n.stoneFilterAll,
                        selectedValue: _draft.availability,
                        options: [
                          _StoneFilterOption(
                            value: _availableFilterValue,
                            label: l10n.stoneAvailable,
                          ),
                          _StoneFilterOption(
                            value: _unavailableFilterValue,
                            label: l10n.stoneUnavailable,
                          ),
                        ],
                        onChanged: (value) =>
                            _update(_draft.withAvailability(value)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: HankoSpacing.md),
              HankoPrimaryButton(
                key: const Key('stone-filters-apply'),
                label: l10n.stoneFilterApply,
                icon: Icons.check,
                onPressed: () => Navigator.of(context).pop(_draft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoneFilterDivider extends StatelessWidget {
  const _StoneFilterDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: HankoSpacing.sm),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: HankoColors.surfaceBorder,
      ),
    );
  }
}

/// Slim summary of the applied filters shown above the list, so active
/// filters are visible at a glance and removable without opening the sheet.
class _StoneActiveFiltersBar extends StatelessWidget {
  const _StoneActiveFiltersBar({
    required this.listings,
    required this.filters,
    required this.onChanged,
  });

  final List<StoneListing> listings;
  final _StoneFilters filters;
  final ValueChanged<_StoneFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final materialKey = filters.materialKey;
    final colorFamily = filters.colorFamily;
    final patternPrimary = filters.patternPrimary;
    final availability = filters.availability;
    return Semantics(
      container: true,
      label: l10n.stoneFilterActiveCount(filters.activeCount),
      child: Wrap(
        spacing: HankoSpacing.xs,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (materialKey != null)
            _StoneActiveFilterChip(
              key: const Key('stone-active-filter-material'),
              label: _materialLabelForKey(listings, materialKey),
              onDeleted: () => onChanged(filters.withMaterialKey(null)),
            ),
          if (colorFamily != null)
            _StoneActiveFilterChip(
              key: const Key('stone-active-filter-color'),
              label: _facetLabel(l10n, colorFamily),
              onDeleted: () => onChanged(filters.withColorFamily(null)),
            ),
          if (patternPrimary != null)
            _StoneActiveFilterChip(
              key: const Key('stone-active-filter-pattern'),
              label: _facetLabel(l10n, patternPrimary),
              onDeleted: () => onChanged(filters.withPatternPrimary(null)),
            ),
          if (availability != null)
            _StoneActiveFilterChip(
              key: const Key('stone-active-filter-availability'),
              label: availability == _availableFilterValue
                  ? l10n.stoneAvailable
                  : l10n.stoneUnavailable,
              onDeleted: () => onChanged(filters.withAvailability(null)),
            ),
          TextButton(
            key: const Key('stone-filters-clear'),
            onPressed: () => onChanged(const _StoneFilters()),
            style: TextButton.styleFrom(
              foregroundColor: HankoColors.gold,
              minimumSize: const Size(44, 44),
            ),
            child: Text(l10n.stoneFilterReset),
          ),
        ],
      ),
    );
  }
}

class _StoneActiveFilterChip extends StatelessWidget {
  const _StoneActiveFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      labelStyle: HankoTextStyles.compactBody.copyWith(
        color: HankoColors.ink,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: HankoColors.medallion,
      side: const BorderSide(color: HankoColors.gold),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      deleteIconColor: HankoColors.ink,
      deleteButtonTooltipMessage: context.l10n.stoneFilterRemove(label),
      onDeleted: onDeleted,
    );
  }
}

List<_StoneFilterOption> _materialOptions(List<StoneListing> listings) {
  final labelsByKey = <String, String>{};
  for (final listing in listings) {
    final key = listing.materialKey.trim();
    if (key.isEmpty || labelsByKey.containsKey(key)) {
      continue;
    }
    labelsByKey[key] = _materialLabel(listing);
  }
  final options = labelsByKey.entries
      .map((entry) => _StoneFilterOption(value: entry.key, label: entry.value))
      .toList(growable: false);
  options.sort((left, right) => left.label.compareTo(right.label));
  return options;
}

List<_StoneFilterOption> _facetOptions(
  GeneratedHankoLocalizations l10n,
  Iterable<String> tokens,
) {
  final seen = <String>{};
  final options = <_StoneFilterOption>[];
  for (final token in tokens) {
    final value = token.trim();
    if (value.isEmpty || !seen.add(value)) {
      continue;
    }
    options.add(
      _StoneFilterOption(value: value, label: _facetLabel(l10n, value)),
    );
  }
  options.sort((left, right) => left.label.compareTo(right.label));
  return options;
}

String _materialLabelForKey(List<StoneListing> listings, String materialKey) {
  for (final listing in listings) {
    if (listing.materialKey == materialKey) {
      return _materialLabel(listing);
    }
  }
  return _labelFromToken(materialKey);
}

/// Localized label for a color family or primary pattern facet token. The
/// listing API returns raw tokens, so known tokens are mapped here and unknown
/// ones fall back to a title-cased token.
String _facetLabel(GeneratedHankoLocalizations l10n, String token) {
  return switch (token.trim().toLowerCase()) {
    'green' => l10n.stoneColorGreen,
    'yellow' => l10n.stoneColorYellow,
    'white' => l10n.stoneColorWhite,
    'pink' => l10n.stoneColorPink,
    'red' => l10n.stoneColorRed,
    'blue' => l10n.stoneColorBlue,
    'black' => l10n.stoneColorBlack,
    'plain' => l10n.stonePatternPlain,
    'veined' => l10n.stonePatternVeined,
    'cloud' => l10n.stonePatternCloud,
    'mottled' => l10n.stonePatternMottled,
    'banded' => l10n.stonePatternBanded,
    'speckled' => l10n.stonePatternSpeckled,
    _ => _labelFromToken(token),
  };
}

class _StoneFilterGroup extends StatelessWidget {
  const _StoneFilterGroup({
    required this.keyPrefix,
    required this.label,
    required this.allLabel,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final String allLabel;
  final String? selectedValue;
  final List<_StoneFilterOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: HankoTextStyles.compactBody),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StoneChoiceChip(
              key: Key('stone-filter-$keyPrefix-all'),
              label: allLabel,
              selected: selectedValue == null,
              onSelected: () => onChanged(null),
            ),
            for (final option in options)
              _StoneChoiceChip(
                key: Key(
                  'stone-filter-$keyPrefix-${_filterKeyToken(option.value)}',
                ),
                label: option.label,
                selected: selectedValue == option.value,
                onSelected: () => onChanged(option.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _StoneChoiceChip extends StatelessWidget {
  const _StoneChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      selected: selected,
      showCheckmark: false,
      avatar: selected
          ? const Icon(Icons.check, size: 16, color: HankoColors.red)
          : null,
      selectedColor: HankoColors.medallion,
      backgroundColor: HankoColors.surface,
      side: BorderSide(
        color: selected ? HankoColors.gold : HankoColors.surfaceBorder,
      ),
      labelStyle: HankoTextStyles.compactBody.copyWith(
        color: selected ? HankoColors.ink : HankoColors.body,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HankoRadii.sm),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _StoneFilterOption {
  const _StoneFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

const _availableFilterValue = 'available';
const _unavailableFilterValue = 'unavailable';

String? _normalizeFilterValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _materialLabel(StoneListing listing) {
  final label = listing.materialLabel.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return _labelFromToken(listing.materialKey);
}

String _filterKeyToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
}

/// Compact horizontal listing card: photo, name, price with availability and
/// a single secondary line for material and size. The whole card opens the
/// stone detail; selecting the stone for the order is one compact secondary
/// control.
class _StoneListingCard extends StatelessWidget {
  const _StoneListingCard({
    required this.listing,
    required this.onOpenStoneDetail,
    required this.isSelectedForOrder,
    required this.onSelectStone,
  });

  final StoneListing listing;
  final ValueChanged<StoneListing>? onOpenStoneDetail;
  final bool isSelectedForOrder;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onOpen = onOpenStoneDetail;
    // Material and size are the facts the photo cannot show. Colour and
    // pattern are visible in the photo and offered as filters, and leaving
    // them out keeps this line to one row so three cards fit on a phone.
    final facetLine = [
      _materialLabel(listing),
      listing.sizeLabel.trim(),
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    final card = HankoSurfaceCard(
      radius: HankoRadii.md,
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          container: true,
          button: onOpen != null,
          selected: isSelectedForOrder,
          hint: onOpen == null ? null : l10n.viewStoneDetails,
          child: InkWell(
            key: const Key('stone-card-open'),
            onTap: onOpen == null ? null : () => onOpen(listing),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 6, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final photoSize = (constraints.maxWidth * 0.3).clamp(
                    84.0,
                    116.0,
                  );
                  return Row(
                    children: [
                      _StoneListingImage(
                        listing: listing,
                        size: photoSize,
                        isSelectedForOrder: isSelectedForOrder,
                      ),
                      const SizedBox(width: HankoSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: HankoTextStyles.cardTitle.copyWith(
                                fontSize: 18,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Price and availability share a line and wrap as
                            // short text, so a long label never adds a whole
                            // button-height row to the card.
                            Wrap(
                              spacing: HankoSpacing.sm,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _formatMoney(listing.price),
                                  style: HankoTextStyles.label.copyWith(
                                    fontSize: 18,
                                    height: 1.2,
                                  ),
                                ),
                                _StoneAvailabilityStatus(listing: listing),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              facetLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: HankoTextStyles.compactBody.copyWith(
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _StoneSelectControl(
                              listing: listing,
                              isSelectedForOrder: isSelectedForOrder,
                              onSelectStone: onSelectStone,
                            ),
                          ],
                        ),
                      ),
                      if (onOpen != null)
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            color: HankoColors.gold,
                            size: 24,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Always wrapped so selecting a stone only toggles the border instead of
    // remounting the card (and its photo).
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HankoRadii.md),
        border: isSelectedForOrder
            ? Border.all(color: HankoColors.gold, width: 1.6)
            : null,
      ),
      child: card,
    );
  }
}

class _StoneSelectControl extends StatelessWidget {
  const _StoneSelectControl({
    required this.listing,
    required this.isSelectedForOrder,
    required this.onSelectStone,
  });

  final StoneListing listing;
  final bool isSelectedForOrder;
  final ValueChanged<StoneListing>? onSelectStone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isSelectedForOrder) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: HankoColors.red, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.stoneSelectedForOrderAction,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HankoTextStyles.label.copyWith(color: HankoColors.red),
              ),
            ),
          ],
        ),
      );
    }

    final canSelect = listing.isOrderable && onSelectStone != null;
    return OutlinedButton.icon(
      key: const Key('stone-card-select'),
      onPressed: canSelect
          ? () async {
              final confirmed = await confirmStoneSelection(context, listing);
              if (confirmed) {
                onSelectStone?.call(listing);
              }
            }
          : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: HankoColors.red,
        disabledForegroundColor: HankoColors.body,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: canSelect ? HankoColors.red : HankoColors.surfaceBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HankoRadii.sm),
        ),
      ),
      icon: const Icon(Icons.add, size: 16),
      label: Text(
        l10n.selectStone,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        // No explicit color so the button's enabled/disabled foreground
        // applies.
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

class _StoneListingImage extends StatelessWidget {
  const _StoneListingImage({
    required this.listing,
    required this.size,
    required this.isSelectedForOrder,
  });

  final StoneListing listing;
  final double size;
  final bool isSelectedForOrder;

  @override
  Widget build(BuildContext context) {
    final primaryPhoto = _primaryPhoto(listing.photos);
    final fallback = _StoneImageFallback(title: listing.title);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
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
          if (isSelectedForOrder)
            const PositionedDirectional(
              top: 6,
              start: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HankoColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: HankoColors.red,
                  size: 22,
                ),
              ),
            ),
        ],
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
          size: 36,
          semanticLabel: title,
        ),
      ),
    );
  }
}

class _StoneAvailabilityStatus extends StatelessWidget {
  const _StoneAvailabilityStatus({required this.listing});

  final StoneListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAvailable = listing.isOrderable;
    final color = isAvailable ? HankoColors.gold : HankoColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isAvailable ? l10n.stoneAvailable : l10n.stoneUnavailable,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HankoTextStyles.compactBody.copyWith(
              color: isAvailable ? HankoColors.body : HankoColors.error,
              height: 1.3,
            ),
          ),
        ),
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
