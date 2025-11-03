import 'dart:async';

import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/catalog.dart';
import 'package:app/features/shop/domain/material_detail.dart';

abstract class MaterialDetailRepository {
  Future<MaterialDetail> fetchMaterialDetail({
    required String materialId,
    required ExperienceGate experience,
  });
}

class FakeMaterialDetailRepository implements MaterialDetailRepository {
  const FakeMaterialDetailRepository();

  @override
  Future<MaterialDetail> fetchMaterialDetail({
    required String materialId,
    required ExperienceGate experience,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final detail = _details[materialId];
    if (detail == null) {
      throw StateError('Material $materialId not found');
    }
    if (experience.isInternational &&
        _internationalOverrides.containsKey(materialId)) {
      return _internationalOverrides[materialId]!;
    }
    return detail;
  }

  static CatalogMaterial _material({
    required String id,
    required String name,
    required CatalogMaterialType type,
    CatalogMaterialFinish? finish,
    String? color,
    double? hardness,
    double? density,
    String? careNotes,
    CatalogMaterialSustainability? sustainability,
    List<String> photos = const [],
  }) {
    return CatalogMaterial(
      id: id,
      name: name,
      type: type,
      finish: finish,
      color: color,
      hardness: hardness,
      density: density,
      careNotes: careNotes,
      sustainability: sustainability,
      photos: photos,
      isActive: true,
      createdAt: DateTime(2023, 6, 1),
    );
  }

  static MaterialDetail _detail({
    required CatalogMaterial material,
    required String description,
    required List<String> highlights,
    required List<MaterialMedia> media,
    required List<MaterialSpec> specs,
    required MaterialAvailability availability,
    List<String> compatibleProductIds = const [],
  }) {
    return MaterialDetail(
      material: material,
      description: description,
      highlights: highlights,
      media: media,
      specs: specs,
      availability: availability,
      compatibleProductIds: compatibleProductIds,
    );
  }

  static final Map<String, MaterialDetail> _details = <String, MaterialDetail>{
    'tsuge': _detail(
      material: _material(
        id: 'tsuge',
        name: '国産柘',
        type: CatalogMaterialType.wood,
        finish: CatalogMaterialFinish.matte,
        color: '淡黄色',
        hardness: 3.2,
        density: 0.95,
        careNotes: '乾燥を避け、直射日光の当たらない場所で保管。',
        sustainability: const CatalogMaterialSustainability(
          certifications: ['森林認証 FSC'],
          notes: '鹿児島県産の間伐材を採用しています。',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1616628182503-86f8804ec731?w=1200',
          'https://images.unsplash.com/photo-1565538810643-b5bdb714032a?w=1200',
        ],
      ),
      description: '朱肉との相性が良く、銀行印にも選ばれる国内産の定番素材です。',
      highlights: const ['手に馴染む軽やかな押し心地', '国内工房で含浸加工済み', '銀行印の登録実績多数'],
      media: const [
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1616628182503-86f8804ec731?w=1600',
          caption: '鹿児島産柘の木目アップ',
        ),
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1565538810643-b5bdb714032a?w=1600',
          caption: '含浸加工後の仕上がり',
        ),
      ],
      specs: const [
        MaterialSpec(
          kind: MaterialSpecKind.hardness,
          label: '硬度',
          value: 'Janka 3.2',
          detail: '軽さと押しやすさのバランスが良い硬さです。',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.texture,
          label: '質感',
          value: '緻密で滑らか',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.origin,
          label: '産地',
          value: '鹿児島県指宿市',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.sustainability,
          label: 'サステナビリティ',
          value: 'FSC 認証材',
          detail: '鹿児島県産の間伐材を採用しています。',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.maintenance,
          label: 'お手入れ',
          value: '年1回の蜜蝋ケア推奨',
        ),
      ],
      availability: MaterialAvailability(
        statusLabel: '国内在庫あり',
        tags: ['即日発送', '職人仕上げ'],
        estimatedLeadTime: '国際配送: 5〜7 営業日',
        inventoryNote: '国内工房で毎週仕上げています。',
      ),
      compatibleProductIds: const ['seal-2024', 'premium-wood-case'],
    ),
    'kuro-sui': _detail(
      material: _material(
        id: 'kuro-sui',
        name: '黒水牛',
        type: CatalogMaterialType.horn,
        finish: CatalogMaterialFinish.gloss,
        color: '漆黒',
        hardness: 4.2,
        density: 1.25,
        careNotes: '高温多湿を避け、付属のケースで保管してください。',
        sustainability: const CatalogMaterialSustainability(
          certifications: ['副産物活用'],
          notes: '食肉副産物を再利用しています。',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=1200',
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200',
        ],
      ),
      description: '艶のある仕上がりで実印にも人気の高い素材です。',
      highlights: const ['耐摩耗性に優れた緻密な繊維', '光沢仕上げで上質感を演出', '手の温度で馴染む自然素材'],
      media: const [
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=1600',
          caption: '磨き上げた黒水牛の艶',
        ),
        MaterialMedia(
          type: MaterialMediaType.video,
          url: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
          previewImageUrl:
              'https://images.unsplash.com/photo-1524593135502-59f89d56a0e4?w=1600',
          caption: '工房での艶出し工程',
        ),
      ],
      specs: const [
        MaterialSpec(
          kind: MaterialSpecKind.hardness,
          label: '硬度',
          value: 'ロックウェル 88',
          detail: '高い耐摩耗性で印影が崩れにくい。',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.texture,
          label: '質感',
          value: '密度の高い滑らかさ',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.origin,
          label: '産地',
          value: 'ベトナム（国内仕上げ）',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.color,
          label: '色調',
          value: '漆黒（微かな縞模様）',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.maintenance,
          label: 'お手入れ',
          value: '乾いた布で油分を拭き取り、適度に保革。',
        ),
      ],
      availability: MaterialAvailability(
        statusLabel: '国内在庫わずか',
        tags: ['要予約', '職人磨き'],
        estimatedLeadTime: '追加研磨で 3〜4 営業日',
        inventoryNote: '艶出し工程に時間を要するため事前予約制。',
      ),
      compatibleProductIds: const ['seal-royal', 'lux-case'],
    ),
    'titanium': _detail(
      material: _material(
        id: 'titanium',
        name: 'チタン',
        type: CatalogMaterialType.titanium,
        finish: CatalogMaterialFinish.hairline,
        color: 'ガンメタル',
        hardness: 6.0,
        density: 4.5,
        careNotes: '水洗い後に柔らかい布で拭き取り乾燥させてください。',
        sustainability: const CatalogMaterialSustainability(
          certifications: ['リサイクル材 60%'],
        ),
        photos: const [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
          'https://images.unsplash.com/photo-1612209710411-5d952f4ef6be?w=1200',
        ],
      ),
      description: '半永久的に使える耐久性で法人印にも選ばれる素材です。',
      highlights: const ['汗や水分に強い耐食性', 'バランスの良い重量感', 'レーザー刻印に最適'],
      media: const [
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1600',
          caption: 'チタン素材の質感',
        ),
        MaterialMedia(
          type: MaterialMediaType.video,
          url: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
          previewImageUrl:
              'https://images.unsplash.com/photo-1612209710411-5d952f4ef6be?w=1600',
          caption: 'レーザー刻印の様子',
        ),
      ],
      specs: const [
        MaterialSpec(
          kind: MaterialSpecKind.hardness,
          label: '硬度',
          value: 'ビッカース 320',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.texture,
          label: '質感',
          value: 'ヘアライン加工',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.origin,
          label: '仕上げ',
          value: '新潟県燕三条',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.bestFor,
          label: 'おすすめ',
          value: '法人印・実印',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.maintenance,
          label: 'お手入れ',
          value: '水洗い可、研磨クロス付属',
        ),
      ],
      availability: MaterialAvailability(
        statusLabel: '常時製作可能',
        tags: ['工房直送', 'レーザー刻印'],
        estimatedLeadTime: '製作 7〜10 営業日',
      ),
      compatibleProductIds: const ['ti-pro', 'seal-2024'],
    ),
    'resin-air': _detail(
      material: _material(
        id: 'resin-air',
        name: 'エアレジン',
        type: CatalogMaterialType.acrylic,
        finish: CatalogMaterialFinish.gloss,
        color: 'シャンパンゴールド',
        hardness: 2.8,
        density: 1.2,
        careNotes: '柔らかい布で拭き掃除し、直射日光を避けてください。',
        sustainability: const CatalogMaterialSustainability(
          notes: 'リサイクル樹脂配合 30%',
        ),
        photos: const [
          'https://images.unsplash.com/photo-1600585154340-0ef3c08f0880?w=1200',
          'https://images.unsplash.com/photo-1527656855834-0235e41779fc?w=1200',
        ],
      ),
      description: '軽量で海外配送にも適した現代的な樹脂素材です。',
      highlights: const ['航空輸送でも安心の軽さ', 'UV コーティング済み', 'カラーカスタム対応'],
      media: const [
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1600585154340-0ef3c08f0880?w=1600',
          caption: 'エアレジンの透明感',
        ),
        MaterialMedia(
          type: MaterialMediaType.image,
          url:
              'https://images.unsplash.com/photo-1527656855834-0235e41779fc?w=1600',
          caption: '仕上げカラーのバリエーション',
        ),
      ],
      specs: const [
        MaterialSpec(
          kind: MaterialSpecKind.hardness,
          label: '硬度',
          value: 'ショア D 72',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.texture,
          label: '質感',
          value: 'ガラスライク',
        ),
        MaterialSpec(
          kind: MaterialSpecKind.bestFor,
          label: 'おすすめ',
          value: '海外発送・ギフト',
        ),
        MaterialSpec(kind: MaterialSpecKind.color, label: '色調', value: '6 色展開'),
      ],
      availability: MaterialAvailability(
        statusLabel: '国際モード推奨素材',
        tags: ['軽量', '即日出荷', '国際配送向け'],
        estimatedLeadTime: '国際配送: 3〜5 営業日',
      ),
      compatibleProductIds: const ['intl-kit', 'travel-case'],
    ),
  };

  static final Map<String, MaterialDetail> _internationalOverrides =
      <String, MaterialDetail>{
        'tsuge': _details['tsuge']!.copyWith(
          availability: MaterialAvailability(
            statusLabel: 'Worldwide shipping',
            tags: ['Ships in 48h', 'Lightweight'],
            estimatedLeadTime: 'Global: 7–9 business days',
            inventoryNote:
                'Finished weekly; customs friendly documentation included.',
          ),
        ),
        'resin-air': _details['resin-air']!.copyWith(
          highlights: const [
            'Featherlight for international shipping',
            'UV coated to prevent discoloration',
            'Comes with bilingual care guide',
          ],
        ),
      };
}
