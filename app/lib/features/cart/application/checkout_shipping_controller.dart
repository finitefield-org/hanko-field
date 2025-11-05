import 'dart:collection';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/cart/application/cart_repository_provider.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:app/features/cart/data/cart_repository.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final checkoutShippingControllerProvider =
    AsyncNotifierProvider<CheckoutShippingController, CheckoutShippingState>(
      CheckoutShippingController.new,
      name: 'checkoutShippingControllerProvider',
    );

enum CheckoutShippingFocus { balance, cost, speed }

const Object _shippingStateSentinel = Object();

class CheckoutShippingState {
  CheckoutShippingState({
    required List<CheckoutShippingOption> options,
    this.selectedOptionId,
    this.advisory,
    this.focus = CheckoutShippingFocus.balance,
    this.isSaving = false,
    this.errorMessage,
    Set<String>? restrictedOptionIds,
  }) : options = UnmodifiableListView<CheckoutShippingOption>(options),
       restrictedOptionIds = UnmodifiableSetView<String>(
         restrictedOptionIds ?? const <String>{},
       );

  final UnmodifiableListView<CheckoutShippingOption> options;
  final String? selectedOptionId;
  final CheckoutShippingAdvisory? advisory;
  final CheckoutShippingFocus focus;
  final bool isSaving;
  final String? errorMessage;
  final UnmodifiableSetView<String> restrictedOptionIds;

  bool get hasOptions => options.isNotEmpty;

  bool get hasAdvisory => advisory != null;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  CheckoutShippingOption? get selectedOption {
    if (selectedOptionId == null) {
      return null;
    }
    for (final option in options) {
      if (option.id == selectedOptionId) {
        return option;
      }
    }
    return null;
  }

  List<CheckoutShippingOption> optionsForRegion(CheckoutShippingRegion region) {
    final regionOptions = <CheckoutShippingOption>[
      for (final option in options)
        if (option.region == region) option,
    ];
    if (focus == CheckoutShippingFocus.balance) {
      return regionOptions;
    }
    final sorted = [...regionOptions];
    if (focus == CheckoutShippingFocus.cost) {
      sorted.sort((a, b) {
        final priceCompare = a.price.compareTo(b.price);
        if (priceCompare != 0) {
          return priceCompare;
        }
        return _speedPriority(a.speed).compareTo(_speedPriority(b.speed));
      });
      return sorted;
    }
    sorted.sort(
      (a, b) => _speedPriority(a.speed).compareTo(_speedPriority(b.speed)),
    );
    return sorted;
  }

  bool isRestricted(String optionId) => restrictedOptionIds.contains(optionId);

  CheckoutShippingState copyWith({
    List<CheckoutShippingOption>? options,
    Object? selectedOptionId = _shippingStateSentinel,
    CheckoutShippingAdvisory? advisory,
    CheckoutShippingFocus? focus,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    Set<String>? restrictedOptionIds,
  }) {
    return CheckoutShippingState(
      options: options ?? this.options,
      selectedOptionId: identical(selectedOptionId, _shippingStateSentinel)
          ? this.selectedOptionId
          : selectedOptionId as String?,
      advisory: advisory ?? this.advisory,
      focus: focus ?? this.focus,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      restrictedOptionIds:
          restrictedOptionIds ??
          UnmodifiableSetView<String>(this.restrictedOptionIds.toSet()),
    );
  }
}

class CheckoutShippingController extends AsyncNotifier<CheckoutShippingState> {
  CartRepository get _repository => ref.read(cartRepositoryProvider);

  CheckoutStateNotifier get _checkoutState =>
      ref.read(checkoutStateProvider.notifier);

  CartController get _cartController =>
      ref.read(cartControllerProvider.notifier);

  @override
  Future<CheckoutShippingState> build() async {
    return _buildState();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final next = await _buildState(preferredFocus: state.value?.focus);
      state = AsyncValue.data(next);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> selectOption(String optionId) async {
    final current = state.value;
    if (current == null ||
        current.isSaving ||
        current.selectedOptionId == optionId) {
      return;
    }
    if (current.isRestricted(optionId)) {
      final experience = await ref.read(experienceGateProvider.future);
      state = AsyncValue.data(
        current.copyWith(
          errorMessage: _restrictionMessage(experience),
          clearError: false,
        ),
      );
      return;
    }
    state = AsyncValue.data(current.copyWith(isSaving: true, clearError: true));
    final experience = await ref.read(experienceGateProvider.future);
    try {
      final snapshot = await _repository.selectShippingOption(
        experience: experience,
        optionId: optionId,
      );
      _cartController.syncSnapshot(
        snapshot,
        feedbackMessage: experience.isInternational
            ? 'Updated shipping preference.'
            : '配送方法を更新しました。',
      );
      final nextState = await _buildState(
        experienceOverride: experience,
        initialSnapshot: snapshot,
        preferredFocus: current.focus,
      );
      state = AsyncValue.data(nextState);
    } on CheckoutShippingException catch (error) {
      state = AsyncValue.data(
        current.copyWith(isSaving: false, errorMessage: error.message),
      );
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(
          isSaving: false,
          errorMessage: experience.isInternational
              ? 'Unable to update shipping option.'
              : '配送方法の更新に失敗しました。',
        ),
      );
    }
  }

  void changeFocus(CheckoutShippingFocus focus) {
    final current = state.value;
    if (current == null || current.focus == focus) {
      return;
    }
    state = AsyncValue.data(current.copyWith(focus: focus, clearError: true));
  }

  void clearError() {
    final current = state.value;
    if (current == null || !current.hasError) {
      return;
    }
    state = AsyncValue.data(current.copyWith(clearError: true));
  }

  Future<CheckoutShippingState> _buildState({
    ExperienceGate? experienceOverride,
    CartSnapshot? initialSnapshot,
    CheckoutShippingFocus? preferredFocus,
  }) async {
    final ExperienceGate experience =
        experienceOverride ?? await ref.watch(experienceGateProvider.future);
    final existingSnapshot = ref.read(cartControllerProvider).value?.snapshot;
    late final CartSnapshot snapshot;
    if (initialSnapshot != null) {
      snapshot = initialSnapshot;
      _cartController.syncSnapshot(snapshot);
    } else if (existingSnapshot != null) {
      snapshot = existingSnapshot;
    } else {
      snapshot = await _repository.loadCart(experience: experience);
      _cartController.syncSnapshot(snapshot);
    }
    final data = await _repository.fetchShippingOptions(experience: experience);
    final selectedId =
        data.selectedOptionId ??
        snapshot.shippingOption?.id ??
        _defaultOptionIdFor(experience, data.options);
    final selectedOption = _findOptionById(data.options, selectedId);
    if (selectedOption != null) {
      _checkoutState.setShippingOption(selectedOption);
    } else {
      _checkoutState.clearShippingOption();
    }
    final restricted = _computeRestrictedOptionIds(
      snapshot.promotion?.code,
      data.options,
    );
    final focus = preferredFocus ?? _suggestFocus(selectedOption);
    return CheckoutShippingState(
      options: data.options,
      selectedOptionId: selectedOption?.id,
      advisory: data.advisory,
      focus: focus,
      restrictedOptionIds: restricted,
    );
  }

  Set<String> _computeRestrictedOptionIds(
    String? promoCode,
    List<CheckoutShippingOption> options,
  ) {
    if (promoCode == null || promoCode.isEmpty) {
      return const <String>{};
    }
    final normalized = promoCode.toUpperCase();
    if (normalized != 'FREESHIP') {
      return const <String>{};
    }
    return {
      for (final option in options)
        if (option.speed != CheckoutShippingSpeed.express) option.id,
    };
  }

  String? _defaultOptionIdFor(
    ExperienceGate experience,
    List<CheckoutShippingOption> options,
  ) {
    if (options.isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.isRecommended) {
        return option.id;
      }
    }
    return options.first.id;
  }

  CheckoutShippingOption? _findOptionById(
    List<CheckoutShippingOption> options,
    String? id,
  ) {
    if (id == null) {
      return null;
    }
    for (final option in options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  CheckoutShippingFocus _suggestFocus(CheckoutShippingOption? option) {
    if (option == null) {
      return CheckoutShippingFocus.balance;
    }
    switch (option.speed) {
      case CheckoutShippingSpeed.express:
        return CheckoutShippingFocus.speed;
      case CheckoutShippingSpeed.economy:
        return CheckoutShippingFocus.cost;
      case CheckoutShippingSpeed.standard:
        return CheckoutShippingFocus.balance;
    }
  }

  String _restrictionMessage(ExperienceGate experience) {
    return experience.isInternational
        ? 'FREESHIP applies to express courier only.'
        : '送料無料コード（FREESHIP）はエクスプレス便にのみ適用されます。';
  }
}

int _speedPriority(CheckoutShippingSpeed speed) {
  switch (speed) {
    case CheckoutShippingSpeed.express:
      return 0;
    case CheckoutShippingSpeed.standard:
      return 1;
    case CheckoutShippingSpeed.economy:
      return 2;
  }
}
