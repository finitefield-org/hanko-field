import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_review_controller.dart';
import 'package:app/features/cart/application/order_completion_notification_service.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

final checkoutCompletionReceiptProvider = Provider<CheckoutOrderReceipt?>(
  (ref) => ref.watch(checkoutReviewControllerProvider).lastReceipt,
  name: 'checkoutCompletionReceiptProvider',
);

class CheckoutCompleteScreen extends ConsumerStatefulWidget {
  const CheckoutCompleteScreen({super.key, this.orderId});

  final String? orderId;

  @override
  ConsumerState<CheckoutCompleteScreen> createState() =>
      _CheckoutCompleteScreenState();
}

class _CheckoutCompleteScreenState
    extends ConsumerState<CheckoutCompleteScreen> {
  String? _notifiedOrderId;
  bool _lastIsInternational = false;

  @override
  void initState() {
    super.initState();
    final initialReceipt = ref.read(checkoutCompletionReceiptProvider);
    if (initialReceipt != null) {
      _notifiedOrderId = initialReceipt.orderId;
      unawaited(
        ref
            .read(orderCompletionNotificationServiceProvider)
            .maybeSchedule(initialReceipt),
      );
    }
    ref.listen<CheckoutOrderReceipt?>(checkoutCompletionReceiptProvider, (
      previous,
      next,
    ) {
      if (next != null && next.orderId != _notifiedOrderId) {
        _notifiedOrderId = next.orderId;
        unawaited(
          ref
              .read(orderCompletionNotificationServiceProvider)
              .maybeSchedule(next),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final experienceAsync = ref.watch(experienceGateProvider);
    final experience = experienceAsync.value;
    final isInternational = experience?.isInternational ?? false;
    _lastIsInternational = isInternational;
    final receipt = ref.watch(checkoutCompletionReceiptProvider);
    final orderId = receipt?.orderId ?? widget.orderId ?? 'HF-00000';

    if (receipt == null) {
      return _CheckoutCompleteFallback(
        orderId: orderId,
        isInternational: isInternational,
        onViewOrders: _handleViewOrders,
        onContinueShopping: () => _selectTab(AppTab.shop),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              pinned: true,
              centerTitle: true,
              title: Text(isInternational ? 'Order complete' : '注文が完了しました'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceL,
                AppTokens.spaceXL,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _CheckoutHeroCard(receipt: receipt, experience: experience),
                  const SizedBox(height: AppTokens.spaceL),
                  _OrderSummarySection(
                    receipt: receipt,
                    experience: experience,
                  ),
                  const SizedBox(height: AppTokens.spaceL),
                  _NextStepsSection(
                    isInternational: isInternational,
                    onTrackOrder: () => _handleTrackOrder(receipt.orderId),
                    onDownloadInvoice: () => _showPlaceholderSnackbar(
                      isInternational ? 'Generating invoice…' : '請求書を準備しています…。',
                    ),
                    onRecreateDesign: _handleRecreateDesign,
                    onViewLibrary: () => _selectTab(AppTab.library),
                    onContinueShopping: () => _selectTab(AppTab.shop),
                  ),
                  const SizedBox(height: AppTokens.spaceL),
                  _ShareAndOrdersSection(
                    receipt: receipt,
                    experience: experience,
                    onShare: () => _handleShare(receipt, experience),
                    onViewOrders: _handleViewOrders,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleViewOrders() {
    _selectTab(AppTab.orders);
  }

  void _handleTrackOrder(String orderId) {
    ref
        .read(appStateProvider.notifier)
        .push(OrderDetailsRoute(orderId: orderId));
  }

  void _handleRecreateDesign() {
    final message = _lastIsInternational
        ? 'Preparing a new design draft…'
        : '新しいデザイン案を準備しています…';
    _showPlaceholderSnackbar(message);
    ref.read(appStateProvider.notifier).push(CreationStageRoute(const ['new']));
  }

  void _handleShare(CheckoutOrderReceipt receipt, ExperienceGate? experience) {
    final totalText = _formatCurrency(
      receipt.total,
      experience?.currencySymbol ?? '¥',
      experience?.currencyCode ?? receipt.currency,
      experience?.locale.toString(),
    );
    final content = experience?.isInternational ?? false
        ? 'Order ${receipt.orderId} confirmed! Total: $totalText.'
              ' Follow along from the Hanko Field app.'
        : '注文 ${receipt.orderId} の手続きが完了しました。合計金額: $totalText。'
              ' Hanko Field アプリで進捗を確認しましょう。';
    Share.share(content, subject: receipt.orderId);
  }

  void _selectTab(AppTab tab) {
    ref.read(appStateProvider.notifier).selectTab(tab);
  }

  void _showPlaceholderSnackbar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CheckoutHeroCard extends StatelessWidget {
  const _CheckoutHeroCard({required this.receipt, required this.experience});

  final CheckoutOrderReceipt receipt;
  final ExperienceGate? experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInternational = experience?.isInternational ?? false;
    final totalText = _formatCurrency(
      receipt.total,
      experience?.currencySymbol ?? '¥',
      experience?.currencyCode ?? receipt.currency,
      experience?.locale.toString(),
    );
    final deliveryText =
        receipt.estimatedDelivery ?? receipt.estimate.estimatedDelivery;
    final title = isInternational
        ? 'Thank you for your order!'
        : 'ご注文ありがとうございます！';
    final subtitle = isInternational
        ? 'Order ${receipt.orderId} is confirmed.'
        : '注文番号 ${receipt.orderId} を受け付けました。';
    final totalLabel = isInternational ? 'Total' : '合計金額';
    final deliveryLabel = isInternational ? 'Estimated delivery' : 'お届け予定';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -10,
            child: Icon(
              Icons.celebration,
              size: 120,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(subtitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTokens.spaceM),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.spaceS),
                    Text(totalLabel, style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      totalText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceS),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.spaceS),
                    Text(deliveryLabel, style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(deliveryText, style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummarySection extends StatelessWidget {
  const _OrderSummarySection({required this.receipt, required this.experience});

  final CheckoutOrderReceipt receipt;
  final ExperienceGate? experience;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInternational = experience?.isInternational ?? false;
    final lines = receipt.lines;

    final summaryTitle = isInternational ? 'Order summary' : '注文サマリー';
    final qtyLabel = isInternational ? 'Qty' : '数量';
    final itemsLabel = isInternational ? 'Items' : '商品';
    final shippingLabel = isInternational ? 'Shipping' : '配送';
    final paymentLabel = isInternational ? 'Payment' : '支払い';

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: AppTokens.radiusL,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            if (lines.isEmpty)
              Text(
                isInternational
                    ? 'Order data unavailable.'
                    : '注文情報を取得できませんでした。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (final (index, line) in lines.indexed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.title,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: AppTokens.spaceXS),
                              Text(
                                line.subtitle,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (line.optionChips.isNotEmpty) ...[
                                const SizedBox(height: AppTokens.spaceXS),
                                Wrap(
                                  spacing: AppTokens.spaceXS,
                                  runSpacing: AppTokens.spaceXS,
                                  children: line.optionChips
                                      .take(4)
                                      .map(
                                        (chip) => Chip(
                                          label: Text(chip),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceS),
                        Text(
                          '$qtyLabel: ${line.quantity}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (index != lines.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTokens.spaceM,
                        ),
                        child: Divider(height: 1),
                      ),
                  ],
                ],
              ),
            const SizedBox(height: AppTokens.spaceL),
            _SummaryRow(
              label: itemsLabel,
              value:
                  '${lines.fold<int>(0, (total, line) => total + line.quantity)}',
            ),
            if (receipt.shippingAddress != null)
              _SummaryRow(
                label: shippingLabel,
                value: _formatShippingLabel(
                  receipt.shippingAddress!,
                  isInternational,
                ),
              ),
            if (receipt.paymentMethod != null)
              _SummaryRow(
                label: paymentLabel,
                value: _formatPaymentMethodLabel(
                  receipt.paymentMethod!,
                  isInternational,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXS),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NextStepsSection extends StatelessWidget {
  const _NextStepsSection({
    required this.isInternational,
    required this.onTrackOrder,
    required this.onDownloadInvoice,
    required this.onRecreateDesign,
    required this.onViewLibrary,
    required this.onContinueShopping,
  });

  final bool isInternational;
  final VoidCallback onTrackOrder;
  final VoidCallback onDownloadInvoice;
  final VoidCallback onRecreateDesign;
  final VoidCallback onViewLibrary;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational ? 'Next steps' : '次のステップ';

    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppTokens.radiusL),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceM),
            _NextStepTile(
              icon: Icons.timeline,
              title: isInternational
                  ? 'Track production progress'
                  : '制作状況を追跡する',
              subtitle: isInternational
                  ? 'See timeline updates and shipping checkpoints.'
                  : '制作工程と配送状況の更新を確認できます。',
              chipLabel: isInternational ? 'Track order' : '進捗を見る',
              onPressed: onTrackOrder,
            ),
            _NextStepTile(
              icon: Icons.picture_as_pdf_outlined,
              title: isInternational ? 'Download your invoice' : '請求書をダウンロード',
              subtitle: isInternational
                  ? 'Save a PDF copy for your records.'
                  : '控えとして PDF を保存しましょう。',
              chipLabel: isInternational ? 'Download' : 'ダウンロード',
              onPressed: onDownloadInvoice,
            ),
            _NextStepTile(
              icon: Icons.auto_fix_high_outlined,
              title: isInternational ? 'Recreate this design' : 'このデザインを再作成',
              subtitle: isInternational
                  ? 'Start with the same specifications.'
                  : '同じ仕様で再注文を開始します。',
              chipLabel: isInternational ? 'Recreate' : '再作成',
              onPressed: onRecreateDesign,
            ),
            _NextStepTile(
              icon: Icons.inventory_2_outlined,
              title: isInternational ? 'View saved seals' : '保存した印影を見る',
              subtitle: isInternational
                  ? 'Access digital assets in your library.'
                  : 'ライブラリでデータや共有リンクを管理します。',
              chipLabel: isInternational ? 'Library' : 'ライブラリ',
              onPressed: onViewLibrary,
            ),
            _NextStepTile(
              icon: Icons.storefront_outlined,
              title: isInternational ? 'Continue shopping' : 'ショップで探し続ける',
              subtitle: isInternational
                  ? 'Discover more materials and accessories.'
                  : '素材やアクセサリーを追加しましょう。',
              chipLabel: isInternational ? 'Shop' : 'ショップ',
              onPressed: onContinueShopping,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepTile extends StatelessWidget {
  const _NextStepTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String chipLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceM),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceM,
              vertical: AppTokens.spaceXS,
            ),
          ),
          child: Text(chipLabel),
        ),
        onTap: onPressed,
      ),
    );
  }
}

class _ShareAndOrdersSection extends StatelessWidget {
  const _ShareAndOrdersSection({
    required this.receipt,
    required this.experience,
    required this.onShare,
    required this.onViewOrders,
  });

  final CheckoutOrderReceipt receipt;
  final ExperienceGate? experience;
  final VoidCallback onShare;
  final VoidCallback onViewOrders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInternational = experience?.isInternational ?? false;
    final shareLabel = isInternational ? 'Share order' : '注文を共有';
    final ordersLabel = isInternational ? 'View orders' : '注文履歴を見る';
    final message = isInternational
        ? 'Invite teammates to follow the timeline.'
        : 'チームと共有して進捗を把握しましょう。';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppTokens.spaceM),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onShare,
                child: Text(shareLabel),
              ),
            ),
            const SizedBox(width: AppTokens.spaceM),
            Expanded(
              child: OutlinedButton(
                onPressed: onViewOrders,
                child: Text(ordersLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutCompleteFallback extends StatelessWidget {
  const _CheckoutCompleteFallback({
    required this.orderId,
    required this.isInternational,
    required this.onViewOrders,
    required this.onContinueShopping,
  });

  final String orderId;
  final bool isInternational;
  final VoidCallback onViewOrders;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isInternational
        ? 'Order details unavailable'
        : '注文情報を確認できません';
    final body = isInternational
        ? 'We could not load completion details for $orderId.'
              ' View your orders to confirm status.'
        : '注文 $orderId の完了情報を表示できませんでした。注文履歴から確認してください。';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceL),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 48,
                ),
                const SizedBox(height: AppTokens.spaceM),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTokens.spaceL),
                FilledButton(
                  onPressed: onViewOrders,
                  child: Text(isInternational ? 'View orders' : '注文履歴を見る'),
                ),
                const SizedBox(height: AppTokens.spaceS),
                TextButton(
                  onPressed: onContinueShopping,
                  child: Text(
                    isInternational ? 'Continue shopping' : 'ショップに戻る',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCurrency(
  double value,
  String symbol,
  String currencyCode,
  String? locale,
) {
  final format = NumberFormat.currency(
    locale: locale ?? (currencyCode == 'JPY' ? 'ja_JP' : 'en_US'),
    symbol: '',
    decimalDigits: currencyCode == 'JPY' ? 0 : 2,
  );
  final formatted = format.format(value);
  return '$symbol$formatted';
}

String _formatShippingLabel(UserAddress address, bool isInternational) {
  final parts = <String>[];
  parts.add(address.recipient);
  if (address.company != null && address.company!.trim().isNotEmpty) {
    parts.add(address.company!.trim());
  }
  final locationSegments = <String>[];
  if (address.state != null && address.state!.trim().isNotEmpty) {
    locationSegments.add(address.state!.trim());
  }
  if (address.city.trim().isNotEmpty) {
    locationSegments.add(address.city.trim());
  }
  if (isInternational) {
    if (address.country.trim().isNotEmpty) {
      locationSegments.add(address.country.trim());
    }
  } else if (address.postalCode.trim().isNotEmpty) {
    locationSegments.add(address.postalCode.trim());
  }
  final location = locationSegments.join(isInternational ? ', ' : ' ');
  if (location.isNotEmpty) {
    parts.add(location);
  }
  return parts.join(' • ');
}

String _formatPaymentMethodLabel(
  CheckoutPaymentMethodSummary method,
  bool isInternational,
) {
  final providerLabel = switch (method.provider) {
    PaymentProvider.paypal => 'PayPal',
    PaymentProvider.stripe => isInternational ? 'Card' : 'カード',
    _ => isInternational ? 'Payment method' : '支払い方法',
  };
  final brand = method.brand?.trim();
  final last4 = method.last4?.trim();
  final billing = method.billingName?.trim();
  final chips = <String>[];
  if (billing != null && billing.isNotEmpty) {
    chips.add(billing);
  }
  final brandPart = brand != null && brand.isNotEmpty ? brand : providerLabel;
  if (last4 != null && last4.isNotEmpty) {
    chips.add('$brandPart •••• $last4');
  } else {
    chips.add(brandPart);
  }
  return chips.join(' • ');
}
