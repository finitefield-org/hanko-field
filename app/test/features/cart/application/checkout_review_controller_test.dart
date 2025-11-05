import 'package:app/core/app_state/app_locale.dart';
import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/cart/application/cart_controller.dart';
import 'package:app/features/cart/application/cart_repository_provider.dart';
import 'package:app/features/cart/application/checkout_review_controller.dart';
import 'package:app/features/cart/application/checkout_state_controller.dart';
import 'package:app/features/cart/data/cart_repository.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_payment_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubExperienceGateNotifier extends ExperienceGateNotifier {
  _StubExperienceGateNotifier(this.gate);

  final ExperienceGate gate;

  @override
  Future<ExperienceGate> build() async => gate;
}

ExperienceGate _buildExperience() {
  return const ExperienceGate(
    locale: Locale('ja', 'JP'),
    systemLocale: Locale('ja', 'JP'),
    localeSource: AppLocaleSource.system,
    persona: UserPersona.japanese,
    region: ExperienceRegion.japanDomestic,
    currencyCode: 'JPY',
    currencySymbol: '¥',
    creationStages: <List<String>>[],
    creationSubtitle: '',
    shopSubtitle: '',
    ordersSubtitle: '',
    librarySubtitle: '',
    profileSubtitle: '',
  );
}

UserAddress _address() {
  return UserAddress(
    id: 'addr-1',
    recipient: 'Hanako Yamada',
    line1: '1-2-3 Ginza',
    city: 'Chuo',
    postalCode: '104-0061',
    country: 'JP',
    phone: '0312345678',
    isDefault: true,
    company: null,
    line2: null,
    state: 'Tokyo',
    label: 'Home',
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: null,
  );
}

CheckoutShippingOption _shippingOption() {
  return CheckoutShippingOption(
    id: 'domestic-standard',
    label: 'Standard shipping',
    summary: 'Delivers in 2-3 business days',
    estimatedDelivery: '2-3 business days',
    price: 1200,
    currency: 'JPY',
    region: CheckoutShippingRegion.domestic,
    speed: CheckoutShippingSpeed.standard,
  );
}

CheckoutPaymentMethodSummary _paymentMethod() {
  return CheckoutPaymentMethodSummary(
    id: 'pm_123',
    provider: PaymentProvider.stripe,
    methodType: PaymentMethodType.card,
    tokenStorageKey: 'stripe:pm_123',
    createdAt: DateTime.utc(2024, 1, 1),
    brand: 'Visa',
    last4: '4242',
    expMonth: 12,
    expYear: 2026,
    billingName: 'Hanako Yamada',
  );
}

class _TestLine {
  _TestLine({
    required this.cache,
    required this.title,
    required this.subtitle,
    required this.unitPrice,
    required this.thumbnailUrl,
  });

  final CartLineCache cache;
  final String title;
  final String subtitle;
  final double unitPrice;
  final String thumbnailUrl;

  double get lineTotal => unitPrice * cache.quantity;

  _TestLine copyWith({int? quantity}) {
    if (quantity == null) {
      return this;
    }
    return _TestLine(
      cache: CartLineCache(
        lineId: cache.lineId,
        productId: cache.productId,
        quantity: quantity,
        price: cache.price,
        currency: cache.currency,
        designSnapshot: cache.designSnapshot,
        addons: cache.addons,
      ),
      title: title,
      subtitle: subtitle,
      unitPrice: unitPrice,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

class _TestCartRepository implements CartRepository {
  _TestCartRepository()
    : _lines = [
        _TestLine(
          cache: CartLineCache(
            lineId: 'line-1',
            productId: 'titanium-hanko',
            quantity: 1,
            price: 16800,
            currency: 'JPY',
          ),
          title: 'チタン印鑑（マット）',
          subtitle: '耐久性◎ / 印相体 / 専用ケース付属',
          unitPrice: 16800,
          thumbnailUrl:
              'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=128',
        ),
      ];

  final List<_TestLine> _lines;
  CheckoutShippingOption? _selectedOption;

  List<CheckoutShippingOption> get _options => [
    CheckoutShippingOption(
      id: 'domestic-standard',
      label: '標準配送',
      summary: '2〜3営業日でお届け',
      estimatedDelivery: '2〜3営業日',
      price: 1200,
      currency: 'JPY',
      region: CheckoutShippingRegion.domestic,
      speed: CheckoutShippingSpeed.standard,
    ),
    CheckoutShippingOption(
      id: 'domestic-express',
      label: 'エクスプレス',
      summary: '翌日配送 / 時間帯指定',
      estimatedDelivery: '翌営業日',
      price: 2200,
      currency: 'JPY',
      region: CheckoutShippingRegion.domestic,
      speed: CheckoutShippingSpeed.express,
    ),
  ];

  CheckoutShippingOption get _effectiveOption =>
      _selectedOption ?? _options.first;

  @override
  Future<CartSnapshot> loadCart({required ExperienceGate experience}) async {
    _selectedOption ??= _options.first;
    return _buildSnapshot(experience);
  }

  CartSnapshot _buildSnapshot(
    ExperienceGate experience, {
    List<_TestLine>? linesOverride,
  }) {
    final lines = linesOverride ?? _lines;
    final cartLines = [
      for (final line in lines)
        CartLine(
          cache: line.cache,
          title: line.title,
          subtitle: line.subtitle,
          thumbnailUrl: line.thumbnailUrl,
          optionChips: const [],
          addons: const [],
          unitPrice: line.unitPrice,
          addonsTotal: 0,
          lineTotal: line.unitPrice * line.cache.quantity,
          currency: experience.currencyCode,
          estimatedLeadTime: experience.isInternational
              ? 'Ships in 5-7 business days'
              : '制作リードタイム: 5営業日',
          quantityWarning: null,
          lowStock: false,
        ),
    ];
    final subtotal = cartLines.fold<double>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    final shippingCost = lines.isEmpty ? 0.0 : _effectiveOption.price;
    final tax = lines.isEmpty ? 0.0 : (subtotal * 0.1);
    final estimate = CartEstimate(
      subtotal: subtotal,
      discount: 0,
      shipping: shippingCost,
      tax: tax,
      total: subtotal + shippingCost + tax,
      currency: experience.currencyCode,
      estimatedDelivery: _effectiveOption.estimatedDelivery,
    );
    return CartSnapshot(
      lines: cartLines,
      estimate: estimate,
      currency: experience.currencyCode,
      experience: experience,
      promotion: null,
      updatedAt: DateTime.now(),
      shippingOption: lines.isEmpty ? null : _effectiveOption,
    );
  }

  @override
  Future<CartSnapshot> setLineQuantity({
    required ExperienceGate experience,
    required String lineId,
    required int quantity,
  }) async {
    final index = _lines.indexWhere((line) => line.cache.lineId == lineId);
    if (index != -1) {
      _lines[index] = _lines[index].copyWith(quantity: quantity);
    }
    return _buildSnapshot(experience);
  }

  @override
  Future<CartSnapshot> removeLine({
    required ExperienceGate experience,
    required String lineId,
  }) async {
    _lines.removeWhere((line) => line.cache.lineId == lineId);
    return _buildSnapshot(experience);
  }

  @override
  Future<CartSnapshot> restoreLine({
    required ExperienceGate experience,
    required CartLineCache line,
    int? index,
  }) async {
    final restored = _TestLine(
      cache: line,
      title: '復元された商品',
      subtitle: 'サンプル概要',
      unitPrice: line.price ?? 10000,
      thumbnailUrl:
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=128',
    );
    if (index != null && index >= 0 && index <= _lines.length) {
      _lines.insert(index, restored);
    } else {
      _lines.add(restored);
    }
    return _buildSnapshot(experience);
  }

  @override
  Future<CartSnapshot> applyPromotion({
    required ExperienceGate experience,
    required String promoCode,
  }) async {
    return _buildSnapshot(experience);
  }

  @override
  Future<CartSnapshot> removePromotion({
    required ExperienceGate experience,
  }) async {
    return _buildSnapshot(experience);
  }

  @override
  Future<CheckoutShippingOptionsData> fetchShippingOptions({
    required ExperienceGate experience,
  }) async {
    return CheckoutShippingOptionsData(
      options: _options,
      selectedOptionId: _selectedOption?.id,
    );
  }

  @override
  Future<CartSnapshot> selectShippingOption({
    required ExperienceGate experience,
    required String optionId,
  }) async {
    _selectedOption = _options.firstWhere((option) => option.id == optionId);
    return _buildSnapshot(experience);
  }

  @override
  Future<CheckoutOrderReceipt> placeOrder({
    required ExperienceGate experience,
    required CheckoutState checkoutState,
    String? specialInstructions,
  }) async {
    if (!checkoutState.hasSelectedAddress) {
      throw CheckoutSubmissionException('配送先住所が未選択です。');
    }
    if (!checkoutState.hasSelectedShippingOption) {
      throw CheckoutSubmissionException('配送方法が未選択です。');
    }
    if (!checkoutState.hasSelectedPaymentMethod) {
      throw CheckoutSubmissionException('支払い方法が未選択です。');
    }
    if (_lines.isEmpty) {
      throw CheckoutSubmissionException('カートに商品がありません。');
    }
    final snapshot = _buildSnapshot(experience);
    final note = specialInstructions?.trim();
    final cleared = _buildSnapshot(
      experience,
      linesOverride: const <_TestLine>[],
    );
    _lines.clear();
    final receipt = CheckoutOrderReceipt(
      orderId: 'HF-${DateTime.now().millisecondsSinceEpoch}',
      placedAt: DateTime.now(),
      total: snapshot.estimate.total,
      currency: snapshot.estimate.currency,
      updatedCart: cleared,
      estimatedDelivery: snapshot.shippingOption?.estimatedDelivery,
      note: (note != null && note.isNotEmpty) ? note : null,
    );
    return receipt;
  }
}

void main() {
  group('CheckoutReviewController', () {
    test('emits error when selections are incomplete', () async {
      final experience = _buildExperience();
      final repository = _TestCartRepository();
      final container = ProviderContainer(
        overrides: [
          experienceGateProvider.overrideWith(
            () => _StubExperienceGateNotifier(experience),
          ),
          cartRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartControllerProvider.future);
      final controller = container.read(
        checkoutReviewControllerProvider.notifier,
      );

      await controller.placeOrder();
      final state = container.read(checkoutReviewControllerProvider);

      expect(state.errorMessage, isNotNull);
      expect(state.successMessage, isNull);
      expect(state.lastReceipt, isNull);
    });

    test('places order successfully and clears checkout state', () async {
      final experience = _buildExperience();
      final repository = _TestCartRepository();
      final container = ProviderContainer(
        overrides: [
          experienceGateProvider.overrideWith(
            () => _StubExperienceGateNotifier(experience),
          ),
          cartRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cartControllerProvider.future);

      final checkoutNotifier = container.read(checkoutStateProvider.notifier);
      checkoutNotifier.setSelectedAddress(_address());
      checkoutNotifier.setShippingOption(_shippingOption());
      checkoutNotifier.setPaymentMethod(_paymentMethod());

      final controller = container.read(
        checkoutReviewControllerProvider.notifier,
      );

      await controller.placeOrder(instructions: 'Keep outer box intact');
      final state = container.read(checkoutReviewControllerProvider);
      final cartState = container.read(cartControllerProvider).value;
      final checkoutState = container.read(checkoutStateProvider);

      expect(state.successMessage, isNotNull);
      expect(state.errorMessage, isNull);
      expect(state.lastReceipt, isA<CheckoutOrderReceipt>());
      expect(state.lastReceipt?.note, 'Keep outer box intact');
      expect(cartState?.lines, isEmpty);
      expect(checkoutState.hasSelectedAddress, isFalse);
      expect(checkoutState.hasSelectedShippingOption, isFalse);
      expect(checkoutState.hasSelectedPaymentMethod, isFalse);
    });
  });
}
