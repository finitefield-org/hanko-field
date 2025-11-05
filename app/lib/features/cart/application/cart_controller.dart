import 'dart:collection';
import 'dart:math';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/cart/application/cart_repository_provider.dart';
import 'package:app/features/cart/data/cart_repository.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartController extends AsyncNotifier<CartViewState> {
  CartRepository get _repository => ref.read(cartRepositoryProvider);

  @override
  Future<CartViewState> build() async {
    final experience = await ref.watch(experienceGateProvider.future);
    final snapshot = await _repository.loadCart(experience: experience);
    return CartViewState(snapshot: snapshot);
  }

  Future<void> reload() async {
    final experience = await ref.read(experienceGateProvider.future);
    state = const AsyncValue.loading();
    try {
      final snapshot = await _repository.loadCart(experience: experience);
      state = AsyncValue.data(CartViewState(snapshot: snapshot));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> incrementQuantity(String lineId) => _adjustQuantity(lineId, 1);

  Future<void> decrementQuantity(String lineId) => _adjustQuantity(lineId, -1);

  Future<void> _adjustQuantity(String lineId, int delta) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final line = current.findLine(lineId);
    if (line == null) {
      return;
    }
    final nextQuantity = max(1, line.quantity + delta);
    if (nextQuantity == line.quantity) {
      return;
    }
    final processing = <String>{...current.processingLineIds, lineId};
    state = AsyncValue.data(current.copyWith(processingLineIds: processing));
    try {
      final updated = await _repository.setLineQuantity(
        experience: current.snapshot.experience,
        lineId: lineId,
        quantity: nextQuantity,
      );
      final updatedProcessing = <String>{...processing}..remove(lineId);
      final message = current.snapshot.experience.isInternational
          ? 'Updated quantity for ${line.title}.'
          : '「${line.title}」の数量を更新しました。';
      state = AsyncValue.data(
        current.copyWith(
          snapshot: updated,
          processingLineIds: updatedProcessing,
          feedbackMessage: message,
          setFeedbackMessage: true,
          setPromoError: true,
        ),
      );
    } catch (error) {
      final rollbackProcessing = <String>{...processing}..remove(lineId);
      state = AsyncValue.data(
        current.copyWith(processingLineIds: rollbackProcessing),
      );
    }
  }

  Future<void> removeLine(String lineId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final index = current.snapshot.lines.indexWhere(
      (line) => line.id == lineId,
    );
    if (index == -1) {
      return;
    }
    final line = current.snapshot.lines[index];
    final processing = <String>{...current.processingLineIds, lineId};
    state = AsyncValue.data(current.copyWith(processingLineIds: processing));
    try {
      final updated = await _repository.removeLine(
        experience: current.snapshot.experience,
        lineId: lineId,
      );
      final updatedProcessing = <String>{...processing}..remove(lineId);
      final message = current.snapshot.experience.isInternational
          ? 'Removed ${line.title} from cart.'
          : '「${line.title}」をカートから削除しました。';
      state = AsyncValue.data(
        current.copyWith(
          snapshot: updated,
          processingLineIds: updatedProcessing,
          feedbackMessage: message,
          setFeedbackMessage: true,
          setPromoError: true,
          recentlyRemoved: CartRemovedLine(line: line, index: index),
          setRecentlyRemoved: true,
        ),
      );
    } catch (error) {
      final rollbackProcessing = <String>{...processing}..remove(lineId);
      state = AsyncValue.data(
        current.copyWith(processingLineIds: rollbackProcessing),
      );
    }
  }

  Future<void> undoLastRemoval() async {
    final current = state.value;
    final removed = current?.recentlyRemoved;
    if (current == null || removed == null) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        processingLineIds: <String>{
          ...current.processingLineIds,
          removed.line.id,
        },
      ),
    );
    try {
      final updated = await _repository.restoreLine(
        experience: current.snapshot.experience,
        line: removed.line.cache,
        index: removed.index,
      );
      final processing = <String>{...current.processingLineIds}
        ..remove(removed.line.id);
      final message = current.snapshot.experience.isInternational
          ? 'Restored ${removed.line.title}.'
          : '「${removed.line.title}」を元に戻しました。';
      state = AsyncValue.data(
        current.copyWith(
          snapshot: updated,
          processingLineIds: processing,
          feedbackMessage: message,
          setFeedbackMessage: true,
          setPromoError: true,
          setRecentlyRemoved: true,
        ),
      );
    } catch (error) {
      final processing = <String>{...current.processingLineIds}
        ..remove(removed.line.id);
      state = AsyncValue.data(current.copyWith(processingLineIds: processing));
    }
  }

  Future<void> applyPromotion(String code) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(isApplyingPromotion: true, setPromoError: true),
    );
    try {
      final updated = await _repository.applyPromotion(
        experience: current.snapshot.experience,
        promoCode: code,
      );
      final message = current.snapshot.experience.isInternational
          ? 'Promotion applied.'
          : 'プロモーションを適用しました。';
      state = AsyncValue.data(
        current.copyWith(
          snapshot: updated,
          isApplyingPromotion: false,
          feedbackMessage: message,
          setFeedbackMessage: true,
          setPromoError: true,
        ),
      );
    } on CartPromotionException catch (error) {
      state = AsyncValue.data(
        current.copyWith(
          isApplyingPromotion: false,
          promoError: error.message,
          setPromoError: true,
        ),
      );
    } catch (error) {
      state = AsyncValue.data(current.copyWith(isApplyingPromotion: false));
    }
  }

  Future<void> removePromotion() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isApplyingPromotion: true));
    try {
      final updated = await _repository.removePromotion(
        experience: current.snapshot.experience,
      );
      final message = current.snapshot.experience.isInternational
          ? 'Promotion removed.'
          : 'プロモーションを解除しました。';
      state = AsyncValue.data(
        current.copyWith(
          snapshot: updated,
          isApplyingPromotion: false,
          feedbackMessage: message,
          setFeedbackMessage: true,
          setPromoError: true,
        ),
      );
    } catch (error) {
      state = AsyncValue.data(current.copyWith(isApplyingPromotion: false));
    }
  }

  void clearFeedback() {
    final current = state.value;
    if (current == null || current.feedbackMessage == null) {
      return;
    }
    state = AsyncValue.data(current.copyWith(setFeedbackMessage: true));
  }

  void clearPromoError() {
    final current = state.value;
    if (current == null || current.promoError == null) {
      return;
    }
    state = AsyncValue.data(current.copyWith(setPromoError: true));
  }
}

@immutable
class CartViewState {
  CartViewState({
    required this.snapshot,
    Set<String> processingLineIds = const <String>{},
    this.isApplyingPromotion = false,
    this.feedbackMessage,
    this.promoError,
    this.recentlyRemoved,
  }) : processingLineIds = UnmodifiableSetView(processingLineIds);

  final CartSnapshot snapshot;
  final UnmodifiableSetView<String> processingLineIds;
  final bool isApplyingPromotion;
  final String? feedbackMessage;
  final String? promoError;
  final CartRemovedLine? recentlyRemoved;

  List<CartLine> get lines => snapshot.lines;

  CartEstimate get estimate => snapshot.estimate;

  bool get hasLines => snapshot.lines.isNotEmpty;

  CartViewState copyWith({
    CartSnapshot? snapshot,
    Set<String>? processingLineIds,
    bool? isApplyingPromotion,
    String? feedbackMessage,
    bool setFeedbackMessage = false,
    String? promoError,
    bool setPromoError = false,
    CartRemovedLine? recentlyRemoved,
    bool setRecentlyRemoved = false,
  }) {
    return CartViewState(
      snapshot: snapshot ?? this.snapshot,
      processingLineIds: processingLineIds ?? this.processingLineIds.toSet(),
      isApplyingPromotion: isApplyingPromotion ?? this.isApplyingPromotion,
      feedbackMessage: setFeedbackMessage
          ? feedbackMessage
          : this.feedbackMessage,
      promoError: setPromoError ? promoError : this.promoError,
      recentlyRemoved: setRecentlyRemoved
          ? recentlyRemoved
          : this.recentlyRemoved,
    );
  }

  CartLine? findLine(String lineId) {
    for (final line in snapshot.lines) {
      if (line.id == lineId) {
        return line;
      }
    }
    return null;
  }
}

@immutable
class CartRemovedLine {
  const CartRemovedLine({required this.line, required this.index});

  final CartLine line;
  final int index;
}

final cartControllerProvider =
    AsyncNotifierProvider<CartController, CartViewState>(CartController.new);
