// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/orders/data/models/order_models.dart';
import 'package:app/features/orders/data/shipment_carrier_links.dart';
import 'package:app/features/orders/view_model/order_tracking_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  Timer? _pollTimer;
  final _links = const ShipmentCarrierLinks();

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final vm = OrderTrackingViewModel(orderId: widget.orderId);
      final current = ref.container.read(vm).valueOrNull;
      final shipment = current?.shipments.firstOrNull;
      final done =
          shipment == null ||
          shipment.status == ShipmentStatus.delivered ||
          shipment.status == ShipmentStatus.cancelled;
      if (done) return;
      unawaited(ref.invoke(vm.refresh()));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final vm = OrderTrackingViewModel(orderId: widget.orderId);
    final state = ref.watch(vm);
    final refreshState = ref.watch(vm.refreshMut);
    final current = state.valueOrNull;

    final latestLocation = current?.shipments
        .expand((shipment) => shipment.events)
        .sorted((a, b) => b.timestamp.compareTo(a.timestamp))
        .firstWhereOrNull((event) => event.location?.isNotEmpty == true)
        ?.location;

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.container.read(navigationControllerProvider).pop(),
        ),
        title: Text(prefersEnglish ? 'Tracking' : '配送トラッキング'),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Map' : '地図',
            icon: const Icon(Icons.map_outlined),
            onPressed: latestLocation == null
                ? null
                : () => unawaited(_openMap(latestLocation, prefersEnglish)),
          ),
          IconButton(
            tooltip: prefersEnglish ? 'Refresh' : '更新',
            icon: const Icon(Icons.refresh),
            onPressed: refreshState is PendingMutationState
                ? null
                : () => unawaited(_refresh(vm)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          displacement: tokens.spacing.xl,
          edgeOffset: tokens.spacing.md,
          onRefresh: () => _refresh(vm),
          child: _buildBody(
            context: context,
            state: state,
            tokens: tokens,
            prefersEnglish: prefersEnglish,
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(OrderTrackingViewModel vm) => ref.invoke(vm.refresh());

  Widget _buildBody({
    required BuildContext context,
    required AsyncValue<OrderTrackingState> state,
    required DesignTokens tokens,
    required bool prefersEnglish,
  }) {
    final loading = state is AsyncLoading<OrderTrackingState>;
    final error = state is AsyncError<OrderTrackingState>;
    final data = state.valueOrNull;

    if (loading && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 6, itemHeight: 88),
      );
    }

    if (error && data == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load' : '読み込みに失敗しました',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () => unawaited(
            _refresh(OrderTrackingViewModel(orderId: widget.orderId)),
          ),
        ),
      );
    }

    final current = data;
    if (current == null) return const SizedBox.shrink();

    if (current.shipments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(tokens.spacing.xl),
        children: [
          AppEmptyState(
            title: prefersEnglish ? 'Tracking unavailable' : '追跡情報がありません',
            message: prefersEnglish
                ? 'Tracking will appear here once a carrier label is created.'
                : '配送ラベルが作成されると、ここに追跡情報が表示されます。',
            icon: Icons.local_shipping_outlined,
            actionLabel: prefersEnglish ? 'Contact support' : '問い合わせ',
            onAction: () => _contactSupport(),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      itemCount: current.shipments.length,
      itemBuilder: (context, index) {
        final shipment = current.shipments[index];
        return Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.lg),
          child: _ShipmentSection(
            shipment: shipment,
            prefersEnglish: prefersEnglish,
            links: _links,
            onContactSupport: _contactSupport,
          ),
        );
      },
    );
  }

  Future<void> _openMap(String location, bool prefersEnglish) async {
    final uri = _links.mapsSearchUri(location);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prefersEnglish ? 'Could not open map' : '地図を開けませんでした'),
        ),
      );
    }
  }

  void _contactSupport() {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push(AppRoutePaths.supportContact),
    );
  }
}

class _ShipmentSection extends StatelessWidget {
  const _ShipmentSection({
    required this.shipment,
    required this.prefersEnglish,
    required this.links,
    required this.onContactSupport,
  });

  final OrderShipment shipment;
  final bool prefersEnglish;
  final ShipmentCarrierLinks links;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final events = List<ShipmentEvent>.of(shipment.events)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final latest = events.firstOrNull;
    final tracking = shipment.trackingNumber;
    final trackingUri = tracking == null
        ? null
        : links.trackingUri(carrier: shipment.carrier, tracking: tracking);
    final supportUri = links.supportUri(shipment.carrier) ?? trackingUri;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _shipmentStatusLabel(
                        shipment.status,
                        prefersEnglish: prefersEnglish,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ActionChip(
                    label: Text(_carrierLabel(shipment.carrier)),
                    avatar: const Icon(Icons.local_shipping_outlined),
                    onPressed: trackingUri == null
                        ? null
                        : () => unawaited(
                            launchUrl(
                              trackingUri,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                  ),
                ],
              ),
              if (latest != null) ...[
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Latest: ${_eventLabel(latest.code, prefersEnglish: prefersEnglish)}'
                      : '最新：${_eventLabel(latest.code, prefersEnglish: prefersEnglish)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatDateTime(latest.timestamp),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (latest.location != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    prefersEnglish
                        ? 'Location: ${latest.location}'
                        : '場所：${latest.location}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
              if (shipment.eta != null) ...[
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Estimated delivery: ${_formatDateTime(shipment.eta!)}'
                      : '配達予定：${_formatDateTime(shipment.eta!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              SizedBox(height: tokens.spacing.lg),
              Wrap(
                spacing: tokens.spacing.sm,
                runSpacing: tokens.spacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: supportUri == null
                        ? onContactSupport
                        : () => unawaited(
                            launchUrl(
                              supportUri,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text(
                      prefersEnglish ? 'Contact carrier' : '配送会社に問い合わせ',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: tracking == null
                        ? null
                        : () => unawaited(_copyTracking(context, tracking)),
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(prefersEnglish ? 'Copy ID' : '追跡番号をコピー'),
                  ),
                ],
              ),
              if (tracking == null) ...[
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? 'Tracking number not available yet.'
                      : '追跡番号がまだ発行されていません。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Text(
          prefersEnglish ? 'Events' : '配送履歴',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing.sm),
        if (events.isEmpty)
          AppEmptyState(
            title: prefersEnglish ? 'No events yet' : 'まだ履歴がありません',
            message: prefersEnglish
                ? 'Carrier events will appear here when available.'
                : '配送会社からの更新があると、ここに表示されます。',
            icon: Icons.schedule_outlined,
            actionLabel: prefersEnglish ? 'Contact support' : '問い合わせ',
            onAction: onContactSupport,
          )
        else
          ...events.mapIndexed((index, event) {
            final highlighted = index == 0;
            return Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.sm),
              child: _ShipmentEventTile(
                event: event,
                highlighted: highlighted,
                prefersEnglish: prefersEnglish,
              ),
            );
          }),
      ],
    );
  }

  Future<void> _copyTracking(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(prefersEnglish ? 'Copied' : 'コピーしました')),
    );
  }
}

class _ShipmentEventTile extends StatelessWidget {
  const _ShipmentEventTile({
    required this.event,
    required this.highlighted,
    required this.prefersEnglish,
  });

  final ShipmentEvent event;
  final bool highlighted;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final bg = highlighted
        ? Theme.of(context).colorScheme.primaryContainer
        : tokens.colors.surface;

    return AppCard(
      backgroundColor: bg,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.lg,
        vertical: tokens.spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: tokens.spacing.md),
            child: Icon(
              _eventIcon(event.code),
              color: highlighted
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eventLabel(event.code, prefersEnglish: prefersEnglish),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatDateTime(event.timestamp),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (event.location != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    event.location!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (event.note != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    event.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            highlighted ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: highlighted
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

String _carrierLabel(ShipmentCarrier carrier) => switch (carrier) {
  ShipmentCarrier.jppost => 'JP Post',
  ShipmentCarrier.yamato => 'Yamato',
  ShipmentCarrier.sagawa => 'Sagawa',
  ShipmentCarrier.dhl => 'DHL',
  ShipmentCarrier.ups => 'UPS',
  ShipmentCarrier.fedex => 'FedEx',
  ShipmentCarrier.other => 'Carrier',
};

String _shipmentStatusLabel(
  ShipmentStatus status, {
  required bool prefersEnglish,
}) {
  return switch (status) {
    ShipmentStatus.labelCreated => prefersEnglish ? 'Label created' : 'ラベル作成',
    ShipmentStatus.inTransit => prefersEnglish ? 'In transit' : '輸送中',
    ShipmentStatus.outForDelivery =>
      prefersEnglish ? 'Out for delivery' : '配達中',
    ShipmentStatus.delivered => prefersEnglish ? 'Delivered' : '配達済み',
    ShipmentStatus.exception => prefersEnglish ? 'Exception' : '例外',
    ShipmentStatus.cancelled => prefersEnglish ? 'Cancelled' : 'キャンセル',
  };
}

String _eventLabel(ShipmentEventCode code, {required bool prefersEnglish}) {
  return switch (code) {
    ShipmentEventCode.labelCreated =>
      prefersEnglish ? 'Label created' : 'ラベル作成',
    ShipmentEventCode.pickedUp => prefersEnglish ? 'Picked up' : '集荷済み',
    ShipmentEventCode.inTransit => prefersEnglish ? 'In transit' : '輸送中',
    ShipmentEventCode.arrivedHub => prefersEnglish ? 'Arrived at hub' : '拠点到着',
    ShipmentEventCode.customsClearance =>
      prefersEnglish ? 'Customs clearance' : '通関完了',
    ShipmentEventCode.outForDelivery =>
      prefersEnglish ? 'Out for delivery' : '配達中',
    ShipmentEventCode.delivered => prefersEnglish ? 'Delivered' : '配達済み',
    ShipmentEventCode.exception => prefersEnglish ? 'Exception' : '例外',
    ShipmentEventCode.returnToSender =>
      prefersEnglish ? 'Return to sender' : '差出人へ返送',
  };
}

IconData _eventIcon(ShipmentEventCode code) => switch (code) {
  ShipmentEventCode.labelCreated => Icons.local_offer_outlined,
  ShipmentEventCode.pickedUp => Icons.inventory_2_outlined,
  ShipmentEventCode.inTransit => Icons.local_shipping_outlined,
  ShipmentEventCode.arrivedHub => Icons.hub_outlined,
  ShipmentEventCode.customsClearance => Icons.verified_outlined,
  ShipmentEventCode.outForDelivery => Icons.route_outlined,
  ShipmentEventCode.delivered => Icons.home_outlined,
  ShipmentEventCode.exception => Icons.error_outline,
  ShipmentEventCode.returnToSender => Icons.keyboard_return_outlined,
};

String _formatDateTime(DateTime dateTime) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} ${two(dateTime.hour)}:${two(dateTime.minute)}';
}
