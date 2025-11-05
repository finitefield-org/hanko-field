import 'dart:async';
import 'dart:math';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/storage/offline_cache_repository.dart';
import 'package:app/features/cart/domain/cart_models.dart';
import 'package:app/features/cart/domain/checkout_models.dart';
import 'package:app/features/cart/domain/checkout_shipping_models.dart';

abstract class CartRepository {
  Future<CartSnapshot> loadCart({required ExperienceGate experience});

  Future<CartSnapshot> setLineQuantity({
    required ExperienceGate experience,
    required String lineId,
    required int quantity,
  });

  Future<CartSnapshot> removeLine({
    required ExperienceGate experience,
    required String lineId,
  });

  Future<CartSnapshot> restoreLine({
    required ExperienceGate experience,
    required CartLineCache line,
    int? index,
  });

  Future<CartSnapshot> applyPromotion({
    required ExperienceGate experience,
    required String promoCode,
  });

  Future<CartSnapshot> removePromotion({required ExperienceGate experience});

  Future<CheckoutShippingOptionsData> fetchShippingOptions({
    required ExperienceGate experience,
  });

  Future<CartSnapshot> selectShippingOption({
    required ExperienceGate experience,
    required String optionId,
  });

  Future<CheckoutOrderReceipt> placeOrder({
    required ExperienceGate experience,
    required CheckoutState checkoutState,
    String? specialInstructions,
  });
}

class FakeCartRepository implements CartRepository {
  FakeCartRepository(
    this._cache, {
    Duration artificialDelay = const Duration(milliseconds: 220),
  }) : _delay = artificialDelay;

  final OfflineCacheRepository _cache;
  final Duration _delay;

  @override
  Future<CartSnapshot> loadCart({required ExperienceGate experience}) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final bundle = _updateAndBuild(raw, experience);
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CartSnapshot> setLineQuantity({
    required ExperienceGate experience,
    required String lineId,
    required int quantity,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final lines = List<CartLineCache>.from(raw.lines);
    final index = lines.indexWhere((line) => line.lineId == lineId);
    if (index == -1) {
      throw StateError('Cart line $lineId not found');
    }
    final clamped = max(1, min(99, quantity));
    final existing = lines[index];
    lines[index] = CartLineCache(
      lineId: existing.lineId,
      productId: existing.productId,
      quantity: clamped,
      designSnapshot: existing.designSnapshot,
      price: existing.price,
      currency: existing.currency,
      addons: existing.addons,
    );
    final bundle = _updateAndBuild(raw.copyWith(lines: lines), experience);
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CartSnapshot> removeLine({
    required ExperienceGate experience,
    required String lineId,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final lines = raw.lines.where((line) => line.lineId != lineId).toList();
    final bundle = _updateAndBuild(raw.copyWith(lines: lines), experience);
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CartSnapshot> restoreLine({
    required ExperienceGate experience,
    required CartLineCache line,
    int? index,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final lines = List<CartLineCache>.from(raw.lines);
    final existingIndex = lines.indexWhere(
      (element) => element.lineId == line.lineId,
    );
    if (existingIndex >= 0) {
      lines[existingIndex] = line;
    } else if (index != null && index >= 0 && index <= lines.length) {
      lines.insert(index, line);
    } else {
      lines.add(line);
    }
    final bundle = _updateAndBuild(raw.copyWith(lines: lines), experience);
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CartSnapshot> applyPromotion({
    required ExperienceGate experience,
    required String promoCode,
  }) async {
    await Future<void>.delayed(_delay);
    final normalized = promoCode.trim().toUpperCase();
    final definition = _promotionDefinitions[normalized];
    if (definition == null) {
      throw CartPromotionException(
        experience.isInternational
            ? 'Promo code not recognized.'
            : 'プロモコードが見つかりません。',
      );
    }
    final raw = await _ensureSnapshot(experience);
    final current = _updateAndBuild(raw, experience);
    final subtotal = current.view.estimate.subtotal;
    if (!definition.isEligible(experience: experience, subtotal: subtotal)) {
      final threshold = experience.isInternational
          ? definition.minimumSubtotalUsd
          : definition.minimumSubtotalJpy;
      final message = experience.isInternational
          ? 'Requires at least ${_formatCurrency(threshold, experience)} merchandise subtotal.'
          : '小計が${_formatCurrency(threshold, experience)}以上の場合に利用できます。';
      throw CartPromotionException(message);
    }
    final promotion = definition.toCache(experience);
    final bundle = _updateAndBuild(
      current.raw.copyWith(promotion: promotion),
      experience,
    );
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CartSnapshot> removePromotion({
    required ExperienceGate experience,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final bundle = _updateAndBuild(raw.copyWith(promotion: null), experience);
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CheckoutShippingOptionsData> fetchShippingOptions({
    required ExperienceGate experience,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final bundle = _updateAndBuild(raw, experience);
    await _cache.writeCart(bundle.raw);
    final subtotal = bundle.view.estimate.subtotal;
    final promotion = bundle.raw.promotion;
    final selectedId =
        bundle.raw.shippingOptionId ?? bundle.view.shippingOption?.id;
    final advisory = _activeShippingAdvisory(experience);
    final options = <CheckoutShippingOption>[];
    final code = (promotion?['code'] as String?)?.toUpperCase();
    final type = promotion?['type'] as String?;
    final hasFreeShippingPromo = type == 'free_shipping';
    for (final definition in _shippingOptions.values) {
      if (!_supportsExperience(definition, experience)) {
        continue;
      }
      final threshold = experience.isInternational
          ? definition.freeThresholdUsd
          : definition.freeThresholdJpy;
      final thresholdApplied =
          subtotal > 0 && threshold != null && subtotal >= threshold;
      final basePrice = subtotal <= 0
          ? 0.0
          : thresholdApplied
          ? 0.0
          : (experience.isInternational
                ? definition.baseCostUsd
                : definition.baseCostJpy);
      var price = basePrice;
      String? promoMessage;
      if (hasFreeShippingPromo &&
          definition.speed == CheckoutShippingSpeed.express) {
        if (price > 0) {
          promoMessage = experience.isInternational
              ? '$code applied: express shipping covered'
              : '$code 適用中: エクスプレス送料無料';
        }
        price = 0.0;
      }
      final thresholdValue = threshold ?? 0;
      final thresholdMessage = thresholdApplied
          ? (experience.isInternational
                ? 'Free over ${_formatCurrency(thresholdValue, experience)} subtotal'
                : '小計が${_formatCurrency(thresholdValue, experience)}以上で送料無料')
          : null;
      options.add(
        definition.toDomain(
          experience: experience,
          price: price,
          thresholdMessage: thresholdMessage,
          promoMessage: promoMessage,
        ),
      );
    }
    return CheckoutShippingOptionsData(
      options: options,
      selectedOptionId: selectedId,
      advisory: advisory,
    );
  }

  @override
  Future<CartSnapshot> selectShippingOption({
    required ExperienceGate experience,
    required String optionId,
  }) async {
    await Future<void>.delayed(_delay);
    final raw = await _ensureSnapshot(experience);
    final definition = _resolveShippingDefinition(optionId, experience);
    final restriction = _validateShippingRestriction(
      experience: experience,
      promotion: raw.promotion,
      option: definition,
    );
    if (restriction != null) {
      throw CheckoutShippingException(restriction);
    }
    final bundle = _updateAndBuild(
      raw.copyWith(shippingOptionId: definition.id),
      experience,
    );
    await _cache.writeCart(bundle.raw);
    return bundle.view;
  }

  @override
  Future<CheckoutOrderReceipt> placeOrder({
    required ExperienceGate experience,
    required CheckoutState checkoutState,
    String? specialInstructions,
  }) async {
    await Future<void>.delayed(_delay);
    if (!checkoutState.hasSelectedAddress) {
      throw CheckoutSubmissionException(
        experience.isInternational
            ? 'Add a shipping address before placing your order.'
            : '注文する前に配送先住所を確定してください。',
      );
    }
    if (!checkoutState.hasSelectedShippingOption) {
      throw CheckoutSubmissionException(
        experience.isInternational
            ? 'Select a shipping option before placing your order.'
            : '注文する前に配送方法を選択してください。',
      );
    }
    if (!checkoutState.hasSelectedPaymentMethod) {
      throw CheckoutSubmissionException(
        experience.isInternational
            ? 'Select a payment method before placing your order.'
            : '注文する前にお支払い方法を選択してください。',
      );
    }

    final raw = await _ensureSnapshot(experience);
    final bundle = _updateAndBuild(raw, experience);
    if (bundle.view.lines.isEmpty) {
      throw CheckoutSubmissionException(
        experience.isInternational ? 'Your cart is empty.' : 'カートに商品がありません。',
      );
    }

    final note = specialInstructions?.trim();
    final orderId = _generateOrderId();
    final estimate = bundle.view.estimate;
    final shippingEta = bundle.view.shippingOption?.estimatedDelivery;

    final cleared = CachedCartSnapshot(
      lines: const [],
      currency: estimate.currency,
      subtotal: 0,
      total: 0,
      discount: 0,
      shipping: 0,
      tax: 0,
      promotion: null,
      updatedAt: DateTime.now(),
      shippingOptionId: null,
    );
    final clearedBundle = _updateAndBuild(cleared, experience);
    await _cache.writeCart(clearedBundle.raw);

    return CheckoutOrderReceipt(
      orderId: orderId,
      placedAt: DateTime.now(),
      total: estimate.total,
      currency: estimate.currency,
      orderSnapshot: bundle.view,
      updatedCart: clearedBundle.view,
      estimatedDelivery: shippingEta,
      note: (note != null && note.isNotEmpty) ? note : null,
      shippingAddress: checkoutState.selectedShippingAddress,
      paymentMethod: checkoutState.selectedPaymentMethod,
    );
  }

  String _generateOrderId() {
    final timestamp = DateTime.now();
    final random = Random(timestamp.millisecondsSinceEpoch);
    final suffix = random.nextInt(9000) + 1000;
    return 'HF-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-$suffix';
  }

  Future<CachedCartSnapshot> _ensureSnapshot(ExperienceGate experience) async {
    final stored = await _cache.readCart();
    if (stored.value != null) {
      return stored.value!;
    }
    final seeded = _seedSnapshot(experience);
    await _cache.writeCart(seeded);
    return seeded;
  }

  _SnapshotBundle _updateAndBuild(
    CachedCartSnapshot raw,
    ExperienceGate experience,
  ) {
    final lines = [for (final line in raw.lines) _buildLine(line, experience)];
    final initialShippingId =
        raw.shippingOptionId ?? _defaultShippingOptionId(experience);
    final estimate = _calculateEstimate(
      lines: lines,
      promotion: raw.promotion,
      experience: experience,
      shippingOptionId: initialShippingId,
    );
    final updated = raw.copyWith(
      subtotal: estimate.estimate.subtotal,
      total: estimate.estimate.total,
      discount: estimate.estimate.discount,
      shipping: estimate.estimate.shipping,
      tax: estimate.estimate.tax,
      promotion: raw.promotion,
      updatedAt: DateTime.now(),
      shippingOptionId: estimate.resolvedOptionId,
    );
    final snapshot = CartSnapshot(
      lines: lines,
      estimate: estimate.estimate,
      currency: estimate.estimate.currency,
      experience: experience,
      promotion: estimate.promotion,
      updatedAt: updated.updatedAt,
      shippingOption: estimate.shippingOption,
    );
    return _SnapshotBundle(updated, snapshot);
  }

  CartLine _buildLine(CartLineCache cache, ExperienceGate experience) {
    final catalogEntry =
        _cartCatalog[cache.productId] ??
        (experience.isInternational ? _fallbackIntl : _fallbackDomestic);
    final localized = catalogEntry.localize(
      experience: experience,
      quantity: cache.quantity,
    );
    final addons = _extractAddons(cache);
    final addonsTotal = addons.fold<double>(
      0,
      (sum, addon) => sum + addon.price,
    );
    final currency = cache.currency ?? localized.currency;
    final unitPrice = cache.price ?? localized.unitPrice;
    final optionChips = [
      ...localized.optionChips,
      ..._extractOptionChips(cache),
    ];
    final leadTime = localized.estimatedLeadTime;
    final quantityWarning = localized.quantityWarning;

    return CartLine(
      cache: cache,
      title: localized.title,
      subtitle: localized.subtitle,
      thumbnailUrl: localized.thumbnailUrl,
      optionChips: optionChips,
      addons: addons,
      unitPrice: unitPrice,
      addonsTotal: addonsTotal,
      lineTotal: unitPrice * cache.quantity + addonsTotal,
      currency: currency,
      estimatedLeadTime: leadTime,
      quantityWarning: quantityWarning,
      lowStock: localized.lowStock,
    );
  }

  List<CartAddon> _extractAddons(CartLineCache cache) {
    final addons = cache.addons;
    if (addons == null) {
      return const [];
    }
    final details =
        (addons['selectedAddonDetails'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
    return [
      for (final detail in details)
        CartAddon(
          id: detail['id'] as String? ?? 'addon-${detail.hashCode}',
          name: detail['name'] as String? ?? 'Accessory',
          price: (detail['price'] as num?)?.toDouble() ?? 0,
          currency: detail['currency'] as String? ?? cache.currency ?? 'JPY',
          category: detail['category'] as String?,
        ),
    ];
  }

  List<String> _extractOptionChips(CartLineCache cache) {
    final addons = cache.addons;
    if (addons == null) {
      return const [];
    }
    final selectedOptions =
        addons['selectedOptions'] as Map<String, dynamic>? ?? const {};
    if (selectedOptions.isEmpty) {
      return const [];
    }
    final chips = <String>[];
    selectedOptions.forEach((key, value) {
      chips.add(value.toString());
    });
    return chips;
  }

  CachedCartSnapshot _seedSnapshot(ExperienceGate experience) {
    final lines = experience.isInternational
        ? _seedInternationalLines()
        : _seedDomesticLines();
    return CachedCartSnapshot(
      lines: lines,
      currency: experience.isInternational ? 'USD' : 'JPY',
      updatedAt: DateTime.now(),
      shippingOptionId: _defaultShippingOptionId(experience),
    );
  }

  List<CartLineCache> _seedDomesticLines() {
    return [
      CartLineCache(
        lineId: 'line-echizen-case',
        productId: 'echizen-case',
        quantity: 1,
        price: 13800.0,
        currency: 'JPY',
        addons: {
          'selectedAddonIds': ['ink-cartridge-pack'],
          'selectedAddonCount': 1,
          'selectedAddonDetails': [
            {
              'id': 'ink-cartridge-pack',
              'name': '朱肉カートリッジ補充セット',
              'price': 2200,
              'currency': 'JPY',
              'category': 'maintenance',
            },
          ],
          'selectedAddonTotalAmount': 2200,
          'selectedAddonCurrency': 'JPY',
          'selectedOptions': {'size': '対応サイズ: 12mm', 'lining': '内張り: 朱色ベルベット'},
        },
      ),
      CartLineCache(
        lineId: 'line-titanium-hanko',
        productId: 'titanium-hanko',
        quantity: 2,
        price: 16800.0,
        currency: 'JPY',
        addons: {
          'selectedOptions': {'font': '書体: 印相体', 'finish': '仕上げ: マット'},
        },
      ),
    ];
  }

  List<CartLineCache> _seedInternationalLines() {
    return [
      CartLineCache(
        lineId: 'line-intl-kit',
        productId: 'intl-kit',
        quantity: 1,
        price: 248.0,
        currency: 'USD',
        addons: {
          'selectedAddonIds': ['intl-guidebook'],
          'selectedAddonCount': 1,
          'selectedAddonDetails': [
            {
              'id': 'intl-guidebook',
              'name': 'Bilingual Cultural Guide',
              'price': 24,
              'currency': 'USD',
              'category': 'guide',
            },
          ],
          'selectedAddonTotalAmount': 24,
          'selectedAddonCurrency': 'USD',
          'selectedOptions': {
            'case': 'Case: Indigo Travel Pouch',
            'ink': 'Ink: Quick-dry Sakura',
          },
        },
      ),
      CartLineCache(
        lineId: 'line-travel-case',
        productId: 'travel-case',
        quantity: 1,
        price: 88.0,
        currency: 'USD',
        addons: {
          'selectedOptions': {
            'size': 'Fits 12-15mm Seals',
            'lining': 'Lining: Midnight Blue',
          },
        },
      ),
    ];
  }

  String _formatCurrency(double? amount, ExperienceGate experience) {
    final symbol = experience.isInternational ? r'$' : '¥';
    if (amount == null) {
      return '${symbol}0';
    }
    final decimals = experience.isInternational ? 2 : 0;
    final formatted = amount.toStringAsFixed(decimals);
    return '$symbol$formatted';
  }

  CheckoutShippingAdvisory? _activeShippingAdvisory(ExperienceGate experience) {
    if (experience.isInternational) {
      return const CheckoutShippingAdvisory(
        title: 'Service advisory',
        message:
            'Customs inspections in EU hubs are adding 1‑2 business days. '
            'Please allow additional time for priority packages.',
        level: CheckoutShippingAdvisoryLevel.warning,
      );
    }
    return const CheckoutShippingAdvisory(
      title: '配送のお知らせ',
      message: '関東エリアでの強風により一部でお届けが通常より1日遅れる可能性があります。',
      level: CheckoutShippingAdvisoryLevel.warning,
    );
  }

  bool _supportsExperience(
    _ShippingOptionDefinition definition,
    ExperienceGate experience,
  ) {
    return experience.isInternational
        ? definition.region == CheckoutShippingRegion.international
        : definition.region == CheckoutShippingRegion.domestic;
  }

  _ShippingOptionDefinition _resolveShippingDefinition(
    String optionId,
    ExperienceGate experience,
  ) {
    final definition = _shippingOptions[optionId];
    if (definition != null && _supportsExperience(definition, experience)) {
      return definition;
    }
    final fallbackId = _defaultShippingOptionId(experience);
    return _shippingOptions[fallbackId]!;
  }

  String _defaultShippingOptionId(ExperienceGate experience) {
    return experience.isInternational ? 'intl-priority' : 'domestic-standard';
  }

  String? _validateShippingRestriction({
    required ExperienceGate experience,
    required Map<String, dynamic>? promotion,
    required _ShippingOptionDefinition option,
  }) {
    final code = (promotion?['code'] as String?)?.toUpperCase();
    final type = promotion?['type'] as String?;
    final requiresExpress = code == 'FREESHIP' && type == 'free_shipping';
    if (requiresExpress && option.speed != CheckoutShippingSpeed.express) {
      return experience.isInternational
          ? 'FREESHIP covers express courier only. Select the express option to keep the benefit.'
          : '送料無料コード（FREESHIP）はエクスプレス便でのみご利用いただけます。';
    }
    return null;
  }

  _EstimateComputation _calculateEstimate({
    required List<CartLine> lines,
    required Map<String, dynamic>? promotion,
    required ExperienceGate experience,
    required String shippingOptionId,
  }) {
    final currency = experience.isInternational ? 'USD' : 'JPY';
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    var discount = 0.0;
    CartPromotion? promo;
    final resolvedOption = _resolveShippingDefinition(
      shippingOptionId,
      experience,
    );
    final threshold = experience.isInternational
        ? resolvedOption.freeThresholdUsd
        : resolvedOption.freeThresholdJpy;
    final thresholdApplied =
        subtotal > 0 && threshold != null && subtotal >= threshold;
    final baseShipping = subtotal <= 0
        ? 0.0
        : thresholdApplied
        ? 0.0
        : (experience.isInternational
              ? resolvedOption.baseCostUsd
              : resolvedOption.baseCostJpy);
    var shipping = baseShipping;
    double shippingSavings = 0.0;

    final code = (promotion?['code'] as String?)?.toUpperCase();
    final type = promotion?['type'] as String?;
    final value = (promotion?['value'] as num?)?.toDouble() ?? 0;
    if (promotion != null && promotion.isNotEmpty) {
      switch (type) {
        case 'percentage':
          discount = subtotal * (value / 100);
          break;
        case 'flat':
          discount = min(value, subtotal).toDouble();
          break;
        case 'free_shipping':
          shippingSavings = shipping;
          shipping = 0.0;
          break;
        default:
          discount = subtotal * (value / 100);
          break;
      }
      final definition = code != null ? _promotionDefinitions[code] : null;
      final savings = type == 'free_shipping' ? shippingSavings : discount;
      if (definition != null) {
        promo = definition.toDomain(
          experience: experience,
          savingsAmount: savings,
          currency: currency,
        );
      } else if (code != null) {
        final summary = experience.isInternational
            ? '$code applied'
            : '$code を適用しました';
        promo = CartPromotion(
          code: code,
          summary: summary,
          savingsAmount: savings,
          currency: currency,
        );
      }
    }
    final taxable = max(0.0, subtotal - discount);
    final taxRate = experience.isInternational ? 0.0 : 0.1;
    final tax = taxable * taxRate;
    final total = max(0.0, taxable + shipping + tax);
    final thresholdValue = threshold ?? 0;
    final thresholdMessage = thresholdApplied
        ? (experience.isInternational
              ? 'Free over ${_formatCurrency(thresholdValue, experience)} subtotal'
              : '小計が${_formatCurrency(thresholdValue, experience)}以上で送料無料')
        : null;
    final promoMessage = shipping <= 0 && shippingSavings > 0 && code != null
        ? (experience.isInternational
              ? '$code applied: express shipping covered'
              : '$code 適用中: エクスプレス送料無料')
        : null;
    final shippingOption = resolvedOption.toDomain(
      experience: experience,
      price: shipping,
      thresholdMessage: thresholdMessage,
      promoMessage: promoMessage,
    );
    final estimate = CartEstimate(
      subtotal: subtotal,
      discount: discount,
      shipping: shipping,
      tax: tax,
      total: total,
      currency: currency,
      estimatedDelivery: shippingOption.estimatedDelivery,
    );
    return _EstimateComputation(
      estimate: estimate,
      promotion: promo,
      shippingOption: shippingOption,
      resolvedOptionId: resolvedOption.id,
    );
  }

  static final Map<String, _ShippingOptionDefinition> _shippingOptions =
      <String, _ShippingOptionDefinition>{
        'domestic-standard': const _ShippingOptionDefinition(
          id: 'domestic-standard',
          region: CheckoutShippingRegion.domestic,
          speed: CheckoutShippingSpeed.standard,
          baseCostJpy: 880.0,
          baseCostUsd: 6.8,
          labelJa: '通常便（ヤマト宅急便）',
          labelEn: 'Domestic standard (Yamato)',
          summaryJa: '追跡・時間指定対応',
          summaryEn: 'Tracking • evening delivery slots',
          etaJa: '発送後2〜3営業日',
          etaEn: 'Ships next day • delivery in 2‑3 business days',
          perksJa: ['追跡番号', '時間指定'],
          perksEn: ['Tracking', 'Time slots'],
          badgeJa: 'おすすめ',
          badgeEn: 'Best value',
          freeThresholdJpy: 20000.0,
          freeThresholdUsd: 150.0,
          recommendedDomestic: true,
        ),
        'domestic-express': const _ShippingOptionDefinition(
          id: 'domestic-express',
          region: CheckoutShippingRegion.domestic,
          speed: CheckoutShippingSpeed.express,
          baseCostJpy: 1400.0,
          baseCostUsd: 10.5,
          labelJa: 'エクスプレス便（翌日午前着）',
          labelEn: 'Domestic express AM delivery',
          summaryJa: '午前中指定 / 補償付き',
          summaryEn: 'Morning delivery • insurance included',
          etaJa: '発送後1営業日以内',
          etaEn: 'Delivery by next business morning',
          perksJa: ['午前中お届け', '補償付き'],
          perksEn: ['Morning delivery', 'Insurance'],
          badgeJa: '最速',
          badgeEn: 'Fastest',
        ),
        'domestic-sameday': const _ShippingOptionDefinition(
          id: 'domestic-sameday',
          region: CheckoutShippingRegion.domestic,
          speed: CheckoutShippingSpeed.express,
          baseCostJpy: 2200.0,
          baseCostUsd: 17.5,
          labelJa: '当日バイク便（首都圏）',
          labelEn: 'Same-day courier (Tokyo)',
          summaryJa: '23区限定 / 置き配可',
          summaryEn: 'Tokyo 23 wards • leave-at-door option',
          etaJa: '最短3時間でお届け',
          etaEn: 'As fast as 3 hours',
          perksJa: ['首都圏限定', '置き配対応'],
          perksEn: ['Metro coverage', 'Drop-off allowed'],
        ),
        'intl-economy': const _ShippingOptionDefinition(
          id: 'intl-economy',
          region: CheckoutShippingRegion.international,
          speed: CheckoutShippingSpeed.economy,
          baseCostJpy: 3200.0,
          baseCostUsd: 18.0,
          labelJa: '国際エコノミー（SAL）',
          labelEn: 'International economy air',
          summaryJa: '追跡あり / 税関対応サポート',
          summaryEn: 'Tracking • customs assistance',
          etaJa: '発送後7〜12営業日',
          etaEn: 'Delivery in 7‑12 business days',
          perksJa: ['税関書類サポート'],
          perksEn: ['Customs paperwork support'],
          badgeJa: '節約',
          badgeEn: 'Saver',
        ),
        'intl-priority': const _ShippingOptionDefinition(
          id: 'intl-priority',
          region: CheckoutShippingRegion.international,
          speed: CheckoutShippingSpeed.standard,
          baseCostJpy: 4200.0,
          baseCostUsd: 24.0,
          labelJa: '国際優先便（EMS）',
          labelEn: 'International priority (EMS)',
          summaryJa: '追跡・補償付き / 配達6〜8日',
          summaryEn: 'Tracking & insurance • delivery in 5‑8 days',
          etaJa: '発送後5〜8営業日',
          etaEn: 'Ships within 2 days • arrives in 5‑8 business days',
          perksJa: ['補償付き', '土曜配送'],
          perksEn: ['Insurance', 'Saturday delivery'],
          badgeJa: '定番',
          badgeEn: 'Recommended',
          freeThresholdJpy: 35000.0,
          freeThresholdUsd: 250.0,
          recommendedInternational: true,
        ),
        'intl-express': const _ShippingOptionDefinition(
          id: 'intl-express',
          region: CheckoutShippingRegion.international,
          speed: CheckoutShippingSpeed.express,
          baseCostJpy: 6200.0,
          baseCostUsd: 42.0,
          labelJa: '国際エクスプレス（DHL）',
          labelEn: 'International express (DHL)',
          summaryJa: '税関前払い / 最速2〜3日',
          summaryEn: 'Customs pre-cleared • delivery in 2‑3 days',
          etaJa: '発送後2〜3営業日',
          etaEn: 'Delivery in 2‑3 business days',
          perksJa: ['税関前払い', '時間指定'],
          perksEn: ['Duties prepaid', 'Time slots'],
          badgeJa: 'グローバル最速',
          badgeEn: 'Fastest global',
        ),
      };

  static final Map<String, _CartCatalogEntry>
  _cartCatalog = <String, _CartCatalogEntry>{
    'echizen-case': const _CartCatalogEntry(
      productId: 'echizen-case',
      titleJa: '越前和紙ケース',
      titleEn: 'Echizen Washi Case',
      subtitleJa: '職人仕上げ / 朱肉付き / 贈答用に最適',
      subtitleEn: 'Artisan craft • Includes ink pad • Gift ready',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=600',
      unitPriceJpy: 13800.0,
      unitPriceUsd: 128.0,
      optionChipsJa: ['越前和紙', '朱色ベルベット'],
      optionChipsEn: ['Echizen paper', 'Vermilion velvet'],
      estimatedLeadTimeJa: '工房出荷: 3営業日以内',
      estimatedLeadTimeEn: 'Ships from workshop in 3 business days',
    ),
    'titanium-hanko': const _CartCatalogEntry(
      productId: 'titanium-hanko',
      titleJa: 'チタン印鑑（マット）',
      titleEn: 'Matte Titanium Seal',
      subtitleJa: '耐久性◎ / 印相体 / 専用ケース付属',
      subtitleEn: 'Durable titanium • Traditional font • Case included',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1512427691650-1e0c7a98a111?w=600',
      unitPriceJpy: 16800.0,
      unitPriceUsd: 158.0,
      optionChipsJa: ['印相体', 'マット加工'],
      optionChipsEn: ['Insho font', 'Matte finish'],
      estimatedLeadTimeJa: '制作リードタイム: 5営業日',
      estimatedLeadTimeEn: 'Crafting time: 5 business days',
      lowStock: true,
      quantityAlertThreshold: 3,
      quantityWarningJa: '3本以上は職人確認のため+1営業日',
      quantityWarningEn: '3+ pieces add 1 business day for QA',
    ),
    'intl-kit': const _CartCatalogEntry(
      productId: 'intl-kit',
      titleJa: 'International Signature Kit',
      titleEn: 'International Signature Kit',
      subtitleJa: '海外発送セット / 英文ガイド同梱',
      subtitleEn: 'All-in-one stamping kit with bilingual guide',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
      unitPriceJpy: 26800.0,
      unitPriceUsd: 248.0,
      optionChipsJa: ['トラベルポーチ', '速乾朱肉'],
      optionChipsEn: ['Travel pouch', 'Quick-dry ink'],
      estimatedLeadTimeJa: '国際発送: 5〜7営業日',
      estimatedLeadTimeEn: 'International shipping: 5‑7 business days',
    ),
    'travel-case': const _CartCatalogEntry(
      productId: 'travel-case',
      titleJa: 'トラベル印鑑ケース',
      titleEn: 'Travel Seal Case',
      subtitleJa: '耐衝撃シェル / 15mmまで収納可',
      subtitleEn: 'Impact resistant shell • Fits up to 15mm seals',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=600',
      unitPriceJpy: 9600.0,
      unitPriceUsd: 88.0,
      optionChipsJa: ['ミッドナイトブルー', '防滴仕様'],
      optionChipsEn: ['Midnight blue', 'Water resistant'],
      estimatedLeadTimeJa: '24時間以内に出荷',
      estimatedLeadTimeEn: 'Ships within 24 hours',
    ),
  };

  static const _CartCatalogEntry _fallbackDomestic = _CartCatalogEntry(
    productId: 'fallback-domestic',
    titleJa: '印鑑商品',
    titleEn: 'Hanko Item',
    subtitleJa: '詳細情報は準備中です',
    subtitleEn: 'Details coming soon',
    thumbnailUrl:
        'https://images.unsplash.com/photo-1523419409543-0c1df022bdd1?w=600',
    unitPriceJpy: 9800.0,
    unitPriceUsd: 92.0,
    optionChipsJa: [],
    optionChipsEn: [],
    estimatedLeadTimeJa: '通常発送: 3営業日',
    estimatedLeadTimeEn: 'Standard shipping: 3 business days',
  );

  static final _CartCatalogEntry _fallbackIntl = _cartCatalog['intl-kit']!;

  static final Map<String, _PromotionDefinition> _promotionDefinitions =
      <String, _PromotionDefinition>{
        'HANKO10': const _PromotionDefinition.percentage(
          code: 'HANKO10',
          value: 10,
          summaryJa: '春のキャンペーン 10% オフ',
          summaryEn: 'Spring campaign 10% off',
          detailJa: '印鑑・ケース本体が対象です。',
          detailEn: 'Applies to seals and cases in cart.',
        ),
        'FREESHIP': const _PromotionDefinition.freeShipping(
          code: 'FREESHIP',
          summaryJa: '送料無料コード',
          summaryEn: 'Free express shipping',
          detailJa: '国内外どちらの配送にも適用されます。',
          detailEn: 'Covers domestic & international shipping fees.',
        ),
        'WELCOME15': const _PromotionDefinition.flat(
          code: 'WELCOME15',
          valueJpy: 1500.0,
          valueUsd: 15.0,
          summaryJa: '初回購入 ¥1,500 オフ',
          summaryEn: 'First order \$15 off',
          detailJa: '小計が¥10,000以上の場合に適用。',
          detailEn: 'Applies on orders above \$90 merchandise subtotal.',
          minimumSubtotalJpy: 10000.0,
          minimumSubtotalUsd: 90.0,
        ),
      };
}

class CartPromotionException implements Exception {
  CartPromotionException(this.message);

  final String message;

  @override
  String toString() => 'CartPromotionException($message)';
}

class CheckoutShippingException implements Exception {
  CheckoutShippingException(this.message);

  final String message;

  @override
  String toString() => 'CheckoutShippingException($message)';
}

class CheckoutSubmissionException implements Exception {
  CheckoutSubmissionException(this.message);

  final String message;

  @override
  String toString() => 'CheckoutSubmissionException($message)';
}

class _SnapshotBundle {
  _SnapshotBundle(this.raw, this.view);

  final CachedCartSnapshot raw;
  final CartSnapshot view;
}

class _EstimateComputation {
  _EstimateComputation({
    required this.estimate,
    required this.shippingOption,
    required this.resolvedOptionId,
    this.promotion,
  });

  final CartEstimate estimate;
  final CheckoutShippingOption shippingOption;
  final String resolvedOptionId;
  final CartPromotion? promotion;
}

enum _PromotionType { percentage, flat, freeShipping }

class _ShippingOptionDefinition {
  const _ShippingOptionDefinition({
    required this.id,
    required this.region,
    required this.speed,
    required this.baseCostJpy,
    required this.baseCostUsd,
    required this.labelJa,
    required this.labelEn,
    required this.summaryJa,
    required this.summaryEn,
    required this.etaJa,
    required this.etaEn,
    this.perksJa = const <String>[],
    this.perksEn = const <String>[],
    this.badgeJa,
    this.badgeEn,
    this.freeThresholdJpy,
    this.freeThresholdUsd,
    this.recommendedDomestic = false,
    this.recommendedInternational = false,
  });

  final String id;
  final CheckoutShippingRegion region;
  final CheckoutShippingSpeed speed;
  final double baseCostJpy;
  final double baseCostUsd;
  final String labelJa;
  final String labelEn;
  final String summaryJa;
  final String summaryEn;
  final String etaJa;
  final String etaEn;
  final List<String> perksJa;
  final List<String> perksEn;
  final String? badgeJa;
  final String? badgeEn;
  final double? freeThresholdJpy;
  final double? freeThresholdUsd;
  final bool recommendedDomestic;
  final bool recommendedInternational;

  CheckoutShippingOption toDomain({
    required ExperienceGate experience,
    required double price,
    String? thresholdMessage,
    String? promoMessage,
  }) {
    final isIntl = experience.isInternational;
    final perks = <String>[...(isIntl ? perksEn : perksJa)];
    if (thresholdMessage != null) {
      perks.add(thresholdMessage);
    } else if (promoMessage != null) {
      perks.add(promoMessage);
    } else if (price <= 0) {
      perks.add(isIntl ? 'Free shipping' : '送料無料');
    }
    return CheckoutShippingOption(
      id: id,
      label: isIntl ? labelEn : labelJa,
      summary: isIntl ? summaryEn : summaryJa,
      estimatedDelivery: isIntl ? etaEn : etaJa,
      price: price,
      currency: isIntl ? 'USD' : 'JPY',
      region: region,
      speed: speed,
      perks: perks,
      badge: isIntl ? badgeEn : badgeJa,
      isRecommended: isIntl ? recommendedInternational : recommendedDomestic,
    );
  }
}

class _PromotionDefinition {
  const _PromotionDefinition._({
    required this.code,
    required this.type,
    this.percentage,
    this.valueJpy,
    this.valueUsd,
    required this.summaryJa,
    required this.summaryEn,
    this.detailJa,
    this.detailEn,
    this.minimumSubtotalJpy,
    this.minimumSubtotalUsd,
  });

  const _PromotionDefinition.percentage({
    required String code,
    required double value,
    required String summaryJa,
    required String summaryEn,
    String? detailJa,
    String? detailEn,
  }) : this._(
         code: code,
         type: _PromotionType.percentage,
         percentage: value,
         summaryJa: summaryJa,
         summaryEn: summaryEn,
         detailJa: detailJa,
         detailEn: detailEn,
       );

  const _PromotionDefinition.flat({
    required String code,
    required double valueJpy,
    required double valueUsd,
    required String summaryJa,
    required String summaryEn,
    String? detailJa,
    String? detailEn,
    double? minimumSubtotalJpy,
    double? minimumSubtotalUsd,
  }) : this._(
         code: code,
         type: _PromotionType.flat,
         valueJpy: valueJpy,
         valueUsd: valueUsd,
         summaryJa: summaryJa,
         summaryEn: summaryEn,
         detailJa: detailJa,
         detailEn: detailEn,
         minimumSubtotalJpy: minimumSubtotalJpy,
         minimumSubtotalUsd: minimumSubtotalUsd,
       );

  const _PromotionDefinition.freeShipping({
    required String code,
    required String summaryJa,
    required String summaryEn,
    String? detailJa,
    String? detailEn,
  }) : this._(
         code: code,
         type: _PromotionType.freeShipping,
         summaryJa: summaryJa,
         summaryEn: summaryEn,
         detailJa: detailJa,
         detailEn: detailEn,
       );

  final String code;
  final _PromotionType type;
  final double? percentage;
  final double? valueJpy;
  final double? valueUsd;
  final String summaryJa;
  final String summaryEn;
  final String? detailJa;
  final String? detailEn;
  final double? minimumSubtotalJpy;
  final double? minimumSubtotalUsd;

  Map<String, dynamic> toCache(ExperienceGate experience) {
    switch (type) {
      case _PromotionType.percentage:
        return {'code': code, 'type': 'percentage', 'value': percentage ?? 0};
      case _PromotionType.flat:
        return {
          'code': code,
          'type': 'flat',
          'value': experience.isInternational ? valueUsd : valueJpy,
          'minimumSubtotal': experience.isInternational
              ? minimumSubtotalUsd
              : minimumSubtotalJpy,
        };
      case _PromotionType.freeShipping:
        return {'code': code, 'type': 'free_shipping'};
    }
  }

  CartPromotion toDomain({
    required ExperienceGate experience,
    required double savingsAmount,
    required String currency,
  }) {
    final summary = experience.isInternational ? summaryEn : summaryJa;
    final detail = experience.isInternational ? detailEn : detailJa;
    return CartPromotion(
      code: code,
      summary: summary,
      savingsAmount: savingsAmount,
      currency: currency,
      detail: detail,
    );
  }

  bool isEligible({
    required ExperienceGate experience,
    required double subtotal,
  }) {
    if (type != _PromotionType.flat) {
      return true;
    }
    final minimum = experience.isInternational
        ? minimumSubtotalUsd
        : minimumSubtotalJpy;
    if (minimum == null) {
      return true;
    }
    return subtotal >= minimum;
  }
}

class _CartCatalogEntry {
  const _CartCatalogEntry({
    required this.productId,
    required this.titleJa,
    required this.titleEn,
    required this.subtitleJa,
    required this.subtitleEn,
    required this.thumbnailUrl,
    required this.unitPriceJpy,
    required this.unitPriceUsd,
    required this.optionChipsJa,
    required this.optionChipsEn,
    required this.estimatedLeadTimeJa,
    required this.estimatedLeadTimeEn,
    this.lowStock = false,
    this.quantityAlertThreshold,
    this.quantityWarningJa,
    this.quantityWarningEn,
  });

  final String productId;
  final String titleJa;
  final String titleEn;
  final String subtitleJa;
  final String subtitleEn;
  final String thumbnailUrl;
  final double unitPriceJpy;
  final double unitPriceUsd;
  final List<String> optionChipsJa;
  final List<String> optionChipsEn;
  final String estimatedLeadTimeJa;
  final String estimatedLeadTimeEn;
  final bool lowStock;
  final int? quantityAlertThreshold;
  final String? quantityWarningJa;
  final String? quantityWarningEn;

  _LocalizedCatalogEntry localize({
    required ExperienceGate experience,
    required int quantity,
  }) {
    final isIntl = experience.isInternational;
    final threshold = quantityAlertThreshold ?? 0;
    final exceedsThreshold = threshold > 0 && quantity >= threshold;
    return _LocalizedCatalogEntry(
      title: isIntl ? titleEn : titleJa,
      subtitle: isIntl ? subtitleEn : subtitleJa,
      thumbnailUrl: thumbnailUrl,
      optionChips: isIntl ? optionChipsEn : optionChipsJa,
      unitPrice: isIntl ? unitPriceUsd : unitPriceJpy,
      currency: isIntl ? 'USD' : 'JPY',
      estimatedLeadTime: isIntl ? estimatedLeadTimeEn : estimatedLeadTimeJa,
      lowStock: lowStock,
      quantityWarning: exceedsThreshold
          ? (isIntl ? quantityWarningEn : quantityWarningJa)
          : null,
    );
  }
}

class _LocalizedCatalogEntry {
  const _LocalizedCatalogEntry({
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.optionChips,
    required this.unitPrice,
    required this.currency,
    required this.estimatedLeadTime,
    required this.lowStock,
    required this.quantityWarning,
  });

  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final List<String> optionChips;
  final double unitPrice;
  final String currency;
  final String? estimatedLeadTime;
  final bool lowStock;
  final String? quantityWarning;
}
