import 'dart:math';

import 'package:app/features/search/domain/search_category.dart';
import 'package:app/features/search/domain/search_result.dart';

const _pageSize = 6;

class SearchRepository {
  const SearchRepository();

  static const List<String> _trendingQueries = [
    '丸枠テンプレート',
    'チタン印材',
    'はんこ手入れ',
    '電子印鑑',
    '配送状況の確認',
    '印影エディタの使い方',
  ];

  static const List<SearchResult> _catalog = [
    SearchResult(
      id: 'template-classic-01',
      title: '和文丸枠テンプレート A',
      description: 'クラシックな丸枠と縦書きフォントの組み合わせ。',
      category: SearchCategory.templates,
      badge: '人気',
      tags: ['丸枠', '和文'],
      metadata: '更新: 2024-02-14',
    ),
    SearchResult(
      id: 'template-classic-02',
      title: '角印テンプレート / 企業印向け',
      description: '会社名や役職が入る角印レイアウトの定番。',
      category: SearchCategory.templates,
      tags: ['角印', 'ビジネス'],
      metadata: '更新: 2024-01-22',
    ),
    SearchResult(
      id: 'template-modern-01',
      title: 'モダン英字テンプレート',
      description: '横書きで読みやすい欧文フォントを採用。',
      category: SearchCategory.templates,
      tags: ['欧文', '横書き'],
      metadata: '更新: 2024-03-01',
    ),
    SearchResult(
      id: 'template-modern-02',
      title: 'クリエイター向け矩形テンプレート',
      description: 'オルタナティブな線と余白を活かした構成。',
      category: SearchCategory.templates,
      badge: '新着',
      tags: ['矩形', 'クリエイティブ'],
      metadata: '更新: 2024-03-10',
    ),
    SearchResult(
      id: 'template-stamp-engraved',
      title: '彫りの深さ重視テンプレート',
      description: '細い線でも潰れにくいアウトラインを自動調整。',
      category: SearchCategory.templates,
      tags: ['彫刻', 'シャープ'],
      metadata: '更新: 2023-12-05',
    ),
    SearchResult(
      id: 'template-kanji-collection',
      title: '漢字コレクション / 旧字体対応',
      description: 'JIS第2水準までの旧字体を網羅。',
      category: SearchCategory.templates,
      badge: '特集',
      tags: ['旧字体', '漢字'],
      metadata: '更新: 2024-02-02',
    ),
    SearchResult(
      id: 'material-tsuge-premium',
      title: '柘植 (ツゲ) プレミアム',
      description: '国産木材の王道。繊細な彫刻と耐久性を両立。',
      category: SearchCategory.materials,
      badge: 'おすすめ',
      tags: ['木材', '軽量'],
      metadata: '在庫: ◎ / 納期 3日',
    ),
    SearchResult(
      id: 'material-ebony',
      title: '黒檀 / 重厚感のある仕上がり',
      description: '高級感を演出できる重さと手触りが特長。',
      category: SearchCategory.materials,
      tags: ['高級', '耐久'],
      metadata: '在庫: ○ / 納期 5日',
    ),
    SearchResult(
      id: 'material-titanium',
      title: 'チタン印材 マットグレー',
      description: '錆びにくくメンテが容易。電子押印とも相性◎。',
      category: SearchCategory.materials,
      badge: '耐久性',
      tags: ['金属', '長期保証'],
      metadata: '在庫: ◎ / 納期 翌日',
    ),
    SearchResult(
      id: 'material-crystal',
      title: 'クリスタルアクリル',
      description: '透明感が美しいギフト向け印材。',
      category: SearchCategory.materials,
      tags: ['透明', 'ギフト'],
      metadata: '在庫: △ / 納期 7日',
    ),
    SearchResult(
      id: 'material-bamboo',
      title: '竹集成材 / サステナブル',
      description: '環境配慮型素材。軽量で扱いやすい。',
      category: SearchCategory.materials,
      tags: ['エコ', '軽量'],
      metadata: '在庫: ○ / 納期 4日',
    ),
    SearchResult(
      id: 'material-horn',
      title: '牛角 (白) 透明感ランク極上',
      description: '希少な真っ白な牛角を厳選。法人印にも人気。',
      category: SearchCategory.materials,
      badge: '限定',
      tags: ['高級', '法人印'],
      metadata: '在庫: △ / 納期 6日',
    ),
    SearchResult(
      id: 'article-maintenance',
      title: '印鑑のお手入れ完全ガイド',
      description: '印材ごとの汚れの落とし方と保管ポイントを紹介。',
      category: SearchCategory.articles,
      tags: ['メンテナンス', '初心者'],
      metadata: '読了目安 6分',
    ),
    SearchResult(
      id: 'article-digital-seal',
      title: '電子印鑑と法的効力の解説',
      description: '電子署名との違い、押印データの扱いをわかりやすく。',
      category: SearchCategory.articles,
      tags: ['電子印鑑', '法務'],
      metadata: '読了目安 8分',
    ),
    SearchResult(
      id: 'article-name-kanji',
      title: '名字別・人気の漢字ランキング',
      description: '姓ごとの人気字体と避けたい文字の傾向を紹介。',
      category: SearchCategory.articles,
      badge: '特集',
      tags: ['ランキング', '漢字'],
      metadata: '読了目安 5分',
    ),
    SearchResult(
      id: 'article-order-flow',
      title: '初めての印鑑注文 手順と注意点',
      description: 'サイズ選びから発送まで、スクリーン別に解説。',
      category: SearchCategory.articles,
      tags: ['初心者', '購入ガイド'],
      metadata: '読了目安 7分',
    ),
    SearchResult(
      id: 'article-registrability',
      title: '印鑑登録 NG 事例集',
      description: '自治体ごとに異なる制限と申請のコツをまとめました。',
      category: SearchCategory.articles,
      tags: ['登録', '自治体'],
      metadata: '読了目安 4分',
    ),
    SearchResult(
      id: 'article-color-trend',
      title: 'カラフル印材のトレンド 2024',
      description: 'カラーパレット付きで選べる鮮やかな素材を特集。',
      category: SearchCategory.articles,
      tags: ['トレンド', 'カラー'],
      metadata: '読了目安 5分',
    ),
    SearchResult(
      id: 'faq-order-change',
      title: '注文後の内容変更はできますか？',
      description: '制作ステータス別の変更可否とサポート窓口をご案内。',
      category: SearchCategory.faq,
      tags: ['注文', '変更'],
      metadata: '更新: 2024-03-05',
    ),
    SearchResult(
      id: 'faq-shipping-status',
      title: '配送状況の確認方法を教えてください。',
      description: 'マイページと通知センターでの確認手順。',
      category: SearchCategory.faq,
      tags: ['配送', 'トラッキング'],
      metadata: '更新: 2024-02-28',
    ),
    SearchResult(
      id: 'faq-material-care',
      title: '木材印材のお手入れ方法は？',
      description: '水濡れ時の対処や乾燥を防ぐコツをまとめました。',
      category: SearchCategory.faq,
      tags: ['メンテナンス', '木材'],
      metadata: '更新: 2024-01-18',
    ),
    SearchResult(
      id: 'faq-digital-certificate',
      title: '電子印鑑データは提供されていますか？',
      description: 'PNG/SVG 形式での提供条件とダウンロード手順。',
      category: SearchCategory.faq,
      tags: ['電子印鑑', 'データ'],
      metadata: '更新: 2024-03-01',
    ),
    SearchResult(
      id: 'faq-return-policy',
      title: '誤植があった場合の返品・再制作について',
      description: '保証範囲と連絡方法を紹介。',
      category: SearchCategory.faq,
      tags: ['保証', '返品'],
      metadata: '更新: 2024-02-05',
    ),
    SearchResult(
      id: 'faq-payment-methods',
      title: '利用可能なお支払い方法を教えてください。',
      description: 'クレジット/QR/法人請求書決済などに対応。',
      category: SearchCategory.faq,
      tags: ['決済', '法人'],
      metadata: '更新: 2023-12-20',
    ),
  ];

  Future<SearchResultPage> search({
    required SearchCategory category,
    required String query,
    required int page,
    int pageSize = _pageSize,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalizedQuery = query.trim();
    final filtered = _catalog.where((result) {
      if (result.category != category) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final lower = normalizedQuery.toLowerCase();
      final haystack = [
        result.title,
        result.description,
        result.metadata ?? '',
        ...result.tags,
      ].join(' ').toLowerCase();
      return haystack.contains(lower);
    }).toList();

    final start = page * pageSize;
    final end = min(start + pageSize, filtered.length);
    final items = start >= filtered.length
        ? <SearchResult>[]
        : filtered.sublist(start, end);
    return SearchResultPage(
      items: items,
      hasMore: end < filtered.length,
      totalAvailable: filtered.length,
    );
  }

  Future<List<String>> suggestions(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _trendingQueries.take(5).toList();
    }
    final matches = <String>{};
    for (final result in _catalog) {
      if (result.title.toLowerCase().contains(normalized)) {
        matches.add(result.title);
      }
      if (result.description.toLowerCase().contains(normalized)) {
        matches.add(result.description);
      }
      for (final tag in result.tags) {
        if (tag.toLowerCase().contains(normalized)) {
          matches.add(tag);
        }
      }
      if (matches.length >= 6) {
        break;
      }
    }
    if (matches.isEmpty) {
      return _trendingQueries
          .where((element) => element.toLowerCase().contains(normalized))
          .take(5)
          .toList();
    }
    return matches.take(6).toList();
  }

  List<String> trendingQueries() => _trendingQueries;
}
