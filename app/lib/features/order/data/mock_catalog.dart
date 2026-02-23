import '../domain/order_models.dart';

const mockCatalog = CatalogData(
  fonts: [
    FontOption(
      key: 'zen_maru_gothic',
      label: 'Zen Maru Gothic',
      family: "'Zen Maru Gothic', sans-serif",
      kanjiStyle: KanjiStyle.japanese,
    ),
    FontOption(
      key: 'kosugi_maru',
      label: 'Kosugi Maru',
      family: "'Kosugi Maru', sans-serif",
      kanjiStyle: KanjiStyle.chinese,
    ),
    FontOption(
      key: 'potta_one',
      label: 'Potta One',
      family: "'Potta One', sans-serif",
      kanjiStyle: KanjiStyle.taiwanese,
    ),
    FontOption(
      key: 'kiwi_maru',
      label: 'Kiwi Maru',
      family: "'Kiwi Maru', sans-serif",
      kanjiStyle: KanjiStyle.japanese,
    ),
    FontOption(
      key: 'wdxl_lubrifont_jp_n',
      label: 'WDXL Lubrifont JP N',
      family: "'WDXL Lubrifont JP N', sans-serif",
      kanjiStyle: KanjiStyle.chinese,
    ),
  ],
  materials: [
    MaterialOption(
      key: 'boxwood',
      label: '柘植',
      description: '軽くて扱いやすい定番材',
      shape: SealShape.square,
      shapeLabel: '角印',
      price: 3600,
      photoUrl: 'https://picsum.photos/seed/hf-boxwood/640/420',
      photoAlt: '柘植材の写真',
      hasPhoto: true,
    ),
    MaterialOption(
      key: 'black_buffalo',
      label: '黒水牛',
      description: 'しっとりした質感で耐久性が高い',
      shape: SealShape.round,
      shapeLabel: '丸印',
      price: 4800,
      photoUrl: 'https://picsum.photos/seed/hf-black-buffalo/640/420',
      photoAlt: '黒水牛材の写真',
      hasPhoto: true,
    ),
    MaterialOption(
      key: 'titanium',
      label: 'チタン',
      description: '重厚で摩耗に強いプレミアム材',
      shape: SealShape.square,
      shapeLabel: '角印',
      price: 9800,
      photoUrl: 'https://picsum.photos/seed/hf-titanium/640/420',
      photoAlt: 'チタン材の写真',
      hasPhoto: true,
    ),
  ],
  countries: [
    CountryOption(code: 'JP', label: '日本', shipping: 600),
    CountryOption(code: 'US', label: 'アメリカ', shipping: 1800),
    CountryOption(code: 'CA', label: 'カナダ', shipping: 1900),
    CountryOption(code: 'GB', label: 'イギリス', shipping: 2000),
    CountryOption(code: 'AU', label: 'オーストラリア', shipping: 2100),
    CountryOption(code: 'SG', label: 'シンガポール', shipping: 1300),
  ],
);
