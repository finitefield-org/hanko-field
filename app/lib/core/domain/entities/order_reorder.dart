import 'package:app/core/domain/entities/order.dart';
import 'package:flutter/foundation.dart';

/// Availability state for a reorder line item.
enum OrderReorderLineAvailability { available, lowStock, unavailable }

@immutable
class OrderReorderLine {
  const OrderReorderLine({
    required this.id,
    required this.item,
    this.availability = OrderReorderLineAvailability.available,
    this.currentUnitPrice,
    this.note,
  });

  /// Stable identifier for tracking the line within reorder flows.
  final String id;

  /// Original order line item that can be cloned into the cart.
  final OrderLineItem item;

  /// Availability flag resolved against current inventory.
  final OrderReorderLineAvailability availability;

  /// Updated unit price if pricing changed since the original order.
  final int? currentUnitPrice;

  /// Optional note describing availability or pricing adjustments.
  final String? note;

  /// Whether the line can be cloned into the cart.
  bool get isAvailable =>
      availability != OrderReorderLineAvailability.unavailable;

  /// True if a new price applies to this line.
  bool get hasPriceChange =>
      currentUnitPrice != null && currentUnitPrice != item.unitPrice;

  /// Unit price to use when rebuilding the cart.
  int get effectiveUnitPrice => currentUnitPrice ?? item.unitPrice;

  /// Total line amount at the effective price.
  int get effectiveTotal => effectiveUnitPrice * item.quantity;

  OrderReorderLine copyWith({
    String? id,
    OrderLineItem? item,
    OrderReorderLineAvailability? availability,
    int? currentUnitPrice,
    Object? note = _sentinel,
  }) {
    return OrderReorderLine(
      id: id ?? this.id,
      item: item ?? this.item,
      availability: availability ?? this.availability,
      currentUnitPrice: currentUnitPrice ?? this.currentUnitPrice,
      note: identical(note, _sentinel) ? this.note : note as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is OrderReorderLine &&
            other.id == id &&
            other.item == item &&
            other.availability == availability &&
            other.currentUnitPrice == currentUnitPrice &&
            other.note == note;
  }

  @override
  int get hashCode =>
      Object.hash(id, item, availability, currentUnitPrice, note);
}

@immutable
class OrderReorderPreview {
  const OrderReorderPreview({
    required this.order,
    required this.lines,
    this.generatedAt,
  });

  /// Source order used for the reorder flow.
  final Order order;

  /// Snapshot of line availability and pricing updates.
  final List<OrderReorderLine> lines;

  /// Timestamp when the preview was generated.
  final DateTime? generatedAt;

  /// Lines that can be cloned without restrictions.
  Iterable<OrderReorderLine> get availableLines =>
      lines.where((line) => line.isAvailable);

  /// Lines that are currently unavailable.
  Iterable<OrderReorderLine> get unavailableLines =>
      lines.where((line) => !line.isAvailable);

  /// True if any selected items are unavailable.
  bool get hasUnavailable => unavailableLines.isNotEmpty;

  /// True if any lines have updated pricing.
  bool get hasPriceChanges =>
      lines.any((line) => line.hasPriceChange && line.isAvailable);
}

@immutable
class OrderReorderResult {
  const OrderReorderResult({
    required this.orderId,
    required this.cartId,
    required this.addedLineIds,
    required this.skippedLineIds,
    required this.priceAdjustedLineIds,
    required this.createdAt,
    this.message,
  });

  /// ID of the source order.
  final String orderId;

  /// Cart ID (or reference) returned by the backend after cloning.
  final String cartId;

  /// Lines cloned into the cart.
  final List<String> addedLineIds;

  /// Lines that were skipped because they were unavailable.
  final List<String> skippedLineIds;

  /// Lines that required pricing adjustments.
  final List<String> priceAdjustedLineIds;

  /// Timestamp when the new cart draft was generated.
  final DateTime createdAt;

  /// Optional message returned by the backend.
  final String? message;

  /// Count of successfully cloned lines.
  int get addedCount => addedLineIds.length;

  /// Count of skipped lines.
  int get skippedCount => skippedLineIds.length;

  /// True if any pricing adjustments were applied.
  bool get hasPriceAdjustments => priceAdjustedLineIds.isNotEmpty;
}

const Object _sentinel = Object();
