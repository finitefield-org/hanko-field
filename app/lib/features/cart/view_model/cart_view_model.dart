// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/value_objects.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum CartAddonKind { option, addon }

class CartAddonOption {
  const CartAddonOption({
    required this.id,
    required this.label,
    this.description,
    this.price,
    this.badge,
    this.kind = CartAddonKind.addon,
  });

  final String id;
  final String label;
  final String? description;
  final Money? price;
  final String? badge;
  final CartAddonKind kind;
}

class CartLineItem {
  const CartLineItem({
    required this.id,
    required this.title,
    required this.variantLabel,
    required this.thumbnailUrl,
    required this.basePrice,
    required this.quantity,
    required this.addonOptions,
    required this.selectedAddonIds,
    required this.leadTimeMinDays,
    required this.leadTimeMaxDays,
    this.designLabel,
    this.note,
    this.ribbon,
    this.compareAtPrice,
  });

  final String id;
  final String title;
  final String variantLabel;
  final String thumbnailUrl;
  final Money basePrice;
  final int quantity;
  final List<CartAddonOption> addonOptions;
  final Set<String> selectedAddonIds;
  final int leadTimeMinDays;
  final int leadTimeMaxDays;
  final String? designLabel;
  final String? note;
  final String? ribbon;
  final Money? compareAtPrice;

  List<CartAddonOption> get selectedAddons =>
      addonOptions.where((item) => selectedAddonIds.contains(item.id)).toList();

  Money get addonsTotal {
    final total = selectedAddons.fold<num>(
      0,
      (sum, item) => sum + (item.price?.amount ?? 0),
    );
    return Money(amount: total.toInt(), currency: basePrice.currency);
  }

  Money get unitPrice => Money(
    amount: basePrice.amount + addonsTotal.amount,
    currency: basePrice.currency,
  );

  Money get lineTotal =>
      Money(amount: unitPrice.amount * quantity, currency: basePrice.currency);

  CartLineItem copyWith({int? quantity, Set<String>? selectedAddonIds}) {
    return CartLineItem(
      id: id,
      title: title,
      variantLabel: variantLabel,
      thumbnailUrl: thumbnailUrl,
      basePrice: basePrice,
      quantity: quantity ?? this.quantity,
      addonOptions: addonOptions,
      selectedAddonIds: selectedAddonIds ?? this.selectedAddonIds,
      leadTimeMinDays: leadTimeMinDays,
      leadTimeMaxDays: leadTimeMaxDays,
      designLabel: designLabel,
      note: note,
      ribbon: ribbon,
      compareAtPrice: compareAtPrice,
    );
  }
}

class CartPromo {
  const CartPromo({
    required this.code,
    required this.label,
    required this.appliedAmount,
    this.freeShipping = false,
    this.description,
  });

  final String code;
  final String label;
  final Money appliedAmount;
  final bool freeShipping;
  final String? description;
}

class CartEstimate {
  const CartEstimate({
    required this.minDays,
    required this.maxDays,
    required this.methodLabel,
    required this.international,
  });

  final int minDays;
  final int maxDays;
  final String methodLabel;
  final bool international;
}

class RemovedCartLine {
  const RemovedCartLine({required this.item, required this.index});

  final CartLineItem item;
  final int index;
}

class CartState {
  const CartState({
    required this.lines,
    required this.estimate,
    this.appliedPromo,
    this.promoError,
    this.pendingLineIds = const <String>{},
    this.recentlyRemoved,
    this.isApplyingPromo = false,
  });

  final List<CartLineItem> lines;
  final CartEstimate estimate;
  final CartPromo? appliedPromo;
  final String? promoError;
  final Set<String> pendingLineIds;
  final RemovedCartLine? recentlyRemoved;
  final bool isApplyingPromo;

  String get currency => lines.isEmpty ? 'JPY' : lines.first.basePrice.currency;

  Money get subtotal {
    final total = lines.fold<num>(
      0,
      (sum, item) => sum + item.lineTotal.amount,
    );
    return Money(amount: total.toInt(), currency: currency);
  }

  Money get discount {
    final amount = min(
      appliedPromo?.appliedAmount.amount ?? 0,
      subtotal.amount,
    );
    return Money(amount: amount, currency: currency);
  }

  Money get taxableSubtotal {
    final amount = max(0, subtotal.amount - discount.amount);
    return Money(amount: amount, currency: currency);
  }

  Money get shipping {
    final waived = appliedPromo?.freeShipping == true;
    if (waived || subtotal.amount >= 15000) {
      return Money(amount: 0, currency: currency);
    }
    final amount = estimate.international ? 2400 : 680;
    return Money(amount: amount, currency: currency);
  }

  Money get tax {
    final amount = (taxableSubtotal.amount * 0.1).round();
    return Money(amount: amount, currency: currency);
  }

  Money get total {
    final amount =
        subtotal.amount - discount.amount + shipping.amount + tax.amount;
    return Money(amount: amount, currency: currency);
  }

  int get itemCount =>
      lines.fold<int>(0, (count, item) => count + item.quantity);

  CartState copyWith({
    List<CartLineItem>? lines,
    CartEstimate? estimate,
    CartPromo? appliedPromo,
    bool clearPromo = false,
    String? promoError,
    Set<String>? pendingLineIds,
    RemovedCartLine? recentlyRemoved,
    bool? isApplyingPromo,
    bool clearRecentlyRemoved = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      estimate: estimate ?? this.estimate,
      appliedPromo: clearPromo ? null : appliedPromo ?? this.appliedPromo,
      promoError: promoError,
      pendingLineIds: pendingLineIds ?? this.pendingLineIds,
      recentlyRemoved: clearRecentlyRemoved
          ? null
          : (recentlyRemoved ?? this.recentlyRemoved),
      isApplyingPromo: isApplyingPromo ?? this.isApplyingPromo,
    );
  }
}

class CartViewModel extends AsyncProvider<CartState> {
  CartViewModel() : super.args(null, autoDispose: false);

  late final adjustQuantityMut = mutation<String>(#adjustQuantity);
  late final removeLineMut = mutation<String>(#removeLine);
  late final undoRemovalMut = mutation<void>(#undoRemoval);
  late final applyPromoMut = mutation<CartPromo?>(#applyPromo);
  late final updateAddonsMut = mutation<Set<String>>(#updateAddons);
  late final clearPromoMut = mutation<void>(#clearPromo);
  late final replaceLinesMut = mutation<List<CartLineItem>>(#replaceLines);

  @override
  Future<CartState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final lines = _seedLines(gates);
    return CartState(lines: lines, estimate: _estimateFor(lines, gates));
  }

  Call<String> adjustQuantity(String lineId, int delta) =>
      mutate(adjustQuantityMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return lineId;

        final pending = {...current.pendingLineIds, lineId};
        ref.state = AsyncData(
          current.copyWith(pendingLineIds: pending, promoError: null),
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));

        final gates = ref.watch(appExperienceGatesProvider);
        final updatedLines = current.lines.map((item) {
          if (item.id != lineId) return item;
          final nextQty = max(1, item.quantity + delta);
          return item.copyWith(quantity: nextQty);
        }).toList();

        pending.remove(lineId);
        ref.state = AsyncData(
          current.copyWith(
            lines: updatedLines,
            estimate: _estimateFor(updatedLines, gates),
            pendingLineIds: pending,
            promoError: null,
          ),
        );
        return lineId;
      }, concurrency: Concurrency.dropLatest);

  Call<String> removeLine(String lineId) => mutate(removeLineMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return lineId;
    final pending = {...current.pendingLineIds, lineId};
    ref.state = AsyncData(
      current.copyWith(pendingLineIds: pending, promoError: null),
    );

    await Future<void>.delayed(const Duration(milliseconds: 180));

    final index = current.lines.indexWhere((item) => item.id == lineId);
    if (index == -1) {
      ref.state = AsyncData(
        current.copyWith(pendingLineIds: pending..remove(lineId)),
      );
      return lineId;
    }

    final removed = current.lines[index];
    final updatedLines = [...current.lines]..removeAt(index);
    final gates = ref.watch(appExperienceGatesProvider);

    pending.remove(lineId);
    ref.state = AsyncData(
      current.copyWith(
        lines: updatedLines,
        estimate: _estimateFor(updatedLines, gates),
        pendingLineIds: pending,
        recentlyRemoved: RemovedCartLine(item: removed, index: index),
        promoError: null,
      ),
    );
    return lineId;
  });

  Call<void> undoRemoval() => mutate(undoRemovalMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final removed = current?.recentlyRemoved;
    if (current == null || removed == null) return;

    final insertIndex = min(removed.index, current.lines.length);
    final updated = [...current.lines]..insert(insertIndex, removed.item);
    final gates = ref.watch(appExperienceGatesProvider);

    ref.state = AsyncData(
      current.copyWith(
        lines: updated,
        estimate: _estimateFor(updated, gates),
        clearRecentlyRemoved: true,
        promoError: null,
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<CartPromo?> applyPromo(String rawCode) => mutate(applyPromoMut, (
    ref,
  ) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return null;

    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final code = rawCode.trim().toUpperCase();

    if (code.isEmpty) {
      ref.state = AsyncData(
        current.copyWith(
          promoError: prefersEnglish
              ? 'Enter a promo code'
              : 'クーポンコードを入力してください',
          isApplyingPromo: false,
        ),
      );
      return null;
    }

    ref.state = AsyncData(current.copyWith(isApplyingPromo: true));

    await Future<void>.delayed(const Duration(milliseconds: 200));

    final subtotal = current.subtotal;
    CartPromo? promo;
    String? error;

    switch (code) {
      case 'FIELD10':
        final amount = max(0, (subtotal.amount * 0.1).round());
        if (amount == 0) {
          error = prefersEnglish
              ? 'Add items before applying discounts.'
              : '商品を追加すると割引を適用できます。';
        } else {
          promo = CartPromo(
            code: code,
            label: prefersEnglish ? '10% off' : '10%オフ',
            description: prefersEnglish
                ? 'Applies to merchandise subtotal.'
                : '商品小計に適用されます。',
            appliedAmount: Money(amount: amount, currency: subtotal.currency),
          );
        }
        break;
      case 'SHIPFREE':
        final threshold = 9000;
        if (subtotal.amount < threshold) {
          final shortfall = threshold - subtotal.amount;
          error = prefersEnglish
              ? 'Add ¥${shortfall.toString()} more to unlock free shipping.'
              : 'あと¥${shortfall.toString()}で送料無料になります。';
        } else {
          promo = CartPromo(
            code: code,
            label: prefersEnglish ? 'Free shipping' : '送料無料',
            freeShipping: true,
            appliedAmount: Money(amount: 0, currency: subtotal.currency),
          );
        }
        break;
      case 'INK200':
        promo = CartPromo(
          code: code,
          label: prefersEnglish ? 'Ink set bonus' : '朱肉セット優待',
          description: prefersEnglish
              ? '¥200 off for ink/accessory bundles.'
              : 'インクやアクセサリーの同梱で¥200オフ。',
          appliedAmount: Money(amount: 200, currency: subtotal.currency),
        );
        break;
      default:
        error = prefersEnglish ? 'Invalid or expired code.' : 'コードが無効か期限切れです。';
    }

    ref.state = AsyncData(
      current.copyWith(
        appliedPromo: promo,
        promoError: error,
        isApplyingPromo: false,
      ),
    );
    return promo;
  }, concurrency: Concurrency.dropLatest);

  Call<Set<String>> updateAddons(String lineId, Set<String> selection) =>
      mutate(updateAddonsMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return selection;

        final pending = {...current.pendingLineIds, lineId};
        ref.state = AsyncData(
          current.copyWith(pendingLineIds: pending, promoError: null),
        );

        await Future<void>.delayed(const Duration(milliseconds: 180));

        final gates = ref.watch(appExperienceGatesProvider);
        final updatedLines = current.lines.map((item) {
          if (item.id != lineId) return item;
          return item.copyWith(selectedAddonIds: selection);
        }).toList();

        pending.remove(lineId);
        ref.state = AsyncData(
          current.copyWith(
            lines: updatedLines,
            estimate: _estimateFor(updatedLines, gates),
            pendingLineIds: pending,
            promoError: null,
          ),
        );
        return selection;
      }, concurrency: Concurrency.dropLatest);

  Call<void> clearPromo() => mutate(clearPromoMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(
      current.copyWith(
        clearPromo: true,
        promoError: null,
        isApplyingPromo: false,
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<List<CartLineItem>> replaceLines(List<CartLineItem> lines) =>
      mutate(replaceLinesMut, (ref) async {
        final gates = ref.watch(appExperienceGatesProvider);
        ref.state = AsyncData(
          CartState(lines: lines, estimate: _estimateFor(lines, gates)),
        );
        return lines;
      }, concurrency: Concurrency.dropLatest);
}

List<CartLineItem> _seedLines(AppExperienceGates gates) {
  final en = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  return [
    CartLineItem(
      id: 'line-titanium',
      title: en ? 'Titanium round seal' : 'チタン丸印',
      variantLabel: en ? '15mm · Deep engraving' : '15mm・深彫り調整',
      designLabel: en ? 'Design: Akiyama (篤山)' : 'デザイン：篤山（Akiyama）',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=640&q=60',
      basePrice: const Money(amount: 12800, currency: 'JPY'),
      compareAtPrice: const Money(amount: 14800, currency: 'JPY'),
      quantity: 1,
      addonOptions: [
        CartAddonOption(
          id: 'addon-sleeve',
          label: en ? 'Microfiber sleeve' : 'マイクロファイバーケース',
          description: en ? 'Slim case with scratch guard.' : '薄型の起毛ケース。',
          price: const Money(amount: 1800, currency: 'JPY'),
          badge: en ? 'Popular' : '人気',
        ),
        CartAddonOption(
          id: 'addon-deep',
          label: en ? 'Deep engraving' : '深彫り仕上げ',
          description: en
              ? 'Sharper edges for crisp stamps.'
              : 'くっきり押せる深彫り仕上げ。',
          price: const Money(amount: 0, currency: 'JPY'),
          kind: CartAddonKind.option,
        ),
        CartAddonOption(
          id: 'addon-wrap',
          label: en ? 'Gift wrap' : 'ギフトラッピング',
          price: const Money(amount: 400, currency: 'JPY'),
          description: en
              ? 'Adds washi band and message card.'
              : '和紙帯とメッセージカード付き。',
        ),
      ],
      selectedAddonIds: {'addon-sleeve', 'addon-deep'},
      leadTimeMinDays: gates.isJapanRegion ? 2 : 5,
      leadTimeMaxDays: gates.isJapanRegion ? 4 : 9,
      note: intl ? 'Customs-friendly material' : 'お急ぎ対応・名入れ済み',
      ribbon: en ? 'Bestseller' : '人気',
    ),
    CartLineItem(
      id: 'line-acrylic',
      title: en ? 'Color acrylic seal' : 'カラーアクリル印',
      variantLabel: en ? '12mm · Mint / Script' : '12mm・ミント / 筆記体',
      designLabel: en ? 'Design: Upload later' : 'デザイン：後でアップロード',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=640&q=60',
      basePrice: const Money(amount: 6200, currency: 'JPY'),
      quantity: 2,
      addonOptions: [
        CartAddonOption(
          id: 'addon-uv',
          label: en ? 'UV finish' : 'UVコート',
          description: en
              ? 'Protects from fading and scratches.'
              : '色あせ・キズ防止コーティング。',
          price: const Money(amount: 1200, currency: 'JPY'),
          badge: en ? 'Limited' : '期間限定',
        ),
        CartAddonOption(
          id: 'addon-ink',
          label: en ? 'Ink pad set' : '朱肉セット',
          description: en
              ? 'Compact pad with replaceable insert.'
              : '交換式のコンパクト朱肉。',
          price: const Money(amount: 900, currency: 'JPY'),
        ),
        CartAddonOption(
          id: 'addon-pouch',
          label: en ? 'Soft pouch' : 'ソフトポーチ',
          description: en ? 'Keeps acrylic surface clean.' : 'アクリル面を保護するポーチ。',
          price: const Money(amount: 700, currency: 'JPY'),
        ),
      ],
      selectedAddonIds: {'addon-uv', 'addon-ink'},
      leadTimeMinDays: gates.isJapanRegion ? 3 : 7,
      leadTimeMaxDays: gates.isJapanRegion ? 6 : 12,
      note: en ? 'Ships with add-on recommendations.' : 'オプション同梱で発送。',
      ribbon: intl ? 'Intl friendly' : 'おすすめ',
    ),
    CartLineItem(
      id: 'line-box',
      title: en ? 'Keepsake box' : '桐箱・刻印入り',
      variantLabel: en ? 'Engraved lid · Natural' : '蓋刻印・ナチュラル',
      designLabel: en ? 'Name: Hanko Field' : '名入れ：はんこフィールド',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1582719471384-894fbb16e074?auto=format&fit=crop&w=640&q=60',
      basePrice: const Money(amount: 3200, currency: 'JPY'),
      quantity: 1,
      addonOptions: [
        CartAddonOption(
          id: 'addon-foam',
          label: en ? 'Foam insert' : 'クッション内装',
          description: en
              ? 'Secures seal and accessories.'
              : '印鑑と付属品を固定するクッション。',
          price: const Money(amount: 0, currency: 'JPY'),
          kind: CartAddonKind.option,
        ),
        CartAddonOption(
          id: 'addon-card',
          label: en ? 'Care card' : 'お手入れカード',
          price: const Money(amount: 0, currency: 'JPY'),
          description: en
              ? 'Printed care instructions in JP/EN.'
              : '日英併記のお手入れガイド。',
        ),
        CartAddonOption(
          id: 'addon-wrap-bundle',
          label: en ? 'Wrapping bundle' : 'ラッピングセット',
          price: const Money(amount: 550, currency: 'JPY'),
          description: en
              ? 'Ribbon, sticker, and spare tissue.'
              : 'リボン・シール・替え紙付き。',
        ),
      ],
      selectedAddonIds: {'addon-foam', 'addon-card', 'addon-wrap-bundle'},
      leadTimeMinDays: gates.isJapanRegion ? 2 : 5,
      leadTimeMaxDays: gates.isJapanRegion ? 3 : 8,
      note: intl ? 'Includes bilingual insert.' : 'メッセージ刻印済み。',
      ribbon: en ? 'Gift' : 'ギフト',
    ),
  ];
}

CartEstimate _estimateFor(List<CartLineItem> lines, AppExperienceGates gates) {
  if (lines.isEmpty) {
    return CartEstimate(
      minDays: 0,
      maxDays: 0,
      methodLabel: gates.emphasizeInternationalFlows ? 'Intl' : 'Domestic',
      international: gates.emphasizeInternationalFlows,
    );
  }

  int maxMin = 0;
  int maxMax = 0;
  for (final line in lines) {
    maxMin = max(maxMin, line.leadTimeMinDays);
    maxMax = max(maxMax, line.leadTimeMaxDays);
  }

  return CartEstimate(
    minDays: maxMin,
    maxDays: maxMax,
    methodLabel: gates.emphasizeInternationalFlows
        ? 'Intl priority'
        : 'Standard',
    international: gates.emphasizeInternationalFlows,
  );
}

final cartViewModel = CartViewModel();
