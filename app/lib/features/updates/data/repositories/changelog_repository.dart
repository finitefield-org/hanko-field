// ignore_for_file: public_member_api_docs

import 'package:app/features/updates/data/models/changelog_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class ChangelogRepository {
  static const fallback = Scope<ChangelogRepository>.required(
    'changelog.repository',
  );

  Future<List<ChangelogRelease>> fetchChangelog();
}

final changelogRepositoryProvider = Provider<ChangelogRepository>((ref) {
  return LocalChangelogRepository();
});

class LocalChangelogRepository implements ChangelogRepository {
  @override
  Future<List<ChangelogRelease>> fetchChangelog() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _seedReleases();
  }

  List<ChangelogRelease> _seedReleases() {
    final now = DateTime.now();
    final releases = <ChangelogRelease>[
      ChangelogRelease(
        id: 'release-2-4-0',
        version: '2.4.0',
        releasedAt: now.subtract(const Duration(days: 6)),
        tier: ChangelogReleaseTier.major,
        heroTone: ChangelogHeroTone.sunset,
        title: const ChangelogCopy(
          en: 'Precision Preview Studio',
          ja: '精密プレビュースタジオ',
        ),
        summary: const ChangelogCopy(
          en: 'Dial in size, paper, and seal impressions before you order.',
          ja: '注文前に印影のサイズや紙質を細部まで確認できます。',
        ),
        highlights: const [
          ChangelogHighlight(
            title: ChangelogCopy(en: 'True-size previews', ja: '実寸プレビュー'),
            description: ChangelogCopy(
              en: 'Switch between paper stocks, ink tones, and seal angles.',
              ja: '紙の種類や朱肉の色、角度を切り替えられます。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Auto contrast assist', ja: '自動コントラスト補正'),
            description: ChangelogCopy(
              en: 'Improved edge clarity for detailed characters.',
              ja: '細部の文字でも輪郭がはっきり見えます。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Share-ready mockups', ja: '共有用モック'),
            description: ChangelogCopy(
              en: 'Export presentation images without watermarks.',
              ja: '透かしなしの共有画像を作成できます。',
            ),
          ),
        ],
        sections: const [
          ChangelogSection(
            title: ChangelogCopy(en: 'New', ja: '新機能'),
            items: [
              ChangelogCopy(
                en: 'Preview Studio with layered paper textures.',
                ja: '紙質レイヤーを切り替えられるプレビュースタジオ。',
              ),
              ChangelogCopy(
                en: 'Photo-backed proofs for outgoing shipments.',
                ja: '出荷前の写真プルーフを提供。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Improved', ja: '改善'),
            items: [
              ChangelogCopy(
                en: 'Faster render pipeline for large seals.',
                ja: '大型印鑑のレンダリング速度を向上。',
              ),
              ChangelogCopy(
                en: 'Sharper AI contrast for thin strokes.',
                ja: '細い線でもAI補正でくっきり表示。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Fixed', ja: '修正'),
            items: [
              ChangelogCopy(
                en: 'Resolved export crop on square layouts.',
                ja: '角印レイアウトの切り抜けを修正。',
              ),
            ],
          ),
        ],
      ),
      ChangelogRelease(
        id: 'release-2-3-1',
        version: '2.3.1',
        releasedAt: now.subtract(const Duration(days: 18)),
        tier: ChangelogReleaseTier.patch,
        heroTone: ChangelogHeroTone.indigo,
        title: const ChangelogCopy(en: 'Quiet polish update', ja: '軽微な改善'),
        summary: const ChangelogCopy(
          en: 'Smoother checkout and snappier order tracking.',
          ja: 'チェックアウトと配送追跡を改善しました。',
        ),
        highlights: const [
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Checkout resiliency', ja: '決済の安定性'),
            description: ChangelogCopy(
              en: 'Retry-friendly payment flow when networks drop.',
              ja: '通信が切れても安全に再試行できます。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Tracking refresh', ja: '追跡の更新性'),
            description: ChangelogCopy(
              en: 'New pull-to-refresh indicator and delay fixes.',
              ja: '更新インジケータと遅延表示を修正。',
            ),
          ),
        ],
        sections: const [
          ChangelogSection(
            title: ChangelogCopy(en: 'Improved', ja: '改善'),
            items: [
              ChangelogCopy(
                en: 'Saved payment method selection across sessions.',
                ja: '決済方法の選択を次回も保持。',
              ),
              ChangelogCopy(
                en: 'Order timeline updates now arrive within 2 minutes.',
                ja: '注文タイムライン更新の遅延を短縮。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Fixed', ja: '修正'),
            items: [
              ChangelogCopy(
                en: 'Corrected shipping address spacing in receipts.',
                ja: '領収書の住所表示を整形。',
              ),
            ],
          ),
        ],
      ),
      ChangelogRelease(
        id: 'release-2-3-0',
        version: '2.3.0',
        releasedAt: now.subtract(const Duration(days: 32)),
        tier: ChangelogReleaseTier.major,
        heroTone: ChangelogHeroTone.jade,
        title: const ChangelogCopy(
          en: 'Creator dashboard upgrade',
          ja: '作成ダッシュボード強化',
        ),
        summary: const ChangelogCopy(
          en: 'New templates, faster studio load, and guided tips.',
          ja: 'テンプレ追加、読み込み高速化、ヒント表示を追加。',
        ),
        highlights: const [
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Curated templates', ja: '厳選テンプレ'),
            description: ChangelogCopy(
              en: 'Seasonal stamp layouts and expert calligraphy picks.',
              ja: '季節テーマと書家監修のテンプレを追加。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Studio shortcuts', ja: '作成ショートカット'),
            description: ChangelogCopy(
              en: 'Jump back into the last edited design instantly.',
              ja: '最後に編集した印影へ即移動。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Guided tips', ja: 'ガイド付きヒント'),
            description: ChangelogCopy(
              en: 'Contextual tips for stroke width and spacing.',
              ja: '線幅や余白のヒントを表示。',
            ),
          ),
        ],
        sections: const [
          ChangelogSection(
            title: ChangelogCopy(en: 'New', ja: '新機能'),
            items: [
              ChangelogCopy(
                en: 'Designer tips panel with persona guidance.',
                ja: 'ペルソナ別の作成ヒントパネル。',
              ),
              ChangelogCopy(
                en: 'Template collections by material type.',
                ja: '素材別テンプレコレクション。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Improved', ja: '改善'),
            items: [
              ChangelogCopy(
                en: 'Load time for large SVG exports reduced by 30%.',
                ja: '大型SVGの書き出し時間を30%短縮。',
              ),
              ChangelogCopy(
                en: 'Reduced memory footprint in AI preview.',
                ja: 'AIプレビューのメモリ消費を削減。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Fixed', ja: '修正'),
            items: [
              ChangelogCopy(
                en: 'Resolved rare crashes on iOS 17 gallery view.',
                ja: 'iOS17のギャラリー表示でのクラッシュを修正。',
              ),
            ],
          ),
        ],
      ),
      ChangelogRelease(
        id: 'release-2-2-4',
        version: '2.2.4',
        releasedAt: now.subtract(const Duration(days: 54)),
        tier: ChangelogReleaseTier.minor,
        heroTone: ChangelogHeroTone.cedar,
        title: const ChangelogCopy(en: 'Background refinements', ja: '背景表示の改善'),
        summary: const ChangelogCopy(
          en: 'Updated mock backgrounds and smoother scrolling.',
          ja: '背景モックとスクロールを改善。',
        ),
        highlights: const [
          ChangelogHighlight(
            title: ChangelogCopy(en: 'New paper textures', ja: '新しい紙テクスチャ'),
            description: ChangelogCopy(
              en: 'Added warm kraft and premium washi options.',
              ja: 'クラフト紙と高級和紙を追加。',
            ),
          ),
          ChangelogHighlight(
            title: ChangelogCopy(en: 'Smoother scroll', ja: 'スクロール改善'),
            description: ChangelogCopy(
              en: 'Optimized list rendering for long catalogs.',
              ja: '長いリストの描画を最適化。',
            ),
          ),
        ],
        sections: const [
          ChangelogSection(
            title: ChangelogCopy(en: 'Improved', ja: '改善'),
            items: [
              ChangelogCopy(
                en: 'Reduced latency when switching preview backgrounds.',
                ja: '背景切り替えの遅延を削減。',
              ),
              ChangelogCopy(
                en: 'Enhanced contrast for dark ink options.',
                ja: '濃い朱肉のコントラストを改善。',
              ),
            ],
          ),
          ChangelogSection(
            title: ChangelogCopy(en: 'Fixed', ja: '修正'),
            items: [
              ChangelogCopy(
                en: 'Fixed overlapping labels in the export sheet.',
                ja: '書き出しシートのラベル重なりを修正。',
              ),
            ],
          ),
        ],
      ),
    ];

    releases.sort((a, b) => b.releasedAt.compareTo(a.releasedAt));
    return releases;
  }
}
