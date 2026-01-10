// ignore_for_file: public_member_api_docs

import 'package:app/features/catalog/data/models/catalog_models.dart'
    as catalog;
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum MaterialMediaType { image, video }

class MaterialMedia {
  const MaterialMedia({required this.url, required this.type, this.caption});

  final String url;
  final MaterialMediaType type;
  final String? caption;
}

class MaterialAvailabilityInfo {
  const MaterialAvailabilityInfo({
    required this.statusLabel,
    required this.windowLabel,
    required this.badges,
    this.note,
  });

  final String statusLabel;
  final String windowLabel;
  final List<String> badges;
  final String? note;
}

class MaterialDetailState {
  const MaterialDetailState({
    required this.material,
    required this.tagline,
    required this.media,
    required this.availability,
    required this.compatibleProductRefs,
    required this.surfaceFinish,
    this.isFavorite = false,
  });

  final catalog.Material material;
  final String tagline;
  final List<MaterialMedia> media;
  final MaterialAvailabilityInfo availability;
  final List<String> compatibleProductRefs;
  final String surfaceFinish;
  final bool isFavorite;

  MaterialDetailState copyWith({bool? isFavorite}) {
    return MaterialDetailState(
      material: material,
      tagline: tagline,
      media: media,
      availability: availability,
      compatibleProductRefs: compatibleProductRefs,
      surfaceFinish: surfaceFinish,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class MaterialDetailViewModel extends AsyncProvider<MaterialDetailState> {
  MaterialDetailViewModel({required this.materialId})
    : super.args((materialId,), autoDispose: true);

  final String materialId;

  late final toggleFavoriteMut = mutation<bool>(#toggleFavorite);

  @override
  Future<MaterialDetailState> build(
    Ref<AsyncValue<MaterialDetailState>> ref,
  ) async {
    final gates = ref.watch(appExperienceGatesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final seeds = _seedMaterialDetails(gates);
    final detail = seeds[materialId];
    if (detail == null) {
      throw StateError('Material not found');
    }
    return detail;
  }

  Call<bool, AsyncValue<MaterialDetailState>> toggleFavorite() =>
      mutate(toggleFavoriteMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return false;
        final next = !current.isFavorite;
        ref.state = AsyncData(current.copyWith(isFavorite: next));
        return next;
      }, concurrency: Concurrency.dropLatest);
}

Map<String, MaterialDetailState> _seedMaterialDetails(
  AppExperienceGates gates,
) {
  final now = DateTime.now();
  final prefersEnglish = gates.prefersEnglish;
  final intl = gates.emphasizeInternationalFlows;

  return {
    'titanium-matte': MaterialDetailState(
      material: catalog.Material(
        id: 'titanium-matte',
        name: prefersEnglish ? 'Matte titanium' : 'マットチタン',
        type: catalog.MaterialType.titanium,
        finish: catalog.MaterialFinish.matte,
        color: prefersEnglish ? 'Cool silver' : 'シルバー',
        hardness: 6.0,
        density: 4.5,
        careNotes: prefersEnglish
            ? 'Wipe after use; hypoallergenic and rust free.'
            : '使用後に拭き取り。金属アレルギー対応で錆びません。',
        sustainability: const catalog.Sustainability(
          certifications: ['Recycled 30%'],
          notes: 'Machining scraps recovered',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=60',
          'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=1200&q=60',
        ],
        supplier: catalog.MaterialSupplier(
          reference: 'TI-ALLOY',
          name: prefersEnglish ? 'Niigata Alloy Works' : '新潟アロイ工房',
          leadTimeDays: intl ? 4 : 3,
          minimumOrderQuantity: 10,
          unitCostCents: 2600,
          currency: 'JPY',
        ),
        inventory: const catalog.MaterialInventory(
          sku: 'MAT-TI-01',
          safetyStock: 24,
          reorderPoint: 12,
          reorderQuantity: 30,
          warehouse: 'Tokyo',
        ),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 190)),
        updatedAt: now.subtract(const Duration(days: 9)),
      ),
      tagline: prefersEnglish ? 'Clean edges, light feel' : 'シャープな印影と軽さ',
      surfaceFinish: prefersEnglish ? 'Bead-blasted matte' : 'ビーズショットマット',
      media: const [
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Macro view of the matte grain',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1471357674240-e1a485acb3e1?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Edge polish after engraving',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1503389152951-9f343605f61e?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.video,
          caption: 'Short clip: clamp test and surface wipe',
        ),
      ],
      availability: MaterialAvailabilityInfo(
        statusLabel: prefersEnglish ? 'In stock' : '在庫あり',
        windowLabel: intl ? 'Ships in 3-4 biz days (DHL)' : '国内3-4営業日で発送',
        badges: [
          prefersEnglish ? 'Priority polish' : '優先仕上げ',
          prefersEnglish ? 'Hypoallergenic' : '金属アレルギー対応',
        ],
        note: prefersEnglish
            ? 'Slots reserved for bilingual/company seals.'
            : '社名・英字刻印の優先枠があります。',
      ),
      compatibleProductRefs: const ['round-classic', 'square-business'],
      isFavorite: true,
    ),
    'horn-premium': MaterialDetailState(
      material: catalog.Material(
        id: 'horn-premium',
        name: prefersEnglish ? 'Premium horn' : '本牛角 プレミアム',
        type: catalog.MaterialType.horn,
        finish: catalog.MaterialFinish.gloss,
        color: prefersEnglish ? 'Amber gloss' : '琥珀色の艶',
        hardness: 2.8,
        density: 1.3,
        careNotes: prefersEnglish
            ? 'Keep dry, avoid direct sunlight.'
            : '直射日光を避けて乾燥保管。',
        sustainability: const catalog.Sustainability(
          certifications: ['Responsible sourced'],
          notes: 'Traceable lot with vet checks',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
        ],
        supplier: catalog.MaterialSupplier(
          reference: 'HORN-A1',
          name: prefersEnglish ? 'Kochi Craft' : '高知クラフト',
          leadTimeDays: intl ? 6 : 5,
          minimumOrderQuantity: 8,
          unitCostCents: 2100,
          currency: 'JPY',
        ),
        inventory: const catalog.MaterialInventory(
          sku: 'MAT-HORN-02',
          safetyStock: 10,
          reorderPoint: 6,
          reorderQuantity: 18,
          warehouse: 'Osaka',
        ),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 420)),
        updatedAt: now.subtract(const Duration(days: 14)),
      ),
      tagline: prefersEnglish ? 'Rich gloss with warm tone' : '深い艶と温かみ',
      surfaceFinish: prefersEnglish ? 'Hand buffed gloss' : '手磨き艶仕上げ',
      media: const [
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Subtle grain and layered hue',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1504595403659-9088ce801e29?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Side polish with gloss protection',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.video,
          caption: 'Short clip: conditioning oil application',
        ),
      ],
      availability: MaterialAvailabilityInfo(
        statusLabel: prefersEnglish ? 'Limited batches' : '数量限定',
        windowLabel: prefersEnglish ? 'Ships in 5-6 biz days' : '5-6営業日で発送',
        badges: [
          prefersEnglish ? 'Hand polished' : '手磨き',
          prefersEnglish ? 'Classic look' : '定番質感',
        ],
        note: prefersEnglish
            ? 'Seasonal humidity checks add 0.5 day.'
            : '季節湿度のチェックで半日追加される場合があります。',
      ),
      compatibleProductRefs: const ['round-classic', 'oval-heritage'],
    ),
    'sakura-wood': MaterialDetailState(
      material: catalog.Material(
        id: 'sakura-wood',
        name: prefersEnglish ? 'Sakura wood' : 'さくら材',
        type: catalog.MaterialType.wood,
        finish: catalog.MaterialFinish.matte,
        color: prefersEnglish ? 'Blush wood' : '桜色',
        hardness: 2.1,
        density: 0.9,
        careNotes: prefersEnglish
            ? 'Avoid moisture; re-oil yearly.'
            : '湿気を避け、年1回オイルで手入れ。',
        sustainability: const catalog.Sustainability(
          certifications: ['FSC'],
          notes: 'Re-planted every 5 years',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=60',
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
        ],
        supplier: catalog.MaterialSupplier(
          reference: 'WOOD-SAKURA',
          name: prefersEnglish ? 'Nagano Forestry' : '長野フォレストリー',
          leadTimeDays: intl ? 5 : 4,
          minimumOrderQuantity: 6,
          unitCostCents: 1200,
          currency: 'JPY',
        ),
        inventory: const catalog.MaterialInventory(
          sku: 'MAT-WOOD-03',
          safetyStock: 14,
          reorderPoint: 8,
          reorderQuantity: 20,
          warehouse: 'Nagano',
        ),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 260)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      tagline: prefersEnglish ? 'Warm feel and soft press' : 'やさしい押し心地',
      surfaceFinish: prefersEnglish ? 'Oil sealed matte' : 'オイルシールマット',
      media: const [
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Fine grain with soft edges',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Tone shifts under daylight',
        ),
      ],
      availability: MaterialAvailabilityInfo(
        statusLabel: prefersEnglish ? 'Made-to-order' : '受注生産',
        windowLabel: prefersEnglish ? 'Ships in 4-5 biz days' : '4-5営業日で発送',
        badges: [
          prefersEnglish ? 'Eco pick' : 'エコ素材',
          prefersEnglish ? 'Bank-in safe' : '銀行印対応',
        ],
        note: prefersEnglish
            ? 'Seasonal wood movement monitored before engraving.'
            : '刻印前に木材の反りを確認しています。',
      ),
      compatibleProductRefs: const ['round-soft', 'square-handwritten'],
    ),
    'color-acrylic': MaterialDetailState(
      material: catalog.Material(
        id: 'color-acrylic',
        name: prefersEnglish ? 'Color acrylic' : 'カラーアクリル',
        type: catalog.MaterialType.acrylic,
        finish: catalog.MaterialFinish.matte,
        color: prefersEnglish ? 'Ivory / translucent' : 'アイボリー半透明',
        hardness: 2.4,
        density: 1.18,
        careNotes: prefersEnglish
            ? 'Wipe with dry cloth; avoid acetone.'
            : '乾いた布で拭き、アセトンは避けてください。',
        sustainability: const catalog.Sustainability(
          certifications: ['RoHS'],
          notes: 'Low-VOC coating',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
        ],
        supplier: catalog.MaterialSupplier(
          reference: 'ACR-CL',
          name: prefersEnglish ? 'Saitama Resin' : '埼玉レジン',
          leadTimeDays: intl ? 4 : 3,
          minimumOrderQuantity: 12,
          unitCostCents: 800,
          currency: 'JPY',
        ),
        inventory: const catalog.MaterialInventory(
          sku: 'MAT-ACR-04',
          safetyStock: 30,
          reorderPoint: 15,
          reorderQuantity: 40,
          warehouse: 'Saitama',
        ),
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
      tagline: prefersEnglish ? 'Playful, resilient colors' : '遊び心ある耐久カラー',
      surfaceFinish: prefersEnglish ? 'Matte anti-glare' : 'マット・アンチグレア',
      media: const [
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Translucent edge under light',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.image,
          caption: 'Color blend sample',
        ),
        MaterialMedia(
          url:
              'https://images.unsplash.com/photo-1522778119026-d647f0596c20?auto=format&fit=crop&w=1200&q=60',
          type: MaterialMediaType.video,
          caption: 'Short clip: scratch test and wipe down',
        ),
      ],
      availability: MaterialAvailabilityInfo(
        statusLabel: prefersEnglish ? 'Ready to ship' : 'すぐ出荷可能',
        windowLabel: prefersEnglish ? '48h quick slot' : '48時間クイック枠',
        badges: [
          prefersEnglish ? 'Lightweight' : '軽量',
          prefersEnglish ? 'Water safe' : '耐水',
        ],
        note: prefersEnglish
            ? 'Fast lane recommended for replacement seals.'
            : '予備印にはクイック枠がおすすめ。',
      ),
      compatibleProductRefs: const ['round-color', 'square-modern'],
    ),
  };
}
