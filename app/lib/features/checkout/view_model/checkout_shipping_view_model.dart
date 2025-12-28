// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/features/cart/view_model/cart_view_model.dart';
import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ShippingFocus { balanced, speed, cost }

class ShippingOption {
  const ShippingOption({
    required this.id,
    required this.label,
    required this.carrier,
    required this.cost,
    required this.minDays,
    required this.maxDays,
    required this.international,
    this.express = false,
    this.note,
    this.badge,
  });

  final String id;
  final String label;
  final String carrier;
  final Money cost;
  final int minDays;
  final int maxDays;
  final bool international;
  final bool express;
  final String? note;
  final String? badge;
}

class ShippingSelectionResult {
  const ShippingSelectionResult({this.selected, this.appliedCost, this.error});

  final ShippingOption? selected;
  final Money? appliedCost;
  final String? error;

  bool get isSuccess => selected != null && error == null;
}

class CheckoutShippingState {
  const CheckoutShippingState({
    required this.options,
    required this.isInternational,
    required this.subtotal,
    required this.discount,
    required this.focus,
    required this.shippingWaived,
    this.selectedId,
    this.bannerMessage,
    this.promoCode,
    this.requiresExpress = false,
    this.addressId,
  });

  final List<ShippingOption> options;
  final bool isInternational;
  final Money subtotal;
  final Money discount;
  final ShippingFocus focus;
  final bool shippingWaived;
  final String? selectedId;
  final String? bannerMessage;
  final String? promoCode;
  final bool requiresExpress;
  final String? addressId;

  bool get hasAddress => addressId != null;

  List<ShippingOption> get domesticOptions =>
      options.where((item) => !item.international).toList(growable: false);

  List<ShippingOption> get internationalOptions =>
      options.where((item) => item.international).toList(growable: false);

  List<ShippingOption> get visibleOptions =>
      isInternational ? internationalOptions : domesticOptions;

  List<ShippingOption> get sortedOptions {
    final sorted = [...visibleOptions];
    switch (focus) {
      case ShippingFocus.speed:
        sorted.sort((a, b) => a.minDays.compareTo(b.minDays));
      case ShippingFocus.cost:
        sorted.sort((a, b) => a.cost.amount.compareTo(b.cost.amount));
      case ShippingFocus.balanced:
        sorted.sort((a, b) {
          if (a.express == b.express) {
            return a.minDays.compareTo(b.minDays);
          }
          return a.express ? -1 : 1;
        });
    }
    return sorted;
  }

  ShippingOption? get selectedOption {
    final fromId = sortedOptions.firstWhereOrNull(
      (item) => item.id == selectedId,
    );
    return fromId ?? sortedOptions.firstOrNull;
  }

  Money effectiveCost(ShippingOption option) {
    if (shippingWaived && !option.express) {
      return Money(amount: 0, currency: subtotal.currency);
    }
    return option.cost;
  }

  Money get shippingCost {
    final option = selectedOption;
    if (option == null) {
      return Money(amount: 0, currency: subtotal.currency);
    }
    return effectiveCost(option);
  }

  Money get tax {
    final base = max(0, subtotal.amount - discount.amount);
    final amount = (base * 0.1).round();
    return Money(amount: amount, currency: subtotal.currency);
  }

  Money get total => Money(
    amount:
        subtotal.amount - discount.amount + shippingCost.amount + tax.amount,
    currency: subtotal.currency,
  );

  int? get etaMin => selectedOption?.minDays;

  int? get etaMax => selectedOption?.maxDays;

  CheckoutShippingState copyWith({
    List<ShippingOption>? options,
    bool? isInternational,
    Money? subtotal,
    Money? discount,
    ShippingFocus? focus,
    bool? shippingWaived,
    String? selectedId,
    String? bannerMessage,
    String? promoCode,
    bool? requiresExpress,
    String? addressId,
  }) {
    return CheckoutShippingState(
      options: options ?? this.options,
      isInternational: isInternational ?? this.isInternational,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      focus: focus ?? this.focus,
      shippingWaived: shippingWaived ?? this.shippingWaived,
      selectedId: selectedId ?? this.selectedId,
      bannerMessage: bannerMessage ?? this.bannerMessage,
      promoCode: promoCode ?? this.promoCode,
      requiresExpress: requiresExpress ?? this.requiresExpress,
      addressId: addressId ?? this.addressId,
    );
  }
}

final _shippingLogger = Logger('CheckoutShippingViewModel');

class CheckoutShippingViewModel extends AsyncProvider<CheckoutShippingState> {
  CheckoutShippingViewModel() : super.args(null, autoDispose: true);

  late final selectShippingMut = mutation<ShippingSelectionResult>(
    #selectShipping,
  );
  late final focusMut = mutation<ShippingFocus>(#setFocus);
  bool _trackedStart = false;

  @override
  Future<CheckoutShippingState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final flow = ref.watch(checkoutFlowProvider);
    final cartAsync = ref.watch(cartViewModel);
    final CartState cart =
        cartAsync.valueOrNull ?? await ref.watch(cartViewModel.future);

    final options = _seedOptions(gates);
    final waived =
        cart.subtotal.amount >= 15000 ||
        cart.appliedPromo?.freeShipping == true;
    final requiresExpress =
        cart.appliedPromo?.code == 'SHIPFREE' && flow.isInternational;
    final initial = CheckoutShippingState(
      options: options,
      isInternational: flow.isInternational,
      subtotal: cart.subtotal,
      discount: cart.discount,
      focus: ShippingFocus.balanced,
      shippingWaived: waived,
      selectedId: flow.shippingMethodId,
      bannerMessage: _bannerMessage(flow.isInternational, gates),
      promoCode: cart.appliedPromo?.code,
      requiresExpress: requiresExpress,
      addressId: flow.addressId,
    );

    if (!_trackedStart) {
      _trackedStart = true;
      final analytics = ref.watch(analyticsClientProvider);
      unawaited(
        analytics.track(
          CheckoutStartedEvent(
            itemCount: cart.lines.length,
            subtotalAmount: cart.subtotal.amount,
            currency: cart.subtotal.currency,
            hasPromo: cart.appliedPromo != null,
            isInternational: flow.isInternational,
          ),
        ),
      );
    }

    return _resolveSelection(initial);
  }

  Call<ShippingSelectionResult> selectShipping(
    String optionId,
  ) => mutate(selectShippingMut, (ref) async {
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
    final current = ref.watch(this).valueOrNull;
    if (current == null) {
      return ShippingSelectionResult(
        error: prefersEnglish ? 'Missing state' : '状態を読み込めませんでした',
      );
    }

    if (!current.hasAddress) {
      return ShippingSelectionResult(
        error: prefersEnglish ? 'Select an address first.' : '先に配送先を選択してください。',
        selected: current.selectedOption,
        appliedCost: current.shippingCost,
      );
    }

    final option = current.visibleOptions.firstWhereOrNull(
      (item) => item.id == optionId,
    );
    if (option == null) {
      return ShippingSelectionResult(
        error: prefersEnglish
            ? 'Option unavailable for this address.'
            : 'この住所では利用できません。',
        selected: current.selectedOption,
        appliedCost: current.shippingCost,
      );
    }

    if (current.requiresExpress && !option.express) {
      return ShippingSelectionResult(
        error: prefersEnglish
            ? 'Promotion requires express shipping.'
            : 'クーポン適用には速達が必要です。',
        selected: current.selectedOption,
        appliedCost: current.shippingCost,
      );
    }

    final next = current.copyWith(selectedId: option.id);
    ref.state = AsyncData(_resolveSelection(next));

    try {
      await ref.invoke(
        checkoutFlowProvider.setShipping(
          shippingMethodId: option.id,
          shippingCost: current.effectiveCost(option),
          etaMinDays: option.minDays,
          etaMaxDays: option.maxDays,
        ),
      );
    } catch (error, stackTrace) {
      _shippingLogger.warning(
        'Failed to persist checkout shipping',
        error,
        stackTrace,
      );
    }

    final analytics = ref.watch(analyticsClientProvider);
    unawaited(
      analytics.track(
        CheckoutShippingSelectedEvent(
          shippingMethodId: option.id,
          carrier: option.carrier,
          costAmount: current.effectiveCost(option).amount,
          currency: current.effectiveCost(option).currency,
          etaMinDays: option.minDays,
          etaMaxDays: option.maxDays,
          isExpress: option.express,
          isInternational: option.international,
          focus: current.focus.name,
          hasPromo: current.promoCode != null,
        ),
      ),
    );

    return ShippingSelectionResult(
      selected: option,
      appliedCost: current.effectiveCost(option),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<ShippingFocus> setFocus(ShippingFocus focus) =>
      mutate(focusMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return focus;
        final next = _resolveSelection(current.copyWith(focus: focus));
        ref.state = AsyncData(next);
        return focus;
      });
}

CheckoutShippingState _resolveSelection(CheckoutShippingState state) {
  final visible = state.sortedOptions;
  if (visible.isEmpty) return state;

  final explicit = visible.firstWhereOrNull((item) {
    if (state.requiresExpress && !item.express) return false;
    return item.id == state.selectedId;
  });

  if (explicit != null) {
    return state.copyWith(selectedId: explicit.id);
  }

  final express = state.requiresExpress
      ? visible.firstWhereOrNull((item) => item.express)
      : null;
  final fallback = express ?? visible.first;
  return state.copyWith(selectedId: fallback.id);
}

List<ShippingOption> _seedOptions(AppExperienceGates gates) {
  final en = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;
  return [
    ShippingOption(
      id: 'dom-standard',
      label: en ? 'Yamato standard' : 'ヤマト通常便',
      carrier: en ? 'Yamato' : 'ヤマト運輸',
      cost: const Money(amount: 680, currency: 'JPY'),
      minDays: gates.isJapanRegion ? 2 : 3,
      maxDays: gates.isJapanRegion ? 4 : 6,
      international: false,
      note: en ? 'Weekends + tracking' : '土日配達・追跡付き',
      badge: intl ? null : (en ? 'Popular' : '人気'),
    ),
    ShippingOption(
      id: 'dom-express',
      label: en ? 'Express next-day' : '翌日お届け（速達）',
      carrier: en ? 'Yamato/JP Post' : 'ヤマト / 日本郵便',
      cost: const Money(amount: 1280, currency: 'JPY'),
      minDays: 1,
      maxDays: 2,
      international: false,
      express: true,
      note: en ? 'Best for promo codes requiring express.' : 'クーポン適用条件の速達はこちら。',
      badge: en ? 'Fastest' : '最短',
    ),
    ShippingOption(
      id: 'dom-pickup',
      label: en ? 'Convenience store pickup' : 'コンビニ受け取り',
      carrier: en ? 'Lawson/FamilyMart' : 'ローソン/ファミマ',
      cost: const Money(amount: 540, currency: 'JPY'),
      minDays: 3,
      maxDays: 5,
      international: false,
      note: en ? 'Held for 7 days at store.' : '店舗で7日間保管。',
    ),
    ShippingOption(
      id: 'intl-express',
      label: en ? 'Express courier' : '国際エクスプレス',
      carrier: en ? 'DHL / Yamato Global' : 'DHL・ヤマト国際',
      cost: const Money(amount: 5200, currency: 'JPY'),
      minDays: 3,
      maxDays: 6,
      international: true,
      express: true,
      note: en ? 'Includes customs pre-clearance.' : '通関前処理込み、追跡可。',
      badge: en ? 'Tracked' : '追跡',
    ),
    ShippingOption(
      id: 'intl-priority',
      label: en ? 'Priority air' : '優先航空便',
      carrier: en ? 'EMS' : 'EMS',
      cost: const Money(amount: 4200, currency: 'JPY'),
      minDays: 4,
      maxDays: 8,
      international: true,
      note: en ? 'Hands-on support for customs forms.' : '通関書類をサポート。',
    ),
    ShippingOption(
      id: 'intl-economy',
      label: en ? 'Economy air' : 'エコノミー航空便',
      carrier: en ? 'JP Post Air' : '日本郵便航空',
      cost: const Money(amount: 2800, currency: 'JPY'),
      minDays: 8,
      maxDays: 14,
      international: true,
      note: en ? 'Best for budget-friendly delivery.' : 'コスト重視の方向け。',
      badge: intl ? (en ? 'Popular' : '人気') : null,
    ),
  ];
}

String _bannerMessage(bool international, AppExperienceGates gates) {
  if (international) {
    return gates.prefersEnglish
        ? 'Customs screening is adding 1–2 days to some international deliveries.'
        : '通関強化により国際便で+1〜2日の遅延が発生しています。';
  }
  return gates.prefersEnglish
      ? 'Seasonal weather may delay Kyushu deliveries by half a day.'
      : '季節要因で九州方面は半日程度遅れる場合があります。';
}

final checkoutShippingViewModel = CheckoutShippingViewModel();
