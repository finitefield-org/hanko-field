import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/catalog.dart';
import 'package:app/features/shop/domain/product_detail.dart';

abstract class ProductDetailRepository {
  Future<ProductDetail> fetchProductDetail({
    required String productId,
    required ExperienceGate experience,
  });
}

class FakeProductDetailRepository implements ProductDetailRepository {
  const FakeProductDetailRepository();

  @override
  Future<ProductDetail> fetchProductDetail({
    required String productId,
    required ExperienceGate experience,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final details = experience.isInternational
        ? _internationalDetails
        : _domesticDetails;
    final detail = details[productId];
    if (detail == null) {
      throw StateError('Product $productId not found');
    }
    return detail;
  }

  static CatalogProduct _baseProduct({
    required String id,
    required String sku,
    required String materialRef,
    required CatalogProductShape shape,
    required double sizeMm,
    required int baseAmount,
    required String currency,
    CatalogSalePrice? salePrice,
    CatalogStockPolicy stockPolicy = CatalogStockPolicy.inventory,
    int? stockQuantity,
    int? stockSafety,
    List<String> photos = const [],
    Map<String, dynamic>? attributes,
  }) {
    return CatalogProduct(
      id: id,
      sku: sku,
      materialRef: materialRef,
      shape: shape,
      size: CatalogProductSize(mm: sizeMm),
      basePrice: CatalogMoney(amount: baseAmount, currency: currency),
      salePrice: salePrice,
      engraveDepthMm: 0.75,
      stockPolicy: stockPolicy,
      stockQuantity: stockQuantity,
      stockSafety: stockSafety,
      photos: photos,
      shipping: const CatalogShippingInfo(weightGr: 420, boxSize: '60'),
      attributes: attributes,
      isActive: true,
      createdAt: DateTime(2023, 11, 1),
    );
  }

  static ProductDetail _buildCaseDetail() {
    final baseProduct = _baseProduct(
      id: 'echizen-case',
      sku: 'CASE-ECHIZEN-12',
      materialRef: 'echizen-washi',
      shape: CatalogProductShape.square,
      sizeMm: 40,
      baseAmount: 14800,
      currency: 'JPY',
      salePrice: const CatalogSalePrice(
        amount: 13800,
        currency: 'JPY',
        active: true,
      ),
      stockQuantity: 26,
      stockSafety: 12,
      photos: const [
        'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=1200',
        'https://images.unsplash.com/photo-1449247613801-ab06418e2861?w=1200',
      ],
      attributes: const {'craft': 'echizen-washi', 'category': 'case'},
    );
    final variantGroups = [
      ProductVariantGroup(
        id: 'size',
        label: '対応サイズ',
        options: [
          const ProductVariantOption(id: 'hanko-12', label: '12mm'),
          const ProductVariantOption(id: 'hanko-15', label: '15mm'),
        ],
      ),
      ProductVariantGroup(
        id: 'lining',
        label: '内張りカラー',
        selectionType: ProductVariantSelectionType.chip,
        options: [
          const ProductVariantOption(
            id: 'indigo',
            label: '藍染め',
            helperText: '落ち着いた藍色',
          ),
          const ProductVariantOption(
            id: 'vermilion',
            label: '朱色',
            helperText: '朱肉が映える',
          ),
          const ProductVariantOption(
            id: 'linen',
            label: '生成り',
            helperText: '淡いホワイト',
          ),
        ],
      ),
    ];
    final variants = [
      ProductVariant(
        id: 'echizen-case-12-indigo',
        optionSelections: const {'size': 'hanko-12', 'lining': 'indigo'},
        displayLabel: '12mm / 藍染め',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1521579773717-291064d5739d?w=1600',
          'https://images.unsplash.com/photo-1449247613801-ab06418e2861?w=1600',
        ],
        price: const CatalogMoney(amount: 14800, currency: 'JPY'),
        salePrice: const CatalogSalePrice(
          amount: 13800,
          currency: 'JPY',
          active: true,
        ),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 14800, currency: 'JPY'),
            note: '単品購入',
          ),
          ProductPriceTier(
            minQuantity: 2,
            maxQuantity: 4,
            price: CatalogMoney(amount: 14200, currency: 'JPY'),
            savingsLabel: '4% OFF',
            note: 'ギフト向けまとめ買い',
          ),
          ProductPriceTier(
            minQuantity: 5,
            price: CatalogMoney(amount: 13600, currency: 'JPY'),
            savingsLabel: '8% OFF',
            note: '法人向けロット',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.inStock,
          label: '在庫あり',
          detail: '工房在庫: 12点',
          quantity: 12,
        ),
        leadTime: '発送目安: 3 営業日以内',
      ),
      ProductVariant(
        id: 'echizen-case-12-vermilion',
        optionSelections: const {'size': 'hanko-12', 'lining': 'vermilion'},
        displayLabel: '12mm / 朱色',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600',
          'https://images.unsplash.com/photo-1512427691650-1e0c7a98a111?w=1600',
        ],
        price: const CatalogMoney(amount: 14800, currency: 'JPY'),
        salePrice: const CatalogSalePrice(
          amount: 13800,
          currency: 'JPY',
          active: true,
        ),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 14800, currency: 'JPY'),
            note: '単品購入',
          ),
          ProductPriceTier(
            minQuantity: 2,
            maxQuantity: 4,
            price: CatalogMoney(amount: 14000, currency: 'JPY'),
            savingsLabel: '5% OFF',
            note: '贈答用セット価格',
          ),
          ProductPriceTier(
            minQuantity: 5,
            price: CatalogMoney(amount: 13400, currency: 'JPY'),
            savingsLabel: '9% OFF',
            note: '法人向けロット',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.limited,
          label: '残りわずか',
          detail: '次回入荷: 2 週間後',
          quantity: 4,
        ),
        leadTime: '発送目安: 5 営業日以内',
      ),
      ProductVariant(
        id: 'echizen-case-15-linen',
        optionSelections: const {'size': 'hanko-15', 'lining': 'linen'},
        displayLabel: '15mm / 生成り',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1400&sat=-100',
        galleryImages: const [
          'https://images.unsplash.com/photo-1512427691650-1e0c7a98a111?w=1600&sat=-100',
          'https://images.unsplash.com/photo-1472289065668-ce650ac443d2?w=1600',
        ],
        price: const CatalogMoney(amount: 16200, currency: 'JPY'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 16200, currency: 'JPY'),
            note: '15mm 対応ケース',
          ),
          ProductPriceTier(
            minQuantity: 2,
            price: CatalogMoney(amount: 15400, currency: 'JPY'),
            savingsLabel: '5% OFF',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.backorder,
          label: '受注生産',
          detail: '職人仕上げのため 10 日ほど',
        ),
        leadTime: '発送目安: 7〜10 営業日',
      ),
    ];

    return ProductDetail(
      id: 'echizen-case',
      name: '越前和紙ケース',
      subtitle: '伝統工芸士仕上げのギフトケース',
      description: '福井県越前市の工房で仕立てた印鑑ケース。内張りには朱肉が映える和紙を採用し、持ち主の印影をしっかり守ります。',
      baseProduct: baseProduct,
      badges: const ['期間限定', '工房直送'],
      highlights: const [
        '福井県指定伝統工芸士による手仕上げ',
        '国産真鍮枠と和紙張りの二重構造',
        'ギフト包装とメッセージカード同梱',
      ],
      specs: [
        ProductSpec(label: 'SKU', value: baseProduct.sku),
        const ProductSpec(
          label: '素材',
          value: '越前和紙・真鍮',
          detail: '内張りに防湿コーティング済み',
        ),
        const ProductSpec(label: '重量', value: '約 120g'),
        const ProductSpec(label: '対応サイズ', value: '12mm / 15mm'),
        const ProductSpec(label: '製造拠点', value: '福井県越前市'),
      ],
      variantGroups: variantGroups,
      variants: variants,
      includedItems: const [
        '越前和紙ケース本体',
        'オリジナル化粧箱',
        'ギフト用リボン（藍／朱）',
        '取扱説明書兼保証書 (1年)',
      ],
      careNote: '高温多湿を避け、付属の化粧箱で保管してください。',
      shippingNote: 'ヤマト運輸（60 サイズ）で全国発送いたします。',
    );
  }

  static ProductDetail _buildSealDetail() {
    final baseProduct = _baseProduct(
      id: 'seal-2024',
      sku: 'SEAL-2024-SET',
      materialRef: 'tsuge',
      shape: CatalogProductShape.round,
      sizeMm: 13.5,
      baseAmount: 24800,
      currency: 'JPY',
      salePrice: const CatalogSalePrice(
        amount: 22800,
        currency: 'JPY',
        active: true,
      ),
      stockPolicy: CatalogStockPolicy.madeToOrder,
      attributes: const {'bundle': true, 'limitedEdition': true},
    );
    final variantGroups = [
      ProductVariantGroup(
        id: 'size',
        label: '印面サイズ',
        options: [
          const ProductVariantOption(
            id: 'size-12',
            label: '12mm',
            helperText: '女性人気',
          ),
          const ProductVariantOption(id: 'size-13.5', label: '13.5mm'),
          const ProductVariantOption(
            id: 'size-15',
            label: '15mm',
            helperText: '男性人気',
          ),
        ],
      ),
      ProductVariantGroup(
        id: 'material',
        label: '素材',
        selectionType: ProductVariantSelectionType.chip,
        options: [
          const ProductVariantOption(id: 'tsuge', label: '国産柘'),
          const ProductVariantOption(id: 'titanium', label: 'チタン'),
          const ProductVariantOption(id: 'kuro-sui', label: '黒水牛'),
        ],
      ),
    ];
    final variants = [
      ProductVariant(
        id: 'seal-2024-12-tsuge',
        optionSelections: const {'size': 'size-12', 'material': 'tsuge'},
        displayLabel: '12mm / 柘',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=1600',
          'https://images.unsplash.com/photo-1524593135502-59f89d56a0e4?w=1600',
        ],
        price: const CatalogMoney(amount: 24800, currency: 'JPY'),
        salePrice: const CatalogSalePrice(
          amount: 22800,
          currency: 'JPY',
          active: true,
        ),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 24800, currency: 'JPY'),
            note: '朱肉セット付属',
          ),
          ProductPriceTier(
            minQuantity: 2,
            maxQuantity: 4,
            price: CatalogMoney(amount: 23600, currency: 'JPY'),
            savingsLabel: '5% OFF',
            note: '家族セット割',
          ),
          ProductPriceTier(
            minQuantity: 5,
            price: CatalogMoney(amount: 22800, currency: 'JPY'),
            savingsLabel: '8% OFF',
            note: '法人契約価格',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.inStock,
          label: '受付中',
          detail: '製作枠残り: 6 件',
        ),
        leadTime: '製作リードタイム: 約 5 営業日',
      ),
      ProductVariant(
        id: 'seal-2024-13-titanium',
        optionSelections: const {'size': 'size-13.5', 'material': 'titanium'},
        displayLabel: '13.5mm / チタン',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1400&sat=-20',
        galleryImages: const [
          'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=1600',
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600',
        ],
        price: const CatalogMoney(amount: 29800, currency: 'JPY'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 29800, currency: 'JPY'),
            note: '耐久保証 5 年',
          ),
          ProductPriceTier(
            minQuantity: 2,
            price: CatalogMoney(amount: 28400, currency: 'JPY'),
            savingsLabel: '5% OFF',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.limited,
          label: '残り 3 枠',
          detail: '次回製作枠: 来週以降',
        ),
        leadTime: '製作リードタイム: 約 7 営業日',
      ),
      ProductVariant(
        id: 'seal-2024-15-kuro',
        optionSelections: const {'size': 'size-15', 'material': 'kuro-sui'},
        displayLabel: '15mm / 黒水牛',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1600',
          'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=1600',
        ],
        price: const CatalogMoney(amount: 26800, currency: 'JPY'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 26800, currency: 'JPY'),
            note: '芯持ち角使用',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.preorder,
          label: '次回ロット予約',
          detail: '製作再開予定: 来月初旬',
        ),
        leadTime: '製作リードタイム: 約 14 営業日',
      ),
    ];

    return ProductDetail(
      id: 'seal-2024',
      name: '新春限定印鑑セット 2024',
      subtitle: '干支モチーフ朱肉とケース付き',
      description: '限定デザインの干支モチーフ朱肉と越前和紙ケースが付属する新春限定セット。国内工房で一本ずつ手仕上げします。',
      baseProduct: baseProduct,
      badges: const ['数量限定', '銀行印対応'],
      highlights: const [
        '干支モチーフ入り朱肉をセットで同梱',
        '五年保証と無料再彫刻サービス付き',
        '銀行印・実印の登録サポート資料同梱',
      ],
      specs: [
        ProductSpec(label: 'SKU', value: baseProduct.sku),
        const ProductSpec(label: '印面形状', value: '丸寸胴'),
        const ProductSpec(label: '対応印影', value: '姓彫り・フルネーム'),
        const ProductSpec(label: '付属ケース', value: '越前和紙・金枠'),
        const ProductSpec(label: '製作', value: '鹿児島・福井工房連携'),
      ],
      variantGroups: variantGroups,
      variants: variants,
      includedItems: const [
        '限定デザイン印鑑（選択素材）',
        '干支モチーフ朱肉',
        '越前和紙ケース（色選択）',
        '登録ガイド＆保証書',
      ],
      careNote: '朱肉を拭き取り、付属のケースで保管してください。',
      shippingNote: '国内送料無料。ヤマト便にて追跡番号をお送りします。',
      requiresDesignSelection: true,
    );
  }

  static ProductDetail _buildIntlKitDetail() {
    final baseProduct = _baseProduct(
      id: 'intl-kit',
      sku: 'INTL-KIT-ENG',
      materialRef: 'titanium',
      shape: CatalogProductShape.square,
      sizeMm: 14,
      baseAmount: 189,
      currency: 'USD',

      stockQuantity: 42,
      stockSafety: 18,
      photos: const [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200',
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
      ],
      attributes: const {'bundle': true, 'international': true},
    );
    final variantGroups = [
      ProductVariantGroup(
        id: 'script',
        label: 'Engraving Script',
        options: [
          const ProductVariantOption(id: 'kanji', label: 'Kanji'),
          const ProductVariantOption(id: 'romaji', label: 'Romaji'),
          const ProductVariantOption(id: 'katakana', label: 'Katakana'),
        ],
      ),
      ProductVariantGroup(
        id: 'bundle',
        label: 'Bundle',
        selectionType: ProductVariantSelectionType.chip,
        options: [
          const ProductVariantOption(id: 'standard', label: 'Standard'),
          const ProductVariantOption(id: 'airport', label: 'Airport Pickup'),
          const ProductVariantOption(id: 'expat', label: 'Expat Support'),
        ],
      ),
    ];
    final variants = [
      ProductVariant(
        id: 'intl-kit-kanji-standard',
        optionSelections: const {'script': 'kanji', 'bundle': 'standard'},
        displayLabel: 'Kanji / Standard',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1600',
          'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1600',
        ],
        price: const CatalogMoney(amount: 189, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 189, currency: 'USD'),
            note: 'Includes bilingual manuals',
          ),
          ProductPriceTier(
            minQuantity: 2,
            price: CatalogMoney(amount: 179, currency: 'USD'),
            savingsLabel: 'Save \$10',
            note: 'Dual kit discount',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.inStock,
          label: 'In stock',
          detail: 'Ships worldwide within 48h',
        ),
        leadTime: 'Ships in 2 business days via DHL Express',
      ),
      ProductVariant(
        id: 'intl-kit-kanji-expat',
        optionSelections: const {'script': 'kanji', 'bundle': 'expat'},
        displayLabel: 'Kanji / Expat Support',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600',
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600&sat=-20',
        ],
        price: const CatalogMoney(amount: 249, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            maxQuantity: 1,
            price: CatalogMoney(amount: 249, currency: 'USD'),
            note: 'Includes legal document templates',
          ),
          ProductPriceTier(
            minQuantity: 2,
            price: CatalogMoney(amount: 235, currency: 'USD'),
            savingsLabel: 'Save \$14',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.limited,
          label: 'Limited slots',
          detail: 'Consultation slots filling fast',
        ),
        leadTime: 'Ships in 3 business days with concierge onboarding',
      ),
      ProductVariant(
        id: 'intl-kit-romaji-airport',
        optionSelections: const {'script': 'romaji', 'bundle': 'airport'},
        displayLabel: 'Romaji / Airport Pickup',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1600',
          'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1600&sat=-20',
        ],
        price: const CatalogMoney(amount: 219, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 219, currency: 'USD'),
            note: 'Airport pickup at HND/NRT',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.preorder,
          label: 'Pre-order',
          detail: 'Pickup slots available next month',
        ),
        leadTime: 'Pickup slots open starting next month',
      ),
    ];

    return ProductDetail(
      id: 'intl-kit',
      name: 'Global Shipping Seal Kit',
      subtitle: 'Custom stamp with bilingual documentation',
      description:
          'Everything needed to stamp abroad confidently. Includes bilingual manuals, customs-ready paperwork, and expedited global shipping.',
      baseProduct: baseProduct,
      badges: const ['Worldwide shipping', 'Bilingual support'],
      highlights: const [
        'Includes customs-ready documentation in English and Japanese',
        'Complimentary virtual onboarding session',
        'Engraved in titanium with lifetime warranty',
      ],
      specs: [
        ProductSpec(label: 'SKU', value: baseProduct.sku),
        const ProductSpec(label: 'Material', value: 'Titanium'),
        const ProductSpec(label: 'Weight', value: 'Approx. 180g'),
        const ProductSpec(
          label: 'Warranty',
          value: 'Lifetime engraving warranty',
        ),
        const ProductSpec(
          label: 'Shipping',
          value: 'DHL Express',
          detail: 'Tracking updates in English included',
        ),
      ],
      variantGroups: variantGroups,
      variants: variants,
      includedItems: const [
        'Titanium stamp with selected engraving',
        'Bilingual usage and etiquette guide',
        'Customs-ready paperwork and pouch',
        'Ink pad suitable for overseas documents',
      ],
      careNote:
          'Clean with the included cloth and store dry. Avoid exposure to salt water.',
      shippingNote: 'Ships from Tokyo with full customs documentation.',
      requiresDesignSelection: true,
    );
  }

  static ProductDetail _buildCulturalSetDetail() {
    final baseProduct = _baseProduct(
      id: 'cultural-set',
      sku: 'CULTURE-GIFT-SET',
      materialRef: 'cultural-bundle',
      shape: CatalogProductShape.square,
      sizeMm: 12,
      baseAmount: 129,
      currency: 'USD',
      photos: const [
        'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1200',
      ],
      attributes: const {'bundle': true},
    );
    final variantGroups = [
      ProductVariantGroup(
        id: 'language',
        label: 'Guide Language',
        options: [
          const ProductVariantOption(id: 'english', label: 'English'),
          const ProductVariantOption(id: 'french', label: 'French'),
          const ProductVariantOption(id: 'spanish', label: 'Spanish'),
        ],
      ),
      ProductVariantGroup(
        id: 'bundle',
        label: 'Bundle Extras',
        selectionType: ProductVariantSelectionType.chip,
        options: [
          const ProductVariantOption(id: 'standard', label: 'Standard'),
          const ProductVariantOption(id: 'culture', label: 'Culture Notes'),
          const ProductVariantOption(id: 'premium', label: 'Premium Keepsake'),
        ],
      ),
    ];
    final variants = [
      ProductVariant(
        id: 'cultural-set-english-standard',
        optionSelections: const {'language': 'english', 'bundle': 'standard'},
        displayLabel: 'English / Standard',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1600',
          'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1600&sat=-20',
        ],
        price: const CatalogMoney(amount: 129, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 129, currency: 'USD'),
            note: 'Includes digital guide',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.inStock,
          label: 'Ships today',
        ),
        leadTime: 'Ships in 24 hours',
      ),
      ProductVariant(
        id: 'cultural-set-english-premium',
        optionSelections: const {'language': 'english', 'bundle': 'premium'},
        displayLabel: 'English / Premium Keepsake',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1400&sat=-20',
        galleryImages: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1600',
        ],
        price: const CatalogMoney(amount: 169, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 169, currency: 'USD'),
            note: 'Includes artisan case',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.limited,
          label: 'Low inventory',
          detail: 'Handmade keepsake case',
        ),
        leadTime: 'Ships in 2 business days',
      ),
      ProductVariant(
        id: 'cultural-set-spanish-culture',
        optionSelections: const {'language': 'spanish', 'bundle': 'culture'},
        displayLabel: 'Spanish / Culture Notes',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1600&sat=-20',
        ],
        price: const CatalogMoney(amount: 149, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 149, currency: 'USD'),
            note: 'Includes cultural audio guide',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.backorder,
          label: 'Ships next week',
        ),
        leadTime: 'Backorder: Ships next week',
      ),
    ];

    return ProductDetail(
      id: 'cultural-set',
      name: 'Kanji Culture Gift Set',
      subtitle: 'Learn etiquette alongside your seal',
      description:
          'A curated gift set combining a compact seal, bilingual culture guide, and etiquette notes to understand Japanese hanko traditions.',
      baseProduct: baseProduct,
      badges: const ['New', 'Gift ready'],
      highlights: const [
        'Includes culture and etiquette lessons in your language',
        'Comes gift-wrapped with a handwritten card option',
        'Digital onboarding videos and pronunciation guide',
      ],
      specs: [
        ProductSpec(label: 'SKU', value: baseProduct.sku),
        const ProductSpec(label: 'Case', value: 'Handmade fabric case'),
        const ProductSpec(label: 'Ink Pad', value: 'Quick-dry formula'),
        const ProductSpec(label: 'Guide', value: 'Bilingual 40-page booklet'),
      ],
      variantGroups: variantGroups,
      variants: variants,
      includedItems: const [
        'Compact seal with pre-selected design',
        'Bilingual etiquette guide',
        'Quick-dry ink pad',
        'Gift-ready wrapping and message card',
      ],
      careNote:
          'Store flat and clean the seal with the included cloth after each use.',
      shippingNote:
          'Ships from Tokyo with tracking for international delivery.',
    );
  }

  static ProductDetail _buildSignatureKitDetail() {
    final baseProduct = _baseProduct(
      id: 'signature-kit',
      sku: 'SIGNATURE-KIT',
      materialRef: 'hybrid-acrylic',
      shape: CatalogProductShape.square,
      sizeMm: 13,
      baseAmount: 210,
      currency: 'USD',

      stockQuantity: 32,
      stockSafety: 14,
      photos: const [
        'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200',
      ],
      attributes: const {'bundle': true, 'subscriptionEligible': true},
    );
    final variantGroups = [
      ProductVariantGroup(
        id: 'support',
        label: 'Support Level',
        options: [
          const ProductVariantOption(id: 'self', label: 'Self-serve'),
          const ProductVariantOption(id: 'guided', label: 'Guided'),
          const ProductVariantOption(id: 'concierge', label: 'Concierge'),
        ],
      ),
      ProductVariantGroup(
        id: 'duration',
        label: 'Support Duration',
        selectionType: ProductVariantSelectionType.chip,
        options: [
          const ProductVariantOption(id: '30days', label: '30 days'),
          const ProductVariantOption(id: '90days', label: '90 days'),
          const ProductVariantOption(id: '365days', label: '365 days'),
        ],
      ),
    ];
    final variants = [
      ProductVariant(
        id: 'signature-kit-self-30',
        optionSelections: const {'support': 'self', 'duration': '30days'},
        displayLabel: 'Self-serve / 30 days',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1600',
        ],
        price: const CatalogMoney(amount: 210, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 210, currency: 'USD'),
            note: 'Includes seal, case, and ink pad',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.inStock,
          label: 'Ready to ship',
        ),
        leadTime: 'Ships in 2 business days',
      ),
      ProductVariant(
        id: 'signature-kit-guided-90',
        optionSelections: const {'support': 'guided', 'duration': '90days'},
        displayLabel: 'Guided / 90 days',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?w=1600',
        ],
        price: const CatalogMoney(amount: 259, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 259, currency: 'USD'),
            note: 'Includes 1:1 onboarding session',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.limited,
          label: 'Few kits left',
          detail: 'Guided onboarding slots limited',
        ),
        leadTime: 'Ships in 3 business days',
      ),
      ProductVariant(
        id: 'signature-kit-concierge-365',
        optionSelections: const {'support': 'concierge', 'duration': '365days'},
        displayLabel: 'Concierge / 365 days',
        primaryImageUrl:
            'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1400',
        galleryImages: const [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600',
        ],
        price: const CatalogMoney(amount: 345, currency: 'USD'),
        pricingTiers: const [
          ProductPriceTier(
            minQuantity: 1,
            price: CatalogMoney(amount: 345, currency: 'USD'),
            note: '24/7 concierge and document review',
          ),
        ],
        stock: const ProductStockStatus(
          level: ProductStockLevel.preorder,
          label: 'Annual plan waitlist',
          detail: 'Next concierge intake in 3 weeks',
        ),
        leadTime: 'Ships when concierge intake opens',
      ),
    ];

    return ProductDetail(
      id: 'signature-kit',
      name: 'Signature Abroad Kit',
      subtitle: 'Support for stamping overseas throughout the year',
      description:
          'Designed for expats who need reliable signature tools abroad. Includes concierge support levels and document review services.',
      baseProduct: baseProduct,
      badges: const ['Support included', 'Subscription ready'],
      highlights: const [
        'Includes digital templates for overseas banking forms',
        'Optional concierge review for important documents',
        'Acrylic hybrid material resistant to humidity changes',
      ],
      specs: [
        ProductSpec(label: 'SKU', value: baseProduct.sku),
        const ProductSpec(label: 'Case', value: 'Water-resistant acrylic'),
        const ProductSpec(label: 'Support', value: 'Email & chat support'),
        const ProductSpec(label: 'Extras', value: 'Document review credits'),
      ],
      variantGroups: variantGroups,
      variants: variants,
      includedItems: const [
        'Hybrid acrylic stamp',
        'Water-resistant travel case',
        'Ink pad and refill cartridges',
        'Support plan welcome kit',
      ],
      careNote:
          'Wipe clean after each use. Store in the travel case to avoid drying.',
      shippingNote:
          'Ships with tracking and insurance. Support onboarding email sent immediately.',
      requiresDesignSelection: true,
    );
  }

  static final Map<String, ProductDetail> _domesticDetails = {
    'echizen-case': _buildCaseDetail(),
    'seal-2024': _buildSealDetail(),
  };

  static final Map<String, ProductDetail> _internationalDetails = {
    'intl-kit': _buildIntlKitDetail(),
    'cultural-set': _buildCulturalSetDetail(),
    'signature-kit': _buildSignatureKitDetail(),
  };
}
