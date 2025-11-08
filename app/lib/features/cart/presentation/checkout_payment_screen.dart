import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/cart/application/checkout_payment_controller.dart';
import 'package:app/features/payments/presentation/tokenized_payment_method_form.dart';
import 'package:app/features/payments/presentation/widgets/payment_method_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  ConsumerState<CheckoutPaymentScreen> createState() =>
      _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen> {
  late final ScrollController _scrollController;

  CheckoutPaymentController get _controller =>
      ref.read(checkoutPaymentControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    ref.listen<AsyncValue<CheckoutPaymentState>>(
      checkoutPaymentControllerProvider,
      (previous, next) {
        final prevState = previous?.value;
        final nextState = next.value;
        if (!mounted || nextState == null) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        if (nextState.feedbackMessage != null &&
            nextState.feedbackMessage != prevState?.feedbackMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(nextState.feedbackMessage!)));
          _controller.clearMessages();
        } else if (nextState.errorMessage != null &&
            nextState.errorMessage != prevState?.errorMessage) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(nextState.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          _controller.clearMessages();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startAddMethod(
    CheckoutPaymentState? state,
    ExperienceGate? experience,
  ) async {
    if (state == null || !state.canAddNewMethod) {
      final message = experience?.isInternational ?? false
          ? 'You have reached the maximum number of stored methods.'
          : '登録できるお支払い方法の上限に達しています。';
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final payload = await showModalBottomSheet<TokenizedPaymentMethodPayload>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppTokens.spaceL,
          right: AppTokens.spaceL,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.spaceL,
          top: AppTokens.spaceL,
        ),
        child: TokenizedPaymentMethodForm(
          experience: experience,
          existingMethodCount: state.methods.length,
        ),
      ),
    );
    if (payload == null) {
      return;
    }
    await _controller.registerTokenizedMethod(payload);
  }

  Future<void> _handleConfirm(
    CheckoutPaymentState state,
    ExperienceGate? experience,
  ) async {
    if (state.selectedMethodId == null) {
      final message = experience?.isInternational ?? false
          ? 'Select a payment method to continue.'
          : '続けるにはお支払い方法を選択してください。';
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final asyncExperience = ref.watch(experienceGateProvider);
    final experience = asyncExperience.value;
    final asyncState = ref.watch(checkoutPaymentControllerProvider);
    final state = asyncState.asData?.value;
    final isIntl = experience?.isInternational ?? false;

    final title = isIntl ? 'Payment methods' : 'お支払い方法';
    final addTooltip = isIntl ? 'Add payment method' : '支払い方法を追加';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: addTooltip,
            onPressed:
                state == null ||
                    state.isProcessing ||
                    state.isAdding ||
                    !state.canAddNewMethod
                ? null
                : () => _startAddMethod(state, experience),
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _PaymentLoadingView(),
          error: (error, stackTrace) => _PaymentErrorView(
            message: error.toString(),
            onRetry: _controller.refresh,
            isInternational: isIntl,
          ),
          data: (data) => RefreshIndicator(
            onRefresh: _controller.refresh,
            child: _PaymentMethodListView(
              state: data,
              isInternational: isIntl,
              controller: _controller,
              scrollController: _scrollController,
            ),
          ),
        ),
      ),
      bottomNavigationBar: asyncState.maybeWhen(
        data: (data) {
          final continueLabel = isIntl ? 'Continue' : '次へ';
          return SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppTokens.spaceL,
              AppTokens.spaceS,
              AppTokens.spaceL,
              AppTokens.spaceL,
            ),
            child: FilledButton(
              onPressed: data.isProcessing
                  ? null
                  : () => _handleConfirm(data, experience),
              child: Text(continueLabel),
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _PaymentMethodListView extends StatelessWidget {
  const _PaymentMethodListView({
    required this.state,
    required this.isInternational,
    required this.controller,
    required this.scrollController,
  });

  final CheckoutPaymentState state;
  final bool isInternational;
  final CheckoutPaymentController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (!state.hasMethods) {
      final headline = isInternational
          ? 'Add a payment method to complete checkout.'
          : 'チェックアウトを完了するにはお支払い方法を追加してください。';
      final helper = isInternational
          ? 'We securely store card tokens via our payment provider.'
          : 'カード情報は決済プロバイダでトークン化され安全に管理されます。';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppTokens.spaceL),
          Text(
            headline,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(
        left: AppTokens.spaceL,
        right: AppTokens.spaceL,
        top: AppTokens.spaceL,
        bottom: AppTokens.spaceXXL,
      ),
      itemBuilder: (context, index) {
        if (index == 0 && state.isProcessing) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final method = state.methods[state.isProcessing ? index - 1 : index];
        return PaymentMethodTile(
          method: method,
          isInternational: isInternational,
          selectedMethodId: state.selectedMethodId,
          onSelect: controller.selectMethod,
        );
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTokens.spaceM),
      itemCount: state.isProcessing
          ? state.methods.length + 1
          : state.methods.length,
    );
  }
}

class _PaymentLoadingView extends StatelessWidget {
  const _PaymentLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _PaymentErrorView extends StatelessWidget {
  const _PaymentErrorView({
    required this.message,
    required this.onRetry,
    required this.isInternational,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isInternational;

  @override
  Widget build(BuildContext context) {
    final retryLabel = isInternational ? 'Retry' : '再試行';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTokens.spaceL),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.spaceL),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
