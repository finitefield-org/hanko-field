// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/checkout/view_model/checkout_complete_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class CheckoutCompletePage extends ConsumerWidget {
  const CheckoutCompletePage({super.key, this.orderId, this.orderNumber});

  final String? orderId;
  final String? orderNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final viewModel = CheckoutCompleteViewModel(
      orderId: orderId,
      orderNumber: orderNumber,
    );
    final state = ref.watch(viewModel);
    final requestState = ref.watch(viewModel.requestNotificationsMut);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => GoRouter.of(context).go(AppRoutePaths.shop),
        ),
        title: Text(prefersEnglish ? 'Order complete' : '注文完了'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.lg,
          ),
          child: _Body(
            prefersEnglish: prefersEnglish,
            state: state,
            requestState: requestState,
            onRequestNotifications: () =>
                ref.invoke(viewModel.requestNotifications()),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.prefersEnglish,
    required this.state,
    required this.requestState,
    required this.onRequestNotifications,
  });

  final bool prefersEnglish;
  final AsyncValue<CheckoutCompleteState> state;
  final MutationState<CheckoutNotificationStatus> requestState;
  final VoidCallback onRequestNotifications;

  @override
  Widget build(BuildContext context) {
    final current = state;
    final tokens = DesignTokensTheme.of(context);

    if (current is AsyncLoading<CheckoutCompleteState> &&
        current.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 4, itemHeight: 110),
      );
    }

    if (current is AsyncError<CheckoutCompleteState> &&
        current.valueOrNull == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish
              ? 'Could not load confirmation'
              : '注文完了を表示できません',
          message: current.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Back to shop' : 'ショップへ戻る',
          onAction: () => GoRouter.of(context).go(AppRoutePaths.shop),
        ),
      );
    }

    final data =
        current.valueOrNull ??
        (throw StateError('Missing checkout complete state'));

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _HeroCard(
          prefersEnglish: prefersEnglish,
          orderNumber: data.orderNumber,
          itemCount: data.cart.itemCount,
          totalLabel: _formatMoney(data.total),
          etaLabel: data.estimatedDeliveryLabel,
        ),
        SizedBox(height: tokens.spacing.md),
        _NextStepsCard(
          prefersEnglish: prefersEnglish,
          notificationStatus: data.notificationStatus,
          isRequesting: requestState is PendingMutationState,
          onRequestNotifications: onRequestNotifications,
        ),
        SizedBox(height: tokens.spacing.md),
        _ShareCard(
          prefersEnglish: prefersEnglish,
          orderNumber: data.orderNumber,
        ),
        SizedBox(height: tokens.spacing.md),
        AppButton(
          label: prefersEnglish ? 'Continue shopping' : '買い物を続ける',
          expand: true,
          onPressed: () => GoRouter.of(context).go(AppRoutePaths.shop),
        ),
      ],
    );
  }

  String _formatMoney(Money money) {
    final prefix = money.currency == 'JPY' ? '¥' : '${money.currency} ';
    return '$prefix${money.amount}';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.prefersEnglish,
    required this.orderNumber,
    required this.itemCount,
    required this.totalLabel,
    required this.etaLabel,
  });

  final bool prefersEnglish;
  final String orderNumber;
  final int itemCount;
  final String totalLabel;
  final String? etaLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.colors.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(tokens.radii.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.celebration_outlined,
              color: tokens.colors.secondary,
              size: 28,
            ),
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'Thanks for your order!' : 'ご注文ありがとうございました',
                  style: textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish ? 'Confirmation' : '注文番号',
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(orderNumber, style: textTheme.headlineSmall),
                SizedBox(height: tokens.spacing.sm),
                Text(
                  prefersEnglish
                      ? '$itemCount items • Total $totalLabel'
                      : '$itemCount点 • 合計 $totalLabel',
                  style: textTheme.bodyMedium,
                ),
                if (etaLabel != null) ...[
                  SizedBox(height: tokens.spacing.xs),
                  Text(
                    prefersEnglish
                        ? 'Estimated delivery: $etaLabel'
                        : 'お届け目安：$etaLabel',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.colors.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({
    required this.prefersEnglish,
    required this.notificationStatus,
    required this.isRequesting,
    required this.onRequestNotifications,
  });

  final bool prefersEnglish;
  final CheckoutNotificationStatus notificationStatus;
  final bool isRequesting;
  final VoidCallback onRequestNotifications;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);

    final notificationChip = switch (notificationStatus) {
      CheckoutNotificationStatus.authorized => ActionChip(
        label: Text(prefersEnglish ? 'Enabled' : '有効'),
        avatar: const Icon(Icons.notifications_active_outlined),
        onPressed: null,
      ),
      CheckoutNotificationStatus.denied => ActionChip(
        label: Text(prefersEnglish ? 'Enable' : '有効にする'),
        avatar: const Icon(Icons.notifications_outlined),
        onPressed: isRequesting ? null : onRequestNotifications,
      ),
      CheckoutNotificationStatus.unknown => ActionChip(
        label: Text(prefersEnglish ? 'Enable' : '有効にする'),
        avatar: const Icon(Icons.notifications_outlined),
        onPressed: isRequesting ? null : onRequestNotifications,
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Next steps' : '次にできること',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          _StepTile(
            title: prefersEnglish ? 'Track your order' : '注文状況を確認する',
            subtitle: prefersEnglish
                ? 'See production and delivery updates.'
                : '制作進捗や配送状況を確認できます。',
            chipLabel: prefersEnglish ? 'Open' : '開く',
            onChipPressed: () => router.go(AppRoutePaths.orders),
          ),
          _StepTile(
            title: prefersEnglish ? 'View your library' : 'マイ印鑑を見る',
            subtitle: prefersEnglish
                ? 'Reuse and export your saved designs.'
                : '保存したデザインを再利用・出力できます。',
            chipLabel: prefersEnglish ? 'Open' : '開く',
            onChipPressed: () => router.go(AppRoutePaths.library),
          ),
          _StepTile(
            title: prefersEnglish ? 'Create another design' : 'もう一度作成する',
            subtitle: prefersEnglish
                ? 'Start a fresh design flow.'
                : '新しいデザイン作成を開始します。',
            chipLabel: prefersEnglish ? 'Start' : '開始',
            onChipPressed: () => router.go('${AppRoutePaths.design}/new'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none_outlined),
            title: Text(
              prefersEnglish ? 'Delivery notifications' : '配送通知',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              prefersEnglish
                  ? 'Get updates when your order ships.'
                  : '発送時などに通知を受け取ります。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.72),
              ),
            ),
            trailing: notificationChip,
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.onChipPressed,
  });

  final String title;
  final String subtitle;
  final String chipLabel;
  final VoidCallback onChipPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.colors.onSurface.withValues(alpha: 0.72),
        ),
      ),
      trailing: ActionChip(label: Text(chipLabel), onPressed: onChipPressed),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.prefersEnglish, required this.orderNumber});

  final bool prefersEnglish;
  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prefersEnglish ? 'Share' : '共有',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: tokens.spacing.sm),
          Text(
            prefersEnglish
                ? 'Share your confirmation with family or colleagues.'
                : '注文番号を共有できます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: prefersEnglish ? 'Share' : '共有する',
                  variant: AppButtonVariant.secondary,
                  leading: const Icon(Icons.ios_share_outlined),
                  expand: true,
                  onPressed: () {
                    final text = prefersEnglish
                        ? 'Order confirmation: $orderNumber'
                        : '注文番号：$orderNumber';
                    Share.share(text);
                  },
                ),
              ),
              SizedBox(width: tokens.spacing.sm),
              Expanded(
                child: AppButton(
                  label: prefersEnglish ? 'View orders' : '注文一覧',
                  variant: AppButtonVariant.ghost,
                  expand: true,
                  onPressed: () => router.go(AppRoutePaths.orders),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
