import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/cart/application/cart_repository_provider.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:app/features/cart/data/cart_repository.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkoutReviewControllerProvider =
    NotifierProvider<CheckoutReviewController, CheckoutReviewState>(
      CheckoutReviewController.new,
      name: 'checkoutReviewControllerProvider',
    );

class CheckoutReviewState {
  const CheckoutReviewState({
    this.isSubmitting = false,
    this.successMessage,
    this.errorMessage,
    this.lastReceipt,
  });

  final bool isSubmitting;
  final String? successMessage;
  final String? errorMessage;
  final CheckoutOrderReceipt? lastReceipt;

  CheckoutReviewState copyWith({
    bool? isSubmitting,
    String? successMessage,
    bool clearSuccessMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    CheckoutOrderReceipt? lastReceipt,
    bool clearReceipt = false,
  }) {
    return CheckoutReviewState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastReceipt: clearReceipt ? null : (lastReceipt ?? this.lastReceipt),
    );
  }
}

class CheckoutReviewController extends Notifier<CheckoutReviewState> {
  CartRepository get _repository => ref.read(cartRepositoryProvider);

  CheckoutStateNotifier get _checkoutState =>
      ref.read(checkoutStateProvider.notifier);

  CartController get _cartController =>
      ref.read(cartControllerProvider.notifier);

  @override
  CheckoutReviewState build() => const CheckoutReviewState();

  Future<void> placeOrder({String? instructions}) async {
    final experience = await ref.read(experienceGateProvider.future);
    final checkoutState = ref.read(checkoutStateProvider);

    state = state.copyWith(
      isSubmitting: true,
      clearSuccessMessage: true,
      clearErrorMessage: true,
      clearReceipt: true,
    );

    try {
      final receipt = await _repository.placeOrder(
        experience: experience,
        checkoutState: checkoutState,
        specialInstructions: instructions,
      );
      final message = experience.isInternational
          ? 'Order ${receipt.orderId} confirmed.'
          : '注文 ${receipt.orderId} を受け付けました。';
      _cartController.syncSnapshot(
        receipt.updatedCart,
        feedbackMessage: message,
      );
      _checkoutState.clearSelectedAddress();
      _checkoutState.clearShippingOption();
      _checkoutState.clearPaymentMethod();
      state = state.copyWith(
        isSubmitting: false,
        successMessage: message,
        lastReceipt: receipt,
      );
    } on CheckoutSubmissionException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);
    } catch (error) {
      final fallback = experience.isInternational
          ? 'Failed to place order. Try again.'
          : '注文処理に失敗しました。もう一度お試しください。';
      state = state.copyWith(isSubmitting: false, errorMessage: fallback);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearSuccessMessage: true, clearErrorMessage: true);
  }
}
