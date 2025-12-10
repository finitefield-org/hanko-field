// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart'
    as catalog;
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum StockBadgeLevel { good, warning, preorder }

class ProductPriceTier {
  const ProductPriceTier({
    required this.label,
    required this.minQuantity,
    required this.unitPrice,
    this.badge,
  });

  final String label;
  final int minQuantity;
  final Money unitPrice;
  final String? badge;
}

class ProductStockInfo {
  const ProductStockInfo({
    required this.level,
    required this.statusLabel,
    required this.windowLabel,
    this.availableQuantity,
    this.safetyStock,
    this.note,
  });

  final StockBadgeLevel level;
  final String statusLabel;
  final String windowLabel;
  final int? availableQuantity;
  final int? safetyStock;
  final String? note;
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.product,
    required this.materialLabel,
    required this.finishLabel,
    required this.leadTimeLabel,
    required this.gallery,
    required this.priceTiers,
    required this.stock,
    this.heroImage,
    this.badges = const <String>[],
    this.perks = const <String>[],
    this.designHint,
  });

  final String id;
  final catalog.Product product;
  final String materialLabel;
  final String finishLabel;
  final String leadTimeLabel;
  final List<String> gallery;
  final List<ProductPriceTier> priceTiers;
  final ProductStockInfo stock;
  final String? heroImage;
  final List<String> badges;
  final List<String> perks;
  final String? designHint;

  double get sizeMm => product.sizeMm;

  String get materialRef => product.materialRef;

  String get sku => product.sku;

  Money get basePrice => product.basePrice;

  Money? get salePrice {
    final sale = product.salePrice;
    if (sale == null) return null;
    if (sale.active == false) return null;
    return Money(amount: sale.amount, currency: sale.currency);
  }

  bool get isRound => product.shape == SealShape.round;
}

class DesignOption {
  const DesignOption({required this.id, required this.label, this.badge});

  final String id;
  final String label;
  final String? badge;
}

class ProductDetailState {
  const ProductDetailState({
    required this.productId,
    required this.title,
    required this.tagline,
    required this.variants,
    required this.selectedVariantId,
    required this.designOptions,
    required this.selectedDesignId,
    this.ribbon,
    this.isFavorite = false,
  });

  final String productId;
  final String title;
  final String tagline;
  final List<ProductVariant> variants;
  final String selectedVariantId;
  final List<DesignOption> designOptions;
  final String selectedDesignId;
  final String? ribbon;
  final bool isFavorite;

  ProductVariant get selectedVariant {
    return variants.firstWhere(
      (variant) => variant.id == selectedVariantId,
      orElse: () => variants.first,
    );
  }

  ProductDetailState copyWith({
    String? selectedVariantId,
    String? selectedDesignId,
    bool? isFavorite,
  }) {
    return ProductDetailState(
      productId: productId,
      title: title,
      tagline: tagline,
      variants: variants,
      selectedVariantId: selectedVariantId ?? this.selectedVariantId,
      designOptions: designOptions,
      selectedDesignId: selectedDesignId ?? this.selectedDesignId,
      ribbon: ribbon,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class ProductDetailViewModel extends AsyncProvider<ProductDetailState> {
  ProductDetailViewModel({required this.productId})
    : super.args((productId,), autoDispose: true);

  final String productId;

  late final toggleFavoriteMut = mutation<bool>(#toggleFavorite);
  late final selectVariantMut = mutation<String>(#selectVariant);
  late final selectDesignMut = mutation<String>(#selectDesign);

  @override
  Future<ProductDetailState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final seeds = _seedProductDetails(gates);
    final detail = seeds[productId];
    if (detail == null) throw StateError('Product not found');
    return detail;
  }

  Call<bool> toggleFavorite() => mutate(toggleFavoriteMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;
    final next = !current.isFavorite;
    ref.state = AsyncData(current.copyWith(isFavorite: next));
    return next;
  }, concurrency: Concurrency.dropLatest);

  Call<String> selectVariant(String variantId) =>
      mutate(selectVariantMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return variantId;

        final target = _resolveVariant(current, variantId: variantId);
        ref.state = AsyncData(current.copyWith(selectedVariantId: target.id));
        return target.id;
      });

  Call<String> selectVariantBySize(double sizeMm) =>
      mutate(selectVariantMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return sizeMm.toString();
        final target = _resolveVariant(current, sizeMm: sizeMm);
        ref.state = AsyncData(current.copyWith(selectedVariantId: target.id));
        return target.id;
      });

  Call<String> selectVariantByMaterial(String materialRef) =>
      mutate(selectVariantMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return materialRef;
        final target = _resolveVariant(current, materialRef: materialRef);
        ref.state = AsyncData(current.copyWith(selectedVariantId: target.id));
        return target.id;
      });

  Call<String> selectDesign(String designId) =>
      mutate(selectDesignMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return designId;
        final exists = current.designOptions.any((opt) => opt.id == designId);
        if (!exists) return current.selectedDesignId;
        ref.state = AsyncData(current.copyWith(selectedDesignId: designId));
        return designId;
      });
}

ProductVariant _resolveVariant(
  ProductDetailState state, {
  String? variantId,
  double? sizeMm,
  String? materialRef,
}) {
  final current = state.selectedVariant;

  if (variantId != null) {
    final match = state.variants.firstWhereOrNull(
      (variant) => variant.id == variantId,
    );
    if (match != null) return match;
  }

  final targetSize = sizeMm ?? current.sizeMm;
  final targetMaterial = materialRef ?? current.materialRef;

  final exact = state.variants.firstWhereOrNull(
    (variant) =>
        variant.sizeMm == targetSize && variant.materialRef == targetMaterial,
  );
  if (exact != null) return exact;

  if (sizeMm != null) {
    final bySize = state.variants.firstWhereOrNull(
      (variant) => variant.sizeMm == sizeMm,
    );
    if (bySize != null) return bySize;
  }

  if (materialRef != null) {
    final byMaterial = state.variants.firstWhereOrNull(
      (variant) => variant.materialRef == materialRef,
    );
    if (byMaterial != null) return byMaterial;
  }

  return current;
}

Map<String, ProductDetailState> _seedProductDetails(AppExperienceGates gates) {
  final now = DateTime.now();
  final en = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  final titanium15 = ProductVariant(
    id: 'round-classic-ti-15',
    product: catalog.Product(
      id: 'round-classic-ti-15',
      sku: 'HN-RND-TI-15',
      materialRef: 'titanium-matte',
      shape: SealShape.round,
      sizeMm: 15,
      basePrice: const Money(amount: 9800, currency: 'JPY'),
      salePrice: const catalog.SalePrice(
        amount: 9200,
        currency: 'JPY',
        active: true,
      ),
      stockPolicy: catalog.StockPolicy.inventory,
      stockQuantity: 24,
      stockSafety: 8,
      photos: const [
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
        'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=60',
      ],
      shipping: const catalog.ShippingAttributes(weightGr: 110, boxSize: '60'),
      attributes: const {'finish': 'matte', 'coating': 'bead'},
      isActive: true,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 4)),
      engraveDepthMm: 1.4,
    ),
    materialLabel: en ? 'Matte titanium' : 'マットチタン',
    finishLabel: en ? 'Bead-blasted' : 'ビーズショット',
    leadTimeLabel: intl ? 'Ships in 3-4 biz days (DHL)' : '国内3-4営業日で発送',
    gallery: const [
      'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1503389152951-9f343605f61e?auto=format&fit=crop&w=1200&q=60',
    ],
    priceTiers: [
      ProductPriceTier(
        label: en ? 'Single' : '単品',
        minQuantity: 1,
        unitPrice: const Money(amount: 9200, currency: 'JPY'),
        badge: en ? 'Limited sale' : 'セール中',
      ),
      ProductPriceTier(
        label: en ? '3+ bundle' : '3本セット',
        minQuantity: 3,
        unitPrice: const Money(amount: 8900, currency: 'JPY'),
        badge: en ? 'Free casing' : 'ケース無料',
      ),
      ProductPriceTier(
        label: en ? '5+ team order' : '5本〜',
        minQuantity: 5,
        unitPrice: const Money(amount: 8600, currency: 'JPY'),
        badge: en ? 'Engraving priority' : '刻印優先',
      ),
    ],
    stock: ProductStockInfo(
      level: StockBadgeLevel.good,
      statusLabel: en ? 'In stock' : '在庫あり',
      windowLabel: intl ? 'Reserved slots tonight' : '今夜刻印枠あり',
      availableQuantity: 14,
      safetyStock: 8,
      note: en
          ? 'Queue clears nightly with bilingual templates.'
          : '夜間にバイリンガル刻印枠を確保。',
    ),
    heroImage:
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
    badges: [en ? 'Bestseller' : '人気', en ? 'Hypoallergenic' : '金属アレルギー対応'],
    perks: [
      en ? 'Microfiber case included' : 'マイクロファイバーケース付属',
      en ? 'Edge polishing included' : '縁の磨き仕上げ込み',
    ],
    designHint: en ? 'Pairs with Tensho & bold strokes' : '篆書・太字テンプレと好相性',
  );

  final titanium18 = ProductVariant(
    id: 'round-classic-ti-18',
    product: catalog.Product(
      id: 'round-classic-ti-18',
      sku: 'HN-RND-TI-18',
      materialRef: 'titanium-matte',
      shape: SealShape.round,
      sizeMm: 18,
      basePrice: const Money(amount: 11200, currency: 'JPY'),
      salePrice: const catalog.SalePrice(
        amount: 10800,
        currency: 'JPY',
        active: true,
      ),
      stockPolicy: catalog.StockPolicy.inventory,
      stockQuantity: 12,
      stockSafety: 6,
      photos: const [
        'https://images.unsplash.com/photo-1503389152951-9f343605f61e?auto=format&fit=crop&w=1200&q=60',
        'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=1200&q=60',
      ],
      shipping: const catalog.ShippingAttributes(weightGr: 130, boxSize: '60'),
      attributes: const {'finish': 'matte', 'coating': 'bead'},
      isActive: true,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 4)),
      engraveDepthMm: 1.5,
    ),
    materialLabel: en ? 'Matte titanium' : 'マットチタン',
    finishLabel: en ? 'Bead-blasted' : 'ビーズショット',
    leadTimeLabel: intl ? 'Ships in 4-5 biz days' : '国内4-5営業日で発送',
    gallery: const [
      'https://images.unsplash.com/photo-1503389152951-9f343605f61e?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=60',
    ],
    priceTiers: [
      ProductPriceTier(
        label: en ? 'Single' : '単品',
        minQuantity: 1,
        unitPrice: const Money(amount: 10800, currency: 'JPY'),
      ),
      ProductPriceTier(
        label: en ? '2+ pair' : '2本セット',
        minQuantity: 2,
        unitPrice: const Money(amount: 10400, currency: 'JPY'),
        badge: en ? 'Case + ink' : 'ケース・朱肉付き',
      ),
      ProductPriceTier(
        label: en ? '5+ team order' : '5本〜',
        minQuantity: 5,
        unitPrice: const Money(amount: 9900, currency: 'JPY'),
        badge: en ? 'Engraving priority' : '刻印優先',
      ),
    ],
    stock: ProductStockInfo(
      level: StockBadgeLevel.warning,
      statusLabel: en ? 'Low stock' : '残りわずか',
      windowLabel: intl ? 'Ship in 4-5 days' : '4-5営業日で発送',
      availableQuantity: 6,
      safetyStock: 6,
      note: en ? 'Slots shared with bulk orders.' : '法人ロットと共用の刻印枠です。',
    ),
    heroImage:
        'https://images.unsplash.com/photo-1503389152951-9f343605f61e?auto=format&fit=crop&w=1200&q=60',
    badges: [
      en ? 'Balanced weight' : 'バランス重視',
      en ? 'For company seals' : '社名刻印向き',
    ],
    perks: [
      en ? 'Edge polish included' : '縁磨き込み',
      en ? 'Priority engraving' : '刻印優先枠',
    ],
    designHint: en ? 'Great for bilingual layouts' : 'バイリンガル刻印に最適',
  );

  final horn15 = ProductVariant(
    id: 'round-classic-horn-15',
    product: catalog.Product(
      id: 'round-classic-horn-15',
      sku: 'HN-RND-HORN-15',
      materialRef: 'horn-premium',
      shape: SealShape.round,
      sizeMm: 15,
      basePrice: const Money(amount: 8700, currency: 'JPY'),
      salePrice: null,
      stockPolicy: catalog.StockPolicy.inventory,
      stockQuantity: 7,
      stockSafety: 4,
      photos: const [
        'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
        'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=1200&q=60',
      ],
      shipping: const catalog.ShippingAttributes(weightGr: 105, boxSize: '60'),
      attributes: const {'finish': 'gloss'},
      isActive: true,
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now.subtract(const Duration(days: 8)),
      engraveDepthMm: 1.2,
    ),
    materialLabel: en ? 'Premium horn' : '本牛角プレミアム',
    finishLabel: en ? 'Gloss finish' : '艶仕上げ',
    leadTimeLabel: intl ? 'Ships in 5-6 biz days' : '5-6営業日で発送',
    gallery: const [
      'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=1200&q=60',
    ],
    priceTiers: [
      ProductPriceTier(
        label: en ? 'Single' : '単品',
        minQuantity: 1,
        unitPrice: const Money(amount: 8700, currency: 'JPY'),
      ),
      ProductPriceTier(
        label: en ? '3+ bundle' : '3本セット',
        minQuantity: 3,
        unitPrice: const Money(amount: 8200, currency: 'JPY'),
        badge: en ? 'Conditioning oil' : '専用オイル付',
      ),
    ],
    stock: ProductStockInfo(
      level: StockBadgeLevel.warning,
      statusLabel: en ? 'Limited batches' : '数量限定',
      windowLabel: intl ? 'Ships in 5-6 days' : '5-6営業日で発送',
      availableQuantity: 4,
      safetyStock: 4,
      note: en ? 'Natural grain differs by lot.' : 'ロットごとに模様が異なります。',
    ),
    heroImage:
        'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
    badges: [en ? 'Warm tone' : '温かみ', en ? 'Traditional' : '伝統素材'],
    perks: [
      en ? 'Hand buffed gloss' : '手磨き艶仕上げ',
      en ? 'Conditioning oil' : 'ケアオイル付き',
    ],
    designHint: en ? 'Soft contrast templates recommended' : '柔らかいコントラスト推奨',
  );

  final woodSquare = ProductVariant(
    id: 'square-modern-wood-18',
    product: catalog.Product(
      id: 'square-modern-wood-18',
      sku: 'HN-SQ-WOOD-18',
      materialRef: 'beech',
      shape: SealShape.square,
      sizeMm: 18,
      basePrice: const Money(amount: 7600, currency: 'JPY'),
      salePrice: const catalog.SalePrice(
        amount: 7200,
        currency: 'JPY',
        active: true,
      ),
      stockPolicy: catalog.StockPolicy.madeToOrder,
      stockQuantity: null,
      stockSafety: null,
      photos: const [
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=60',
        'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
      ],
      shipping: const catalog.ShippingAttributes(weightGr: 118, boxSize: '60'),
      attributes: const {'finish': 'satin'},
      isActive: true,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 3)),
      engraveDepthMm: 1.1,
    ),
    materialLabel: en ? 'Beech satin' : 'ブナ サテン',
    finishLabel: en ? 'Satin oil' : 'サテンオイル仕上げ',
    leadTimeLabel: intl ? 'Ships in 6-7 biz days' : '6-7営業日で発送',
    gallery: const [
      'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=60',
      'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
    ],
    priceTiers: [
      ProductPriceTier(
        label: en ? 'Single' : '単品',
        minQuantity: 1,
        unitPrice: const Money(amount: 7200, currency: 'JPY'),
        badge: en ? 'Made to order' : '受注生産',
      ),
      ProductPriceTier(
        label: en ? '3+ bundle' : '3本セット',
        minQuantity: 3,
        unitPrice: const Money(amount: 6900, currency: 'JPY'),
        badge: en ? 'Oil refill' : 'オイルリフィル付',
      ),
    ],
    stock: ProductStockInfo(
      level: StockBadgeLevel.preorder,
      statusLabel: en ? 'Made to order' : '受注生産',
      windowLabel: intl ? 'Ships in 6-7 days' : '6-7営業日で発送',
      note: en ? 'Includes humidity conditioning.' : '含浸処理込みで納期確保。',
    ),
    heroImage:
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=60',
    badges: [en ? 'Lightweight' : '軽量', en ? 'Eco' : '環境配慮'],
    perks: [
      en ? 'Oil conditioning included' : 'オイル含浸込み',
      en ? 'Sustainably sourced' : 'サステナブル材',
    ],
    designHint: en ? 'Great for bilingual layouts' : 'バイリンガル刻印向き',
  );

  final ovalHeritage = ProductVariant(
    id: 'oval-heritage-17',
    product: catalog.Product(
      id: 'oval-heritage-17',
      sku: 'HN-OVAL-HER-17',
      materialRef: 'horn-premium',
      shape: SealShape.round,
      sizeMm: 17,
      basePrice: const Money(amount: 9300, currency: 'JPY'),
      salePrice: null,
      stockPolicy: catalog.StockPolicy.inventory,
      stockQuantity: 10,
      stockSafety: 5,
      photos: const [
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
      ],
      shipping: const catalog.ShippingAttributes(weightGr: 120, boxSize: '60'),
      attributes: const {'finish': 'semi-matte'},
      isActive: true,
      createdAt: now.subtract(const Duration(days: 75)),
      updatedAt: now.subtract(const Duration(days: 6)),
      engraveDepthMm: 1.25,
    ),
    materialLabel: en ? 'Horn semi-matte' : '牛角 セミマット',
    finishLabel: en ? 'Soft sheen' : '控えめな艶',
    leadTimeLabel: intl ? 'Ships in 4-5 biz days' : '4-5営業日で発送',
    gallery: const [
      'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
    ],
    priceTiers: [
      ProductPriceTier(
        label: en ? 'Single' : '単品',
        minQuantity: 1,
        unitPrice: const Money(amount: 9300, currency: 'JPY'),
      ),
      ProductPriceTier(
        label: en ? '3+ bundle' : '3本セット',
        minQuantity: 3,
        unitPrice: const Money(amount: 8800, currency: 'JPY'),
      ),
    ],
    stock: ProductStockInfo(
      level: StockBadgeLevel.good,
      statusLabel: en ? 'Ready' : '在庫あり',
      windowLabel: intl ? '4-5 day ship' : '4-5営業日発送',
      availableQuantity: 8,
      safetyStock: 5,
    ),
    heroImage:
        'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=1200&q=60',
    perks: [
      en ? 'Includes edge rounding' : '面取り込み',
      en ? 'Moisture conditioning' : '湿度調整済み',
    ],
    designHint: en ? 'Classic scripts and bank use' : '銀行印・実印向き',
  );

  final roundDetail = ProductDetailState(
    productId: 'round-classic',
    title: en ? 'Round classic' : '丸印クラシック',
    tagline: en
        ? 'Daily-use round seal with resilient titanium and warm horn options.'
        : 'チタンと牛角から選べる日常使いの丸印。',
    ribbon: en ? 'Bestseller' : '人気商品',
    variants: [titanium15, titanium18, horn15],
    selectedVariantId: titanium15.id,
    designOptions: [
      DesignOption(
        id: 'tensho-classic',
        label: en ? 'Tensho classic · 15mm' : '篆書クラシック・15mm',
        badge: en ? 'Recommended' : 'おすすめ',
      ),
      DesignOption(
        id: 'engraved-bold',
        label: en ? 'Engraved bold · deep carve' : '深彫りボールド',
      ),
      DesignOption(
        id: 'select-later',
        label: en ? 'Select design later' : 'あとで選ぶ',
        badge: en ? 'Needs choice' : '要選択',
      ),
    ],
    selectedDesignId: 'tensho-classic',
    isFavorite: true,
  );

  final squareDetail = ProductDetailState(
    productId: 'square-modern',
    title: en ? 'Square modern' : 'モダン角印',
    tagline: en
        ? 'Square seal with satin beech and crisp edges for bilingual names.'
        : 'ブナのサテン仕上げでバイリンガル刻印に映える角印。',
    variants: [woodSquare],
    selectedVariantId: woodSquare.id,
    designOptions: [
      DesignOption(
        id: 'modern-square',
        label: en ? 'Modern square layout' : 'モダン角レイアウト',
      ),
      DesignOption(
        id: 'select-later',
        label: en ? 'Select design later' : 'あとで選ぶ',
      ),
    ],
    selectedDesignId: 'modern-square',
  );

  final businessSquare = ProductDetailState(
    productId: 'square-business',
    title: en ? 'Business square' : 'ビジネス角印',
    tagline: en
        ? 'Bold visibility for invoices and company seals.'
        : '請求書・社名に映える太字角印。',
    variants: [woodSquare],
    selectedVariantId: woodSquare.id,
    designOptions: squareDetail.designOptions,
    selectedDesignId: 'modern-square',
  );

  final heritageOval = ProductDetailState(
    productId: 'oval-heritage',
    title: en ? 'Heritage oval' : '楕円ヘリテージ',
    tagline: en
        ? 'Softer oval profile for bank and official use.'
        : '銀行印・実印向けの柔らかい楕円フォルム。',
    variants: [ovalHeritage],
    selectedVariantId: ovalHeritage.id,
    designOptions: [
      DesignOption(
        id: 'tensho-classic',
        label: en ? 'Tensho classic' : '篆書クラシック',
      ),
      DesignOption(
        id: 'engraved-bold',
        label: en ? 'Engraved bold' : '深彫りボールド',
      ),
      DesignOption(id: 'select-later', label: en ? 'Select later' : 'あとで選ぶ'),
    ],
    selectedDesignId: 'tensho-classic',
  );

  return {
    roundDetail.productId: roundDetail,
    squareDetail.productId: squareDetail,
    businessSquare.productId: businessSquare,
    heritageOval.productId: heritageOval,
  };
}
