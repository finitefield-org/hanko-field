import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/orders/application/order_details_provider.dart';
import 'package:app/features/orders/application/order_shipments_provider.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  int _selectedShipmentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final shipmentsAsync = ref.watch(orderShipmentsProvider(widget.orderId));
    final orderNumber = orderAsync.maybeWhen(
      data: (order) => order.orderNumber,
      orElse: () => widget.orderId,
    );

    final shipments = shipmentsAsync.asData?.value ?? const <OrderShipment>[];
    _ensureSelectedIndex(shipments.length);
    final safeIndex = shipments.isEmpty
        ? 0
        : _selectedShipmentIndex < 0
        ? 0
        : (_selectedShipmentIndex >= shipments.length
              ? shipments.length - 1
              : _selectedShipmentIndex);
    final selectedShipment = shipments.isEmpty ? null : shipments[safeIndex];

    OrderShipmentEvent? latestEventWithLocation;
    if (selectedShipment != null) {
      for (final event in selectedShipment.events.reversed) {
        if ((event.location ?? '').isNotEmpty) {
          latestEventWithLocation = event;
          break;
        }
      }
      latestEventWithLocation ??= selectedShipment.events.isNotEmpty
          ? selectedShipment.events.last
          : null;
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.orderTrackingAppBarTitle(orderNumber)),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.orderTrackingActionViewMap,
            onPressed: (latestEventWithLocation?.location ?? '').isNotEmpty
                ? () => _handleMapTap(context, latestEventWithLocation!, l10n)
                : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        displacement: 72,
        onRefresh: () async {
          await Future.wait([
            ref.refresh(orderShipmentsProvider(widget.orderId).future),
            ref.refresh(orderDetailsProvider(widget.orderId).future),
          ]);
        },
        child: shipmentsAsync.when(
          data: (items) =>
              _buildContent(context, l10n, items, orderAsync.asData?.value),
          loading: () => const _TrackingLoadingView(),
          error: (error, stackTrace) => _TrackingErrorView(
            message: l10n.orderTrackingLoadError,
            onRetry: () {
              ref.invalidate(orderShipmentsProvider(widget.orderId));
            },
            retryLabel: l10n.orderDetailsRetryLabel,
          ),
        ),
      ),
    );
  }

  void _ensureSelectedIndex(int length) {
    if (length <= 0) {
      if (_selectedShipmentIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedShipmentIndex = 0;
          });
        });
      }
      return;
    }
    final safeIndex = _selectedShipmentIndex < 0
        ? 0
        : (_selectedShipmentIndex >= length
              ? length - 1
              : _selectedShipmentIndex);
    if (safeIndex != _selectedShipmentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedShipmentIndex = safeIndex;
        });
      });
    }
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    List<OrderShipment> shipments,
    Order? order,
  ) {
    if (shipments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppTokens.spaceXXL),
          AppEmptyState(
            title: l10n.orderTrackingUnavailableTitle,
            message: l10n.orderTrackingUnavailableMessage,
            icon: const Icon(Icons.local_shipping_outlined),
            primaryAction: AppButton(
              label: l10n.orderTrackingContactSupport,
              variant: AppButtonVariant.primary,
              onPressed: () =>
                  _showSnackBar(context, l10n.orderTrackingSupportPending),
            ),
          ),
        ],
      );
    }

    final safeIndex = _selectedShipmentIndex < 0
        ? 0
        : (_selectedShipmentIndex >= shipments.length
              ? shipments.length - 1
              : _selectedShipmentIndex);
    final selectedShipment = shipments[safeIndex];
    final events = selectedShipment.events;

    final timelineTitle = l10n.orderTrackingTimelineTitle(events.length);

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (shipments.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceL),
            child: _ShipmentSelector(
              shipments: shipments,
              selectedIndex: _selectedShipmentIndex,
              onChanged: (index) {
                setState(() {
                  _selectedShipmentIndex = index;
                });
              },
            ),
          ),
        _TrackingStatusCard(shipment: selectedShipment, l10n: l10n),
        const SizedBox(height: AppTokens.spaceL),
        _TrackingActions(
          shipment: selectedShipment,
          l10n: l10n,
          onContactCarrier: () =>
              _handleContactCarrier(context, selectedShipment, l10n),
          onCopyTracking: selectedShipment.trackingNumber == null
              ? null
              : () => _handleCopyTracking(
                  context,
                  selectedShipment.trackingNumber!,
                  l10n,
                ),
        ),
        const SizedBox(height: AppTokens.spaceXL),
        Text(
          timelineTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTokens.spaceM),
        _ShipmentTimeline(events: events, l10n: l10n),
        if (order != null) ...[
          const SizedBox(height: AppTokens.spaceXL),
          _OrderSummaryFooter(order: order, l10n: l10n),
        ],
        const SizedBox(height: AppTokens.spaceXXL),
      ],
    );
  }

  void _handleContactCarrier(
    BuildContext context,
    OrderShipment shipment,
    AppLocalizations l10n,
  ) {
    _showSnackBar(
      context,
      l10n.orderTrackingContactCarrierPending(
        _carrierLabel(l10n, shipment.carrier),
      ),
    );
  }

  void _handleCopyTracking(
    BuildContext context,
    String trackingNumber,
    AppLocalizations l10n,
  ) async {
    final message = l10n.orderTrackingCopied(trackingNumber);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: trackingNumber));
    if (!mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleMapTap(
    BuildContext context,
    OrderShipmentEvent event,
    AppLocalizations l10n,
  ) {
    final location = event.location;
    final message = (location != null && location.isNotEmpty)
        ? l10n.orderTrackingMapPlaceholder(location)
        : l10n.orderTrackingMapPlaceholderGeneric;
    _showSnackBar(context, message);
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ShipmentSelector extends StatelessWidget {
  const _ShipmentSelector({
    required this.shipments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<OrderShipment> shipments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceL,
        vertical: AppTokens.spaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.orderTrackingShipmentSelectorLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTokens.spaceS),
          DropdownButtonFormField<int>(
            initialValue:
                (selectedIndex >= 0 && selectedIndex < shipments.length)
                ? selectedIndex
                : 0,
            borderRadius: AppTokens.radiusL,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < shipments.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    l10n.orderTrackingShipmentSelectorOption(
                      i + 1,
                      _carrierLabel(l10n, shipments[i].carrier),
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _TrackingStatusCard extends StatelessWidget {
  const _TrackingStatusCard({required this.shipment, required this.l10n});

  final OrderShipment shipment;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = _statusLabel(l10n, shipment.status);
    final statusIcon = _statusIcon(shipment.status);
    final latestEvent = shipment.events.isNotEmpty
        ? shipment.events.last
        : null;
    final latestTimestamp = latestEvent?.timestamp;
    final formattedTimestamp = latestTimestamp != null
        ? DateFormat.yMMMd().add_Hm().format(latestTimestamp)
        : null;
    final location = latestEvent?.location;
    final eta = shipment.eta;

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(right: AppTokens.spaceM),
                padding: const EdgeInsets.all(AppTokens.spaceS),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppTokens.radiusM,
                ),
                child: Icon(statusIcon, color: scheme.primary, size: 28),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (formattedTimestamp != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Text(
                          l10n.orderTrackingUpdatedAt(formattedTimestamp),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (location != null && location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Text(
                          l10n.orderTrackingLatestLocation(location),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (eta != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                        child: Text(
                          l10n.orderTrackingEta(DateFormat.yMMMd().format(eta)),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          Wrap(
            spacing: AppTokens.spaceS,
            runSpacing: AppTokens.spaceS,
            children: [
              Chip(
                avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(_carrierLabel(l10n, shipment.carrier)),
              ),
              if (shipment.service != null && shipment.service!.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.settings_ethernet_rounded, size: 18),
                  label: Text(shipment.service!),
                ),
              if (shipment.trackingNumber != null &&
                  shipment.trackingNumber!.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.tag_outlined, size: 18),
                  label: Text(
                    l10n.orderTrackingTrackingIdLabel(shipment.trackingNumber!),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingActions extends StatelessWidget {
  const _TrackingActions({
    required this.shipment,
    required this.l10n,
    required this.onContactCarrier,
    this.onCopyTracking,
  });

  final OrderShipment shipment;
  final AppLocalizations l10n;
  final VoidCallback onContactCarrier;
  final VoidCallback? onCopyTracking;

  @override
  Widget build(BuildContext context) {
    final hasTrackingId =
        shipment.trackingNumber != null && shipment.trackingNumber!.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: onContactCarrier,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded),
                const SizedBox(width: AppTokens.spaceS),
                Flexible(
                  child: Text(
                    l10n.orderTrackingContactCarrierButton,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTokens.spaceM),
        TextButton.icon(
          onPressed: hasTrackingId ? onCopyTracking : null,
          icon: const Icon(Icons.copy_all_outlined),
          label: Text(l10n.orderTrackingCopyTrackingIdButton),
        ),
      ],
    );
  }
}

class _ShipmentTimeline extends StatelessWidget {
  const _ShipmentTimeline({required this.events, required this.l10n});

  final List<OrderShipmentEvent> events;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return AppCard(
        variant: AppCardVariant.outlined,
        child: AppEmptyState(
          title: l10n.orderTrackingNoEventsTitle,
          message: l10n.orderTrackingNoEventsMessage,
          icon: const Icon(Icons.hourglass_empty_rounded),
        ),
      );
    }

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceM),
      child: Column(
        children: [
          for (var index = 0; index < events.length; index++) ...[
            if (index != 0)
              const Divider(
                height: AppTokens.spaceL,
                indent: AppTokens.spaceL,
                endIndent: AppTokens.spaceL,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceS,
              ),
              child: _TrackingEventTile(
                event: events[index],
                isActive: index == events.length - 1,
                isFirst: index == 0,
                isLast: index == events.length - 1,
                l10n: l10n,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingEventTile extends StatelessWidget {
  const _TrackingEventTile({
    required this.event,
    required this.isActive,
    required this.isFirst,
    required this.isLast,
    required this.l10n,
  });

  final OrderShipmentEvent event;
  final bool isActive;
  final bool isFirst;
  final bool isLast;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eventLabel = _eventLabel(l10n, event.code);
    final icon = _eventIcon(event.code);
    final timestamp = DateFormat.yMMMd().add_Hm().format(event.timestamp);
    final location = event.location;
    final note = event.note;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  )
                else
                  const SizedBox(height: AppTokens.spaceS),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isActive
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  )
                else
                  const SizedBox(height: AppTokens.spaceS),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        eventLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: isActive ? FontWeight.w600 : null,
                            ),
                      ),
                    ),
                    Icon(
                      icon,
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceXS),
                Text(
                  timestamp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (location != null && location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                    child: Text(
                      location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceXS),
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryFooter extends StatelessWidget {
  const _OrderSummaryFooter({required this.order, required this.l10n});

  final Order order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.orderTrackingOrderSummaryTitle(order.orderNumber),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.orderTrackingOrderStatus(
              _orderStatusLabel(l10n, order.status),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingLoadingView extends StatelessWidget {
  const _TrackingLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        AppSkeletonBlock(height: 120),
        SizedBox(height: AppTokens.spaceL),
        AppSkeletonBlock(height: 44),
        SizedBox(height: AppTokens.spaceXL),
        AppListSkeleton(items: 3),
      ],
    );
  }
}

class _TrackingErrorView extends StatelessWidget {
  const _TrackingErrorView({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppTokens.spaceXXL),
        AppEmptyState(
          title: message,
          icon: const Icon(Icons.error_outline),
          primaryAction: AppButton(
            label: retryLabel,
            variant: AppButtonVariant.primary,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

String _carrierLabel(AppLocalizations l10n, OrderShipmentCarrier carrier) {
  return switch (carrier) {
    OrderShipmentCarrier.jppost => l10n.orderTrackingCarrierJapanPost,
    OrderShipmentCarrier.yamato => l10n.orderTrackingCarrierYamato,
    OrderShipmentCarrier.sagawa => l10n.orderTrackingCarrierSagawa,
    OrderShipmentCarrier.dhl => l10n.orderTrackingCarrierDhl,
    OrderShipmentCarrier.ups => l10n.orderTrackingCarrierUps,
    OrderShipmentCarrier.fedex => l10n.orderTrackingCarrierFedex,
    OrderShipmentCarrier.other => l10n.orderTrackingCarrierOther,
  };
}

String _statusLabel(AppLocalizations l10n, OrderShipmentStatus status) {
  return switch (status) {
    OrderShipmentStatus.labelCreated => l10n.orderTrackingStatusLabelCreated,
    OrderShipmentStatus.inTransit => l10n.orderTrackingStatusInTransit,
    OrderShipmentStatus.outForDelivery =>
      l10n.orderTrackingStatusOutForDelivery,
    OrderShipmentStatus.delivered => l10n.orderTrackingStatusDelivered,
    OrderShipmentStatus.exception => l10n.orderTrackingStatusException,
    OrderShipmentStatus.cancelled => l10n.orderTrackingStatusCancelled,
  };
}

IconData _statusIcon(OrderShipmentStatus status) {
  return switch (status) {
    OrderShipmentStatus.labelCreated => Icons.receipt_long_outlined,
    OrderShipmentStatus.inTransit => Icons.delivery_dining_outlined,
    OrderShipmentStatus.outForDelivery => Icons.directions_run_outlined,
    OrderShipmentStatus.delivered => Icons.home_work_outlined,
    OrderShipmentStatus.exception => Icons.warning_rounded,
    OrderShipmentStatus.cancelled => Icons.cancel_outlined,
  };
}

String _eventLabel(AppLocalizations l10n, OrderShipmentEventCode code) {
  return switch (code) {
    OrderShipmentEventCode.labelCreated => l10n.orderTrackingEventLabelCreated,
    OrderShipmentEventCode.pickedUp => l10n.orderTrackingEventPickedUp,
    OrderShipmentEventCode.inTransit => l10n.orderTrackingEventInTransit,
    OrderShipmentEventCode.arrivedHub => l10n.orderTrackingEventArrivedHub,
    OrderShipmentEventCode.customsClearance =>
      l10n.orderTrackingEventCustomsClearance,
    OrderShipmentEventCode.outForDelivery =>
      l10n.orderTrackingEventOutForDelivery,
    OrderShipmentEventCode.delivered => l10n.orderTrackingEventDelivered,
    OrderShipmentEventCode.exception => l10n.orderTrackingEventException,
    OrderShipmentEventCode.returnToSender =>
      l10n.orderTrackingEventReturnToSender,
  };
}

IconData _eventIcon(OrderShipmentEventCode code) {
  return switch (code) {
    OrderShipmentEventCode.labelCreated => Icons.description_outlined,
    OrderShipmentEventCode.pickedUp => Icons.inventory_2_outlined,
    OrderShipmentEventCode.inTransit => Icons.alt_route_outlined,
    OrderShipmentEventCode.arrivedHub => Icons.account_tree_outlined,
    OrderShipmentEventCode.customsClearance => Icons.task_alt_outlined,
    OrderShipmentEventCode.outForDelivery => Icons.directions_bike_outlined,
    OrderShipmentEventCode.delivered => Icons.home_outlined,
    OrderShipmentEventCode.exception => Icons.report_gmailerrorred_outlined,
    OrderShipmentEventCode.returnToSender => Icons.u_turn_left_outlined,
  };
}

String _orderStatusLabel(AppLocalizations l10n, OrderStatus status) {
  return switch (status) {
    OrderStatus.draft => l10n.orderStatusCanceled,
    OrderStatus.pendingPayment => l10n.orderStatusPendingPayment,
    OrderStatus.paid => l10n.orderStatusPaid,
    OrderStatus.inProduction => l10n.orderStatusInProduction,
    OrderStatus.readyToShip => l10n.orderStatusReadyToShip,
    OrderStatus.shipped => l10n.orderStatusShipped,
    OrderStatus.delivered => l10n.orderStatusDelivered,
    OrderStatus.canceled => l10n.orderStatusCanceled,
  };
}
