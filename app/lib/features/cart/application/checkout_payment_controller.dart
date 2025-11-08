import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/data/repositories/api_user_repository.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/domain/repositories/user_repository.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkoutPaymentControllerProvider =
    AsyncNotifierProvider<CheckoutPaymentController, CheckoutPaymentState>(
      CheckoutPaymentController.new,
      name: 'checkoutPaymentControllerProvider',
    );

const Object _sentinel = Object();

class CheckoutPaymentState {
  CheckoutPaymentState({
    required List<CheckoutPaymentMethodSummary> methods,
    this.selectedMethodId,
    this.isRefreshing = false,
    this.isProcessing = false,
    this.isAdding = false,
    this.canAddNewMethod = true,
    this.feedbackMessage,
    this.errorMessage,
    Set<String>? removingMethodIds,
  }) : methods = UnmodifiableListView<CheckoutPaymentMethodSummary>(methods),
       removingMethodIds = UnmodifiableSetView<String>(
         removingMethodIds ?? const <String>{},
       );

  final UnmodifiableListView<CheckoutPaymentMethodSummary> methods;
  final String? selectedMethodId;
  final bool isRefreshing;
  final bool isProcessing;
  final bool isAdding;
  final bool canAddNewMethod;
  final String? feedbackMessage;
  final String? errorMessage;
  final UnmodifiableSetView<String> removingMethodIds;

  bool get hasMethods => methods.isNotEmpty;

  CheckoutPaymentMethodSummary? get selectedMethod {
    if (selectedMethodId == null) {
      return null;
    }
    for (final method in methods) {
      if (method.id == selectedMethodId) {
        return method;
      }
    }
    return null;
  }

  CheckoutPaymentState copyWith({
    List<CheckoutPaymentMethodSummary>? methods,
    Object? selectedMethodId = _sentinel,
    bool? isRefreshing,
    bool? isProcessing,
    bool? isAdding,
    bool? canAddNewMethod,
    String? feedbackMessage,
    bool clearFeedback = false,
    String? errorMessage,
    bool clearError = false,
    Set<String>? removingMethodIds,
  }) {
    return CheckoutPaymentState(
      methods: methods ?? this.methods,
      selectedMethodId: identical(selectedMethodId, _sentinel)
          ? this.selectedMethodId
          : selectedMethodId as String?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isProcessing: isProcessing ?? this.isProcessing,
      isAdding: isAdding ?? this.isAdding,
      canAddNewMethod: canAddNewMethod ?? this.canAddNewMethod,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      removingMethodIds: removingMethodIds == null
          ? this.removingMethodIds
          : UnmodifiableSetView<String>(removingMethodIds),
    );
  }
}

class TokenizedPaymentMethodPayload {
  TokenizedPaymentMethodPayload({
    required this.provider,
    required this.methodType,
    required this.providerRef,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.billingName,
  });

  final PaymentProvider provider;
  final PaymentMethodType methodType;
  final String providerRef;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? billingName;
}

class CheckoutPaymentController extends AsyncNotifier<CheckoutPaymentState> {
  CheckoutPaymentController();

  late ExperienceGate _experience;
  List<UserPaymentMethod> _rawMethods = const [];

  UserRepository get _userRepository => ref.read(userRepositoryProvider);

  SecureStorageService get _secureStorage => ref.read(secureStorageProvider);

  CheckoutStateNotifier get _checkoutState =>
      ref.read(checkoutStateProvider.notifier);

  CheckoutState get _checkoutSnapshot => ref.read(checkoutStateProvider);

  @override
  Future<CheckoutPaymentState> build() async {
    _experience = await ref.watch(experienceGateProvider.future);
    final methods = await _userRepository.fetchPaymentMethods();
    return _synthesiseState(methods: methods);
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      state = const AsyncValue.loading();
    } else {
      state = AsyncValue.data(
        current.copyWith(
          isRefreshing: true,
          clearFeedback: true,
          clearError: true,
        ),
      );
    }
    try {
      final methods = await _userRepository.fetchPaymentMethods();
      final next = await _synthesiseState(
        methods: methods,
        preserveSelectionId: current?.selectedMethodId,
      );
      state = AsyncValue.data(next.copyWith(isRefreshing: false));
    } catch (error, stackTrace) {
      if (current == null) {
        state = AsyncValue.error(error, stackTrace);
        return;
      }
      state = AsyncValue.data(
        current.copyWith(
          isRefreshing: false,
          errorMessage: _localized(
            'お支払い方法の更新に失敗しました。',
            'Unable to refresh payment methods.',
          ),
          clearFeedback: true,
        ),
      );
    }
  }

  void clearMessages() {
    final current = state.value;
    if (current == null ||
        (current.feedbackMessage == null && current.errorMessage == null)) {
      return;
    }
    state = AsyncValue.data(
      current.copyWith(clearFeedback: true, clearError: true),
    );
  }

  void selectMethod(String methodId) {
    final current = state.value;
    if (current == null || current.selectedMethodId == methodId) {
      return;
    }
    final method = _findSummary(methodId, current.methods);
    if (method == null) {
      return;
    }
    _checkoutState.setPaymentMethod(method);
    state = AsyncValue.data(
      current.copyWith(
        selectedMethodId: methodId,
        clearFeedback: true,
        clearError: true,
      ),
    );
  }

  Future<void> registerTokenizedMethod(
    TokenizedPaymentMethodPayload payload,
  ) async {
    final current = state.value;
    if (current != null && !current.canAddNewMethod) {
      state = AsyncValue.data(
        current.copyWith(
          errorMessage: _localized(
            'これ以上お支払い方法を追加できません。',
            'You cannot add more payment methods right now.',
          ),
          clearFeedback: true,
        ),
      );
      return;
    }

    state = AsyncValue.data(
      (current ?? CheckoutPaymentState(methods: const [], isProcessing: true))
          .copyWith(
            isProcessing: true,
            isAdding: true,
            clearFeedback: true,
            clearError: true,
          ),
    );

    try {
      final now = DateTime.now();
      final method = UserPaymentMethod(
        id: _generateLocalId(),
        provider: payload.provider,
        methodType: payload.methodType,
        brand: payload.brand,
        last4: payload.last4,
        expMonth: payload.expMonth,
        expYear: payload.expYear,
        billingName: payload.billingName,
        providerRef: payload.providerRef,
        fingerprint: null,
        createdAt: now,
        updatedAt: now,
      );
      final savedMethod = await _userRepository.addPaymentMethod(method);
      final merged = [..._rawMethods, savedMethod];
      final nextState = await _synthesiseState(
        methods: merged,
        preserveSelectionId: savedMethod.id,
      );
      state = AsyncValue.data(
        nextState.copyWith(
          isProcessing: false,
          isAdding: false,
          feedbackMessage: _localized(
            'お支払い方法を追加しました。',
            'New payment method added.',
          ),
        ),
      );
    } catch (error) {
      final currentState = state.value;
      if (currentState == null) {
        state = AsyncValue.error(error, StackTrace.current);
        return;
      }
      state = AsyncValue.data(
        currentState.copyWith(
          isProcessing: false,
          isAdding: false,
          errorMessage: _localized(
            'お支払い方法の追加に失敗しました。',
            'Failed to add payment method.',
          ),
          clearFeedback: true,
        ),
      );
    }
  }

  Future<void> removeMethod(String methodId) async {
    final current = state.value;
    if (current == null || current.removingMethodIds.contains(methodId)) {
      return;
    }
    final methodIndex = _rawMethods.indexWhere(
      (element) => element.id == methodId,
    );
    if (methodIndex == -1) {
      state = AsyncValue.data(
        current.copyWith(
          errorMessage: _localized(
            'お支払い方法が見つかりません。',
            'Payment method not found.',
          ),
          clearFeedback: true,
        ),
      );
      return;
    }

    final removing = {...current.removingMethodIds, methodId};
    state = AsyncValue.data(
      current.copyWith(
        isProcessing: true,
        removingMethodIds: removing,
        clearFeedback: true,
        clearError: true,
      ),
    );

    try {
      final method = _rawMethods[methodIndex];
      if (!_isLocalId(method.id)) {
        await _userRepository.removePaymentMethod(methodId);
      }
      await _secureStorage.delete(key: _tokenStorageKey(methodId));
      final remaining = [..._rawMethods]..removeAt(methodIndex);
      final preserveSelection = current.selectedMethodId == methodId
          ? null
          : current.selectedMethodId;
      final nextState = await _synthesiseState(
        methods: remaining,
        preserveSelectionId: preserveSelection,
      );
      final latestRemoving = {...state.value?.removingMethodIds ?? removing}
        ..remove(methodId);
      state = AsyncValue.data(
        nextState.copyWith(
          isProcessing: false,
          removingMethodIds: latestRemoving,
          feedbackMessage: _localized(
            'お支払い方法を削除しました。',
            'Payment method removed.',
          ),
        ),
      );
    } catch (error) {
      final latestState = state.value ?? current;
      final updatedRemoving = {...latestState.removingMethodIds}
        ..remove(methodId);
      state = AsyncValue.data(
        latestState.copyWith(
          isProcessing: false,
          removingMethodIds: updatedRemoving,
          errorMessage: _localized(
            'お支払い方法の削除に失敗しました。',
            'Failed to remove payment method.',
          ),
          clearFeedback: true,
        ),
      );
    }
  }

  Future<String?> readToken(String methodId) {
    return _secureStorage.read(key: _tokenStorageKey(methodId));
  }

  Future<CheckoutPaymentState> _synthesiseState({
    required List<UserPaymentMethod> methods,
    String? preserveSelectionId,
  }) async {
    _rawMethods = [...methods];
    final summaries = await _summariesFrom(_rawMethods);
    final resolvedSelectionId = _resolveSelectionId(
      summaries: summaries,
      preferred: preserveSelectionId,
    );

    if (resolvedSelectionId == null) {
      _checkoutState.clearPaymentMethod();
    } else {
      final selected = _findSummary(resolvedSelectionId, summaries);
      if (selected != null) {
        _checkoutState.setPaymentMethod(selected);
      } else {
        _checkoutState.clearPaymentMethod();
      }
    }

    final canAdd = summaries.length < _maxStoredMethods;

    return CheckoutPaymentState(
      methods: summaries,
      selectedMethodId: resolvedSelectionId,
      canAddNewMethod: canAdd,
      removingMethodIds: const <String>{},
    );
  }

  Future<List<CheckoutPaymentMethodSummary>> _summariesFrom(
    List<UserPaymentMethod> methods,
  ) async {
    if (methods.isEmpty) {
      return const [];
    }
    final sorted = [...methods]..sort(_sortByRecencyThenBrand);
    final writes = <Future<void>>[];
    final summaries = <CheckoutPaymentMethodSummary>[];
    for (final method in sorted) {
      final storageKey = _tokenStorageKey(method.id);
      writes.add(
        _secureStorage.write(key: storageKey, value: method.providerRef),
      );
      summaries.add(
        CheckoutPaymentMethodSummary(
          id: method.id,
          provider: method.provider,
          methodType: method.methodType,
          brand: method.brand,
          last4: method.last4,
          expMonth: method.expMonth,
          expYear: method.expYear,
          billingName: method.billingName,
          tokenStorageKey: storageKey,
          createdAt: method.createdAt,
          updatedAt: method.updatedAt,
        ),
      );
    }
    await Future.wait(writes);
    return summaries;
  }

  String? _resolveSelectionId({
    required List<CheckoutPaymentMethodSummary> summaries,
    String? preferred,
  }) {
    if (summaries.isEmpty) {
      return null;
    }
    CheckoutPaymentMethodSummary? lookup(String? id) {
      if (id == null) {
        return null;
      }
      return _findSummary(id, summaries);
    }

    final preferredMethod = lookup(preferred);
    if (preferredMethod != null && !preferredMethod.isExpired) {
      return preferredMethod.id;
    }

    final checkoutId = _checkoutSnapshot.selectedPaymentMethodId;
    final checkoutMethod = lookup(checkoutId);
    if (checkoutMethod != null && !checkoutMethod.isExpired) {
      return checkoutMethod.id;
    }

    return summaries
        .firstWhere(
          (method) => !method.isExpired,
          orElse: () => summaries.first,
        )
        .id;
  }

  CheckoutPaymentMethodSummary? _findSummary(
    String methodId,
    Iterable<CheckoutPaymentMethodSummary> summaries,
  ) {
    for (final method in summaries) {
      if (method.id == methodId) {
        return method;
      }
    }
    return null;
  }

  int get _maxStoredMethods => _experience.isInternational ? 5 : 3;

  int _sortByRecencyThenBrand(UserPaymentMethod a, UserPaymentMethod b) {
    final dateA = a.updatedAt ?? a.createdAt;
    final dateB = b.updatedAt ?? b.createdAt;
    final byDate = dateB.compareTo(dateA);
    if (byDate != 0) {
      return byDate;
    }
    final brandA = (a.brand ?? '').toLowerCase();
    final brandB = (b.brand ?? '').toLowerCase();
    return brandA.compareTo(brandB);
  }

  String _localized(String ja, String en) {
    return _experience.isInternational ? en : ja;
  }

  String _tokenStorageKey(String methodId) =>
      'checkout.payment.token.$methodId';

  bool _isLocalId(String methodId) => methodId.startsWith('local-pay-');

  String _generateLocalId() {
    final rand = Random();
    final suffix = rand.nextInt(1 << 32).toRadixString(16);
    return 'local-pay-$suffix-${DateTime.now().millisecondsSinceEpoch}';
  }
}
