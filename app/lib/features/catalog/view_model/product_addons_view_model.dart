// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum AddonType { caseAccessory, box, ink }

class ProductAddon {
  const ProductAddon({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.price,
    this.compareAt,
    this.thumbnail,
    this.badge,
    this.limited = false,
    this.defaultSelected = false,
    this.leadTimeLabel,
  });

  final String id;
  final AddonType type;
  final String name;
  final String description;
  final Money price;
  final Money? compareAt;
  final String? thumbnail;
  final String? badge;
  final bool limited;
  final bool defaultSelected;
  final String? leadTimeLabel;

  int get savings => compareAt == null ? 0 : compareAt!.amount - price.amount;
}

class AddonGroup {
  const AddonGroup({
    required this.type,
    required this.title,
    required this.note,
    required this.items,
  });

  final AddonType type;
  final String title;
  final String note;
  final List<ProductAddon> items;
}

class AddonRecommendation {
  const AddonRecommendation({
    required this.title,
    required this.description,
    required this.addonIds,
    required this.savings,
    this.badge,
  });

  final String title;
  final String description;
  final List<String> addonIds;
  final Money savings;
  final String? badge;
}

class AddonCartUpdate {
  const AddonCartUpdate({
    required this.addonNames,
    required this.addonsTotal,
    required this.bundleSavings,
    required this.estimatedLineTotal,
  });

  final List<String> addonNames;
  final Money addonsTotal;
  final Money bundleSavings;
  final Money estimatedLineTotal;
}

class ProductAddonsState {
  const ProductAddonsState({
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.groups,
    required this.selectedAddonIds,
    this.recommendation,
  });

  final String productId;
  final String productName;
  final Money basePrice;
  final List<AddonGroup> groups;
  final Set<String> selectedAddonIds;
  final AddonRecommendation? recommendation;

  List<ProductAddon> get allAddons =>
      groups.expand((group) => group.items).toList(growable: false);

  List<ProductAddon> get selectedAddons =>
      allAddons.where((item) => selectedAddonIds.contains(item.id)).toList();

  Money get addonsTotal => _sumAddons(this);

  Money get bundleSavings => _bundleSavings(this);

  Money get estimatedLineTotal => Money(
    amount: basePrice.amount + addonsTotal.amount - bundleSavings.amount,
    currency: basePrice.currency,
  );

  bool get hasSelection => selectedAddonIds.isNotEmpty;

  bool get qualifiesForBundle {
    final rec = recommendation;
    if (rec == null) return false;
    return const SetEquality<String>().equals(
      rec.addonIds.toSet(),
      {...rec.addonIds}.intersection(selectedAddonIds),
    );
  }

  ProductAddonsState copyWith({Set<String>? selectedAddonIds}) {
    return ProductAddonsState(
      productId: productId,
      productName: productName,
      basePrice: basePrice,
      groups: groups,
      selectedAddonIds: Set<String>.from(
        selectedAddonIds ?? this.selectedAddonIds,
      ),
      recommendation: recommendation,
    );
  }
}

class ProductAddonsViewModel extends AsyncProvider<ProductAddonsState> {
  ProductAddonsViewModel({required this.productId})
    : super.args((productId,), autoDispose: true);

  final String productId;

  late final toggleAddonMut = mutation<String>(#toggleAddon);
  late final clearAllMut = mutation<void>(#clearAll);
  late final applyRecommendationMut = mutation<void>(#applyRecommendation);
  late final commitSelectionMut = mutation<AddonCartUpdate>(#commitSelection);

  @override
  Future<ProductAddonsState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 140));

    final seeds = _seedAddons(gates);
    final detail = seeds[productId];
    if (detail == null) throw StateError('Product add-ons not found');
    return detail;
  }

  Call<String> toggleAddon(String addonId) =>
      mutate(toggleAddonMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return addonId;

        final next = {...current.selectedAddonIds};
        if (next.contains(addonId)) {
          next.remove(addonId);
        } else {
          next.add(addonId);
        }

        ref.state = AsyncData(current.copyWith(selectedAddonIds: next));
        return addonId;
      });

  Call<void> clearAll() => mutate(clearAllMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(current.copyWith(selectedAddonIds: <String>{}));
  }, concurrency: Concurrency.dropLatest);

  Call<void> applyRecommendation() =>
      mutate(applyRecommendationMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        final rec = current?.recommendation;
        if (current == null || rec == null) return;
        final next = {...current.selectedAddonIds, ...rec.addonIds};
        ref.state = AsyncData(current.copyWith(selectedAddonIds: next));
      });

  Call<AddonCartUpdate> commitSelection() =>
      mutate(commitSelectionMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) throw StateError('Missing add-ons state');
        await Future<void>.delayed(const Duration(milliseconds: 180));

        return AddonCartUpdate(
          addonNames: current.selectedAddons.map((item) => item.name).toList(),
          addonsTotal: current.addonsTotal,
          bundleSavings: current.bundleSavings,
          estimatedLineTotal: current.estimatedLineTotal,
        );
      }, concurrency: Concurrency.dropLatest);
}

Map<String, ProductAddonsState> _seedAddons(AppExperienceGates gates) {
  final en = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  ProductAddonsState buildRoundClassic() {
    final groups = [
      AddonGroup(
        type: AddonType.caseAccessory,
        title: en ? 'Cases' : 'ケース',
        note: en ? 'Carry and protect the seal.' : '持ち運びと保護用。',
        items: [
          ProductAddon(
            id: 'case-microfiber',
            type: AddonType.caseAccessory,
            name: en ? 'Microfiber sleeve' : 'マイクロファイバーケース',
            description: en
                ? 'Slim sleeve with anti-scratch lining.'
                : '薄型で内側起毛のスリーブ。',
            price: const Money(amount: 1800, currency: 'JPY'),
            badge: en ? 'Most picked' : '人気',
            thumbnail:
                'https://images.unsplash.com/photo-1518442216856-67f3a0e9c1f0?auto=format&fit=crop&w=480&q=60',
            defaultSelected: true,
          ),
          ProductAddon(
            id: 'case-hard',
            type: AddonType.caseAccessory,
            name: en ? 'Hard travel case' : 'ハードトラベルケース',
            description: en
                ? 'Shock-absorbing shell with spare pad slot.'
                : '衝撃吸収シェル。替え朱肉スペース付き。',
            price: const Money(amount: 2600, currency: 'JPY'),
            compareAt: const Money(amount: 2900, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=480&q=60',
            limited: true,
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.box,
        title: en ? 'Boxes' : '箱・ギフト',
        note: en ? 'For gifting or archival storage.' : '贈り物や保管用。',
        items: [
          ProductAddon(
            id: 'box-paulownia',
            type: AddonType.box,
            name: en ? 'Paulownia gift box' : '桐箱ギフトボックス',
            description: en
                ? 'Humidity-balancing paulownia with ribbon.'
                : '調湿性のある桐材。リボン付き。',
            price: const Money(amount: 2800, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=480&q=60',
            leadTimeLabel: intl ? 'Ship with product' : '同梱発送',
          ),
          ProductAddon(
            id: 'box-slide',
            type: AddonType.box,
            name: en ? 'Slide box with padding' : 'スライド式クッション箱',
            description: en
                ? 'Magnetic slide, includes microfiber cloth.'
                : 'マグネット式スライド。クロス付き。',
            price: const Money(amount: 2200, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1462396881884-de2c07cb95ed?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.ink,
        title: en ? 'Ink & pads' : '朱肉・パッド',
        note: en ? 'Fresh pads tuned for titanium.' : 'チタン向け配合の朱肉。',
        items: [
          ProductAddon(
            id: 'ink-fastdry',
            type: AddonType.ink,
            name: en ? 'Fast-dry vermilion' : '速乾朱肉',
            description: en
                ? 'Smudge-resistant within 5 seconds.'
                : '5秒でほぼ定着する速乾タイプ。',
            price: const Money(amount: 1200, currency: 'JPY'),
            compareAt: const Money(amount: 1400, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=480&q=60',
            defaultSelected: true,
          ),
          ProductAddon(
            id: 'ink-refill',
            type: AddonType.ink,
            name: en ? 'Refill set (2x)' : '補充インク2本セット',
            description: en
                ? 'Keeps tone consistent for 6 months.'
                : '6ヶ月色味をキープ。',
            price: const Money(amount: 900, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1501696461415-6bd6660c6746?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
    ];

    return ProductAddonsState(
      productId: 'round-classic',
      productName: en ? 'Round classic' : '丸印クラシック',
      basePrice: const Money(amount: 9200, currency: 'JPY'),
      groups: groups,
      selectedAddonIds: _defaults(groups),
      recommendation: AddonRecommendation(
        title: en ? 'Travel & gift bundle' : '持ち歩き＋贈答セット',
        description: en
            ? 'Hard case + paulownia box + fast-dry ink. Save ¥600.'
            : 'ハードケース＋桐箱＋速乾朱肉で¥600お得。',
        addonIds: const ['case-hard', 'box-paulownia', 'ink-fastdry'],
        savings: const Money(amount: 600, currency: 'JPY'),
        badge: en ? 'Most chosen' : '人気',
      ),
    );
  }

  ProductAddonsState buildSquareModern() {
    final groups = [
      AddonGroup(
        type: AddonType.caseAccessory,
        title: en ? 'Cases' : 'ケース',
        note: en ? 'Suited for square edges.' : '角印向けの保護ケース。',
        items: [
          ProductAddon(
            id: 'case-satin',
            type: AddonType.caseAccessory,
            name: en ? 'Satin pouch' : 'サテン巾着',
            description: en
                ? 'Soft inner wall to protect satin finish.'
                : 'サテン仕上げを守る柔らかい内側。',
            price: const Money(amount: 1600, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1421986527537-888d998adb74?auto=format&fit=crop&w=480&q=60',
            defaultSelected: true,
          ),
          ProductAddon(
            id: 'case-handle',
            type: AddonType.caseAccessory,
            name: en ? 'Handle strap' : 'ストラップ付ハンドル',
            description: en
                ? 'Loop strap to keep grip while stamping.'
                : '捺印時の滑り止めストラップ。',
            price: const Money(amount: 1100, currency: 'JPY'),
            badge: en ? 'New' : '新登場',
            thumbnail:
                'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.box,
        title: en ? 'Boxes' : '箱・保管',
        note: en ? 'Pairs with bilingual seals.' : 'バイリンガル刻印向け保管。',
        items: [
          ProductAddon(
            id: 'box-magnetic',
            type: AddonType.box,
            name: en ? 'Magnetic archive box' : 'マグネット保管箱',
            description: en
                ? 'Desiccant slot and magnetic lid.'
                : '乾燥剤スペース付きマグネット蓋。',
            price: const Money(amount: 2400, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1462396881884-de2c07cb95ed?auto=format&fit=crop&w=480&q=60',
          ),
          ProductAddon(
            id: 'box-fabric',
            type: AddonType.box,
            name: en ? 'Fabric-covered box' : '布張りボックス',
            description: en
                ? 'Muted navy fabric for desk use.'
                : 'デスクに馴染むネイビーの布張り。',
            price: const Money(amount: 1900, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.ink,
        title: en ? 'Ink & pads' : '朱肉・パッド',
        note: en ? 'Square pad with crisp edges.' : '角印向けクリスプな朱肉。',
        items: [
          ProductAddon(
            id: 'ink-square',
            type: AddonType.ink,
            name: en ? 'Square pad (matte finish)' : '角用パッド（マット）',
            description: en
                ? 'Clean edges with low-bleed formula.'
                : 'にじみにくいマット配合。',
            price: const Money(amount: 1300, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=480&q=60',
          ),
          ProductAddon(
            id: 'ink-navy',
            type: AddonType.ink,
            name: en ? 'Navy ink (JP office)' : '紺色朱肉（事務用）',
            description: en
                ? 'For invoices and bilingual layouts.'
                : '請求書やバイリンガル刻印向け。',
            price: const Money(amount: 1500, currency: 'JPY'),
            compareAt: const Money(amount: 1700, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1501696461415-6bd6660c6746?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
    ];

    return ProductAddonsState(
      productId: 'square-modern',
      productName: en ? 'Square modern' : 'モダン角印',
      basePrice: const Money(amount: 7200, currency: 'JPY'),
      groups: groups,
      selectedAddonIds: _defaults(groups),
      recommendation: AddonRecommendation(
        title: en ? 'Desk set bundle' : 'デスクセット',
        description: en
            ? 'Magnetic box + navy ink keeps bilingual seals crisp.'
            : 'マグネット箱＋紺朱肉でバイリンガル印影を保つ。',
        addonIds: const ['box-magnetic', 'ink-navy'],
        savings: const Money(amount: 400, currency: 'JPY'),
      ),
    );
  }

  ProductAddonsState buildSquareBusiness() {
    final groups = [
      AddonGroup(
        type: AddonType.caseAccessory,
        title: en ? 'Cases' : 'ケース',
        note: en ? 'For frequent stamping.' : '頻繁な捺印向け。',
        items: [
          ProductAddon(
            id: 'case-grip',
            type: AddonType.caseAccessory,
            name: en ? 'Grip sleeve' : 'グリップスリーブ',
            description: en
                ? 'Anti-slip silicone sleeve for team use.'
                : 'シリコン素材で滑りにくい。',
            price: const Money(amount: 1400, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=480&q=60',
          ),
          ProductAddon(
            id: 'case-lock',
            type: AddonType.caseAccessory,
            name: en ? 'Locking cap' : 'ロックキャップ',
            description: en
                ? 'Twist-lock for desk drawers.'
                : '引き出し収納向けのツイストロック。',
            price: const Money(amount: 900, currency: 'JPY'),
            badge: en ? 'Office safe' : '事務用',
            thumbnail:
                'https://images.unsplash.com/photo-1462396881884-de2c07cb95ed?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.box,
        title: en ? 'Boxes' : '箱・保管',
        note: en ? 'Store with invoices.' : '請求書と一緒に保管。',
        items: [
          ProductAddon(
            id: 'box-ledger',
            type: AddonType.box,
            name: en ? 'Ledger drawer tray' : '帳票トレー型ボックス',
            description: en
                ? 'Fits A5 vouchers with desiccant slot.'
                : 'A5伝票と一緒に収納。乾燥剤スペース付き。',
            price: const Money(amount: 2100, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.ink,
        title: en ? 'Ink & pads' : '朱肉・パッド',
        note: en ? 'Bulk-safe refills.' : '大量押印向け。',
        items: [
          ProductAddon(
            id: 'ink-volume',
            type: AddonType.ink,
            name: en ? 'High-volume pad' : '大容量パッド',
            description: en
                ? 'Stays consistent for 500 impressions.'
                : '500回の押印でも色が安定。',
            price: const Money(amount: 1700, currency: 'JPY'),
            compareAt: const Money(amount: 1900, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=480&q=60',
            defaultSelected: true,
          ),
        ],
      ),
    ];

    return ProductAddonsState(
      productId: 'square-business',
      productName: en ? 'Business square' : 'ビジネス角印',
      basePrice: const Money(amount: 8900, currency: 'JPY'),
      groups: groups,
      selectedAddonIds: _defaults(groups),
      recommendation: AddonRecommendation(
        title: en ? 'Bulk desk bundle' : '業務用まとめセット',
        description: en
            ? 'Grip sleeve + ledger tray + high-volume pad for teams.'
            : '滑り止め＋帳票トレー＋大容量朱肉で業務効率化。',
        addonIds: const ['case-grip', 'box-ledger', 'ink-volume'],
        savings: const Money(amount: 500, currency: 'JPY'),
      ),
    );
  }

  ProductAddonsState buildOvalHeritage() {
    final groups = [
      AddonGroup(
        type: AddonType.caseAccessory,
        title: en ? 'Cases' : 'ケース',
        note: en ? 'Preserve natural grain.' : '天然素材の保護。',
        items: [
          ProductAddon(
            id: 'case-velvet',
            type: AddonType.caseAccessory,
            name: en ? 'Velvet case' : 'ベルベットケース',
            description: en
                ? 'Soft cradle to avoid micro scratches.'
                : '微細な傷を防ぐベルベット。',
            price: const Money(amount: 2000, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=480&q=60',
          ),
          ProductAddon(
            id: 'case-oil',
            type: AddonType.caseAccessory,
            name: en ? 'Care oil kit' : 'ケアオイルキット',
            description: en
                ? 'Oil + cloth to maintain horn sheen.'
                : '牛角の艶を保つオイルとクロス。',
            price: const Money(amount: 1500, currency: 'JPY'),
            badge: en ? 'Care' : 'メンテ',
            thumbnail:
                'https://images.unsplash.com/photo-1447933601403-0c6688de566e?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.box,
        title: en ? 'Boxes' : '箱・ギフト',
        note: en ? 'For heirloom use.' : '保管・贈答用。',
        items: [
          ProductAddon(
            id: 'box-heirloom',
            type: AddonType.box,
            name: en ? 'Heirloom paulownia box' : '桐箱（家紋刻印）',
            description: en
                ? 'Includes family crest engraving plate.'
                : '家紋プレート刻印付き。',
            price: const Money(amount: 3200, currency: 'JPY'),
            compareAt: const Money(amount: 3500, currency: 'JPY'),
            thumbnail:
                'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=480&q=60',
            limited: true,
            leadTimeLabel: intl ? 'Ships in 6-7 biz days' : '6-7営業日で発送',
          ),
        ],
      ),
      AddonGroup(
        type: AddonType.ink,
        title: en ? 'Ink & pads' : '朱肉・パッド',
        note: en ? 'Deep carve friendly.' : '深彫りに適した朱肉。',
        items: [
          ProductAddon(
            id: 'ink-classic',
            type: AddonType.ink,
            name: en ? 'Classic vermilion' : 'クラシック朱肉',
            description: en
                ? 'Warm tone to match natural horn.'
                : '天然素材に合う暖色の朱。',
            price: const Money(amount: 1100, currency: 'JPY'),
            defaultSelected: true,
            thumbnail:
                'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=480&q=60',
          ),
        ],
      ),
    ];

    return ProductAddonsState(
      productId: 'oval-heritage',
      productName: en ? 'Heritage oval' : '楕円ヘリテージ',
      basePrice: const Money(amount: 10800, currency: 'JPY'),
      groups: groups,
      selectedAddonIds: _defaults(groups),
      recommendation: AddonRecommendation(
        title: en ? 'Heirloom care bundle' : '家紋・ケアセット',
        description: en
            ? 'Velvet case + care oil + crest box keep grain pristine.'
            : 'ベルベット・ケアオイル・家紋桐箱で長期保存。',
        addonIds: const ['case-velvet', 'case-oil', 'box-heirloom'],
        savings: const Money(amount: 500, currency: 'JPY'),
      ),
    );
  }

  final seeds = <ProductAddonsState>[
    buildRoundClassic(),
    buildSquareModern(),
    buildSquareBusiness(),
    buildOvalHeritage(),
  ];

  return {for (final seed in seeds) seed.productId: seed};
}

Set<String> _defaults(List<AddonGroup> groups) {
  return groups
      .expand((group) => group.items)
      .where((item) => item.defaultSelected)
      .map((item) => item.id)
      .toSet();
}

Money _sumAddons(ProductAddonsState state) {
  final selected = state.selectedAddons;
  if (selected.isEmpty) {
    return Money(amount: 0, currency: state.basePrice.currency);
  }
  final amount = selected.fold<int>(0, (sum, item) => sum + item.price.amount);
  return Money(amount: amount, currency: state.basePrice.currency);
}

Money _bundleSavings(ProductAddonsState state) {
  final rec = state.recommendation;
  if (rec == null) {
    return Money(amount: 0, currency: state.basePrice.currency);
  }
  final qualifies = rec.addonIds.every(state.selectedAddonIds.contains);
  if (!qualifies) {
    return Money(amount: 0, currency: state.basePrice.currency);
  }
  return rec.savings;
}
