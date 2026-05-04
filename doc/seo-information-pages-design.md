# SEO向け静的情報ページ設計（印鑑・宝石・多言語）

## 1. 目的
Hanko Field / STONE SIGNATURE に、印鑑と宝石印材についての多言語情報ページを追加し、自然検索から購入導線へつなげるための設計を定義する。

SEO用の情報ページは、ビルド時にすべてHTMLとして生成する。Firestoreや管理画面のデータから本文HTMLを作成しない。

対象は `web`。`app` は対象外。`admin` もSEOページ編集には使わない。公開コンテンツ内の用語・材質説明は、`doc/firebase-firestore-design.md` の材質マスタと矛盾しないようにする。

## 2. 前提
- `web` は Rust / htmx / ironframe / askama で実装する。
- SEO情報ページはリポジトリ内の静的コンテンツファイルからビルド時に生成する。
- SEO情報ページの生成器は Go で実装し、HTMLレンダリングには標準ライブラリの `html/template` を使う。
- SEO情報ページの静的HTML生成には Askama を使わない。Askama は既存のRust動的ページ用に限定する。
- SEO情報ページのHTML、sitemap、リダイレクト定義はビルド成果物としてコンテナに含める。
- SEO情報ページの本文生成にFirestoreを使わない。
- SEO情報ページの編集に `admin` を使わない。
- `web` / `admin` ではポーリング、SSE、WebSocketなどのストリーミングを使わない。
- 初期対応ロケールは `en` / `ja`。追加ロケールは BCP 47 の言語タグで拡張する。
- 既存の注文・決済ページは現行仕様を維持し、SEO情報ページだけを新しいURL体系で追加する。

## 3. SEO基本方針
- 量産よりも、検索意図ごとに十分な内容を持つページを作る。薄いページ、翻訳だけで内容差がないページ、同じ内容の言い換えページは作らない。
- 情報ページは静的HTMLで返し、本文・見出し・内部リンク・構造化データを初回レスポンスに含める。
- URLは短く、意味が分かる英語スラッグにする。日本語ページでもスラッグは共通英語スラッグを使い、言語はパスプレフィックスで表す。
- 各ロケールの本文が翻訳済みの場合、各ロケールURLをインデックス対象にし、各ページは self-canonical にする。
- `hreflang` はHTMLの `<head>` とXML sitemapにビルド時生成し、各言語ページが自分自身と他言語ページを双方向に参照する。
- 公開ページは `index,follow`、プレビュー・下書き・検索結果・フィルタ付き一覧は `noindex` にする。
- 構造化データは、画面上に見えている内容だけをJSON-LDで出力する。

参考にしたGoogle公式方針:
- 多言語ページは `hreflang` で各言語版を明示し、各言語版が自分自身と他言語版を列挙する。
- canonical URLとsitemap URLは絶対URLを使う。
- sitemapには検索結果に出したいURLを入れ、公開URLの `lastmod` は本文や構造化データなどの重要変更時だけ更新する。
- 構造化データはJSON-LDを優先し、ユーザに見えない内容をマークアップしない。

## 4. URL設計

### 4.1 URL体系
初期対応:

| ページ種別 | 英語URL（既定ロケール） | 日本語URL |
| --- | --- | --- |
| 情報トップ | `/learn` | `/ja/learn` |
| 印鑑カテゴリ | `/learn/seals` | `/ja/learn/seals` |
| 宝石カテゴリ | `/learn/gemstones` | `/ja/learn/gemstones` |
| 印鑑記事 | `/learn/seals/{slug}` | `/ja/learn/seals/{slug}` |
| 宝石記事 | `/learn/gemstones/{slug}` | `/ja/learn/gemstones/{slug}` |
| 材質ガイド | `/learn/materials/{material_key}` | `/ja/learn/materials/{material_key}` |

追加ロケール:

| ロケール | URL例 |
| --- | --- |
| `zh-Hant` | `/zh-Hant/learn/gemstones/jade` |
| `zh-Hans` | `/zh-Hans/learn/gemstones/jade` |
| `ko` | `/ko/learn/seals/what-is-a-hanko` |

### 4.2 URLルール
- 既定ロケール `en` はロケールプレフィックスなし。
- 既定ロケール以外は `/{locale}/...` を付ける。
- スラッグは小文字ASCII、単語区切りはハイフン、末尾スラッシュなし。
- 公開後の `slug` / `material_key` は原則変更しない。
- 変更が必要な場合は `web/content/seo/redirects.toml` に旧URLを保存し、実行時に恒久リダイレクト（301）する。
- クエリパラメータで本文言語を切り替えるURLは新規情報ページでは使わない。
- `?lang=ja` など旧形式でアクセスされた場合は、対応するパス形式へ301リダイレクトする。
- タグ、色、模様などの絞り込みURLは情報ページとして扱わず、原則 `noindex`。

### 4.3 canonical / hreflang例
英語ページ `/learn/gemstones/jade`:

```html
<link rel="canonical" href="https://finitefield.org/learn/gemstones/jade">
<link rel="alternate" hreflang="en" href="https://finitefield.org/learn/gemstones/jade">
<link rel="alternate" hreflang="ja" href="https://finitefield.org/ja/learn/gemstones/jade">
<link rel="alternate" hreflang="x-default" href="https://finitefield.org/learn/gemstones/jade">
```

日本語ページ `/ja/learn/gemstones/jade`:

```html
<link rel="canonical" href="https://finitefield.org/ja/learn/gemstones/jade">
<link rel="alternate" hreflang="en" href="https://finitefield.org/learn/gemstones/jade">
<link rel="alternate" hreflang="ja" href="https://finitefield.org/ja/learn/gemstones/jade">
<link rel="alternate" hreflang="x-default" href="https://finitefield.org/learn/gemstones/jade">
```

本文が未翻訳のロケールはHTMLを生成せず、`hreflang` とsitemapにも出さない。

## 5. 初期ページ計画

### 5.1 ハブページ
| page_id | URL | 目的 |
| --- | --- | --- |
| `learn_home` | `/learn` | 情報ページ全体の入口。印鑑、宝石、材質ガイドへ導線を張る。 |
| `seal_hub` | `/learn/seals` | 印鑑の基礎、文化、名前選び、形状、手入れへのカテゴリ入口。 |
| `gemstone_hub` | `/learn/gemstones` | 宝石印材の基礎、種類、選び方、手入れへのカテゴリ入口。 |

### 5.2 印鑑ページ
| page_id | URL | 主な検索意図 |
| --- | --- | --- |
| `what_is_a_hanko` | `/learn/seals/what-is-a-hanko` | 印鑑とは何か、海外ユーザ向けのseal / stamp / signatureとの違い |
| `name_kanji_guide` | `/learn/seals/name-kanji-guide` | 名前を漢字にする考え方、読み、意味、注意点 |
| `round_vs_square_seals` | `/learn/seals/round-vs-square-seals` | 丸印と角印の違い、用途、見た目の選び方 |
| `seal_script_styles` | `/learn/seals/seal-script-styles` | 日本・中国・台湾スタイルの書体差 |
| `hanko_care` | `/learn/seals/care-and-storage` | 印鑑の保管、朱肉、手入れ |

### 5.3 宝石・材質ページ
| page_id | URL | 主な検索意図 |
| --- | --- | --- |
| `gemstone_seal_guide` | `/learn/gemstones/gemstone-seal-guide` | 宝石印鑑とは何か、木材や樹脂との違い |
| `how_to_choose_gemstone` | `/learn/gemstones/how-to-choose` | 色、模様、重さ、用途からの選び方 |
| `gemstone_care` | `/learn/gemstones/care-and-storage` | 宝石印材の保管、傷、衝撃、湿度 |
| `material_jade` | `/learn/materials/jade` | 翡翠・玉石系の特徴と選び方 |
| `material_qingtian_stone` | `/learn/materials/qingtian-stone` | 青田石の特徴 |
| `material_shoushan_stone` | `/learn/materials/shoushan-stone` | 寿山石の特徴 |
| `material_balin_stone` | `/learn/materials/balin-stone` | 巴林石の特徴 |
| `material_yili_stone` | `/learn/materials/yili-stone` | 伊犁石の特徴 |
| `material_laos_stone` | `/learn/materials/laos-stone` | ラオス石の特徴 |
| `material_xixia_stone` | `/learn/materials/xixia-stone` | 西峡石の特徴 |
| `material_frozen_stone` | `/learn/materials/frozen-stone` | 凍石の特徴 |

材質名や鉱物情報は誇張しない。産地、希少性、硬度、効能に関する断定は根拠がある場合だけ記載し、医療・金運・開運などの効能訴求はしない。

## 6. 静的コンテンツ構成

### 6.1 ディレクトリ
SEO情報ページの原稿と生成物は次のように管理する。

```text
web/
├── content/
│   └── seo/
│       ├── pages/
│       │   ├── learn_home/
│       │   │   ├── page.toml
│       │   │   ├── body.en.md
│       │   │   └── body.ja.md
│       │   └── material_jade/
│       │       ├── page.toml
│       │       ├── body.en.md
│       │       └── body.ja.md
│       └── redirects.toml
├── generated/
│   └── seo/
│       └── public/
│           ├── learn/
│           │   └── index.html
│           ├── ja/
│           │   └── learn/
│           │       └── index.html
│           └── sitemap.xml
├── static/
│   └── seo/
│       └── ...
└── tools/
    └── seo-pages/
        ├── go.mod
        ├── main.go
        ├── internal/
        │   └── ...
        └── templates/
            └── seo_page.gohtml
```

- `web/content/seo` はGit管理する原稿。
- `web/static/seo` は公開画像などの静的アセット。
- `web/generated/seo/public` はビルド時生成物。原則Git管理しない。
- `web/tools/seo-pages` は Go 製の静的HTML生成器。`html/template` のテンプレートもここで管理する。
- Cloud Runのruntime imageには `web/generated/seo/public` を含める。

### 6.2 `page.toml`
各ページは `web/content/seo/pages/{page_id}/page.toml` でメタ情報を持つ。

```toml
id = "material_jade"
kind = "material_guide"
section = "materials"
slug = "jade"
parent_id = "gemstone_hub"
material_key = "jade"
status = "published"
is_indexable = true
published_at = "2026-05-05"
reviewed_at = "2026-05-05"
updated_at = "2026-05-05"
related_page_ids = ["how_to_choose_gemstone", "gemstone_care"]
related_material_keys = ["qingtian-stone", "shoushan-stone"]

[image]
src = "/static/seo/materials/jade.webp"
width = 1600
height = 900

[locales.en]
title = "Jade seals"
meta_title = "Jade seals and gemstone hanko guide | STONE SIGNATURE"
meta_description = "Learn how jade is used for gemstone seals, how it looks, and how to choose it for a custom hanko."
lead = "Jade gives a stone seal a calm color, smooth feel, and lasting presence."
body = "body.en.md"
image_alt = "Green jade stone seal material"
is_published = true
updated_at = "2026-05-05"

[locales.ja]
title = "翡翠・玉石の印鑑"
meta_title = "翡翠・玉石の宝石印鑑ガイド | STONE SIGNATURE"
meta_description = "翡翠・玉石を宝石印鑑に使うときの特徴、色合い、選び方を解説します。"
lead = "翡翠・玉石は、落ち着いた色合いとなめらかな質感を楽しめる印材です。"
body = "body.ja.md"
image_alt = "緑色の翡翠印材"
is_published = true
updated_at = "2026-05-05"
```

### 6.3 `redirects.toml`
公開済みURLを変更した場合は `web/content/seo/redirects.toml` に旧URLを追加する。

```toml
[[redirects]]
from_path = "/learn/gemstones/jade-seals"
to_path = "/learn/materials/jade"
status_code = 301
reason = "Move jade from gemstone article to material guide"
```

リダイレクトは静的HTMLでは表現しない。ビルド時に `web/generated/seo/redirects.json` などへ変換し、`web` の実行時ハンドラがメモリ上の定義から301を返す。Firestoreは使わない。

## 7. ビルド時生成

### 7.1 生成コマンド
`web/tools/seo-pages` にSEOページ生成用のGoコマンドを追加する。

```text
web/tools/seo-pages/main.go
web/tools/seo-pages/templates/seo_page.gohtml
```

想定コマンド:

```sh
cd web/tools/seo-pages
go run . \
  -content-dir ../../content/seo \
  -out-dir ../../generated/seo/public \
  -redirects-out ../../generated/seo/redirects.json \
  -site-base-url https://finitefield.org
```

`web/Makefile` には `seo` ターゲットを追加し、`css` とDocker buildの前に実行する。

```make
seo:
	cd web/tools/seo-pages && go run . -content-dir ../../content/seo -out-dir ../../generated/seo/public -redirects-out ../../generated/seo/redirects.json -site-base-url https://finitefield.org
```

`css` ターゲットのスキャン対象には `web/tools/seo-pages/templates/**/*.gohtml` も含める。SEOページ用のクラス名はGoテンプレート内で静的に書き、動的に連結しない。

Docker buildでは、builder stageにGoを入れるか、Go生成専用stageを追加して `cd web/tools/seo-pages && go run . ...` を実行し、runtime stageへ `web/generated/seo/public` と `web/generated/seo/redirects.json` をコピーする。

### 7.2 生成処理
ビルドコマンドは次を行う。

1. `web/content/seo/pages/*/page.toml` を読む。
2. `status = "published"` のページだけ対象にする。
3. `locales.{locale}.is_published = true` の本文Markdownを読む。
4. MarkdownをHTMLへ変換し、許可済みタグだけにサニタイズする。
5. URL、canonical、`hreflang`、パンくず、関連リンクを解決する。
6. Goの `html/template` で `web/tools/seo-pages/templates/seo_page.gohtml` をレンダリングする。
7. `web/generated/seo/public/{url}/index.html` へ出力する。
8. `web/generated/seo/public/sitemap.xml` を出力する。
9. `web/generated/seo/redirects.json` を出力する。
10. URL重複、未解決関連リンク、未翻訳 `hreflang`、Markdown構造の不備があればビルドを失敗させる。

Markdownから生成した本文HTMLは、サニタイズ後にのみ `template.HTML` としてテンプレートへ渡す。それ以外の文字列は `html/template` の通常エスケープに任せる。

JSON-LDはGoの構造体から `encoding/json` で生成し、生成器内で安全性を担保したうえで `template.JS` として `<script type="application/ld+json">` に渡す。本文や `page.toml` の文字列を手書きJSONとして直接埋め込まない。

### 7.3 生成ファイル例
| URL | 生成先 |
| --- | --- |
| `/learn` | `web/generated/seo/public/learn/index.html` |
| `/learn/seals` | `web/generated/seo/public/learn/seals/index.html` |
| `/learn/seals/what-is-a-hanko` | `web/generated/seo/public/learn/seals/what-is-a-hanko/index.html` |
| `/ja/learn` | `web/generated/seo/public/ja/learn/index.html` |
| `/ja/learn/materials/jade` | `web/generated/seo/public/ja/learn/materials/jade/index.html` |

末尾スラッシュなしのURLで公開する。`/learn/` のような末尾スラッシュ付きアクセスは `/learn` へ301リダイレクトする。

## 8. ページテンプレート

### 8.1 共通構成
情報ページは `web/tools/seo-pages/templates/seo_page.gohtml` をGoの `html/template` として用意し、ビルド時にHTMLへ展開する。

必須要素:
- `<html lang="{locale}">`
- `<title>`
- `<meta name="description">`
- `<meta name="robots" content="index,follow">`
- self-canonical
- `hreflang` alternates
- OG / Twitter Card
- パンくずUI
- 本文上部のカテゴリ導線
- 関連記事
- 関連材質または「デザインする」CTA
- JSON-LD

### 8.2 本文構造
各記事は次の順序を基本にする。

1. H1
2. lead
3. 代表画像
4. 目次
5. H2本文セクション
6. 注意点・選び方・比較表
7. FAQ（画面表示のみ。構造化データは原則付けない）
8. 関連記事
9. 購入導線

FAQリッチリザルトはGoogle上で表示対象が限定されているため、Hanko Fieldでは初期実装で `FAQPage` 構造化データを出さない。FAQ自体はユーザ向け本文として表示する。

### 8.3 Markdownレンダリング
- 本文は `body.{locale}.md` にMarkdownで書く。
- Markdownはビルド時にHTML化し、許可済みタグだけにサニタイズする。
- サニタイズ済みの本文HTMLだけを `template.HTML` として扱う。
- Markdown内で許可する要素は `h2` / `h3` / `p` / `ul` / `ol` / `li` / `strong` / `em` / `a` / `table` / `thead` / `tbody` / `tr` / `th` / `td` / `blockquote` / `img`。
- 外部リンクはビルド時に警告し、必要に応じて `rel="nofollow noopener"` を付与する。
- 画像は `web/static/seo` 配下の公開画像だけ許可する。
- Markdown内にH1を含めない。H1は `page.toml` の `title` からテンプレートが出す。

## 9. 構造化データ

### 9.1 全情報ページ
全ページに `BreadcrumbList` を出す。パンくずはURL構造そのものではなく、ユーザが辿る自然な階層にする。

例:

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Learn", "item": "https://finitefield.org/learn" },
    { "@type": "ListItem", "position": 2, "name": "Gemstones", "item": "https://finitefield.org/learn/gemstones" },
    { "@type": "ListItem", "position": 3, "name": "Jade" }
  ]
}
```

### 9.2 記事ページ
`kind = article` のページは `Article` JSON-LDを出す。

必須・推奨項目:
- `headline`
- `description`
- `image`
- `datePublished`
- `dateModified`
- `author` は `Organization` として `STONE SIGNATURE`
- `publisher` は `Organization` として `STONE SIGNATURE`
- `mainEntityOfPage`

### 9.3 材質ガイド
材質ガイドは基本的に情報ページなので、初期実装では `Article` と `BreadcrumbList` のみ出す。販売中の個別出品ページではないため、価格や在庫を持たない `Product` 構造化データは出さない。

将来、個別の購入可能ページを `/shop/{listing_id}` のように公開する場合のみ、表示価格・在庫・配送情報と一致する `Product` / merchant listing の構造化データを検討する。

## 10. sitemap / robots

### 10.1 sitemap
`/sitemap.xml` はビルド時に生成する。Firestoreや実行時クエリから生成しない。

含めるURL:
- `/`
- `/design`
- `/terms`
- `/commercial-transactions`
- `page.toml` の `status = "published"`
- `locales.{locale}.is_published = true`
- `is_indexable = true`

除外するURL:
- `/admin`
- `/mock`
- `/kanji`
- `/purchase`
- `/payment/*`
- 下書き、プレビュー、アーカイブ
- フィルタ・検索結果などクエリ依存ページ

各ロケールURLごとに `<url>` を作り、その中に全ロケールの `xhtml:link` を同じ内容で出す。`lastmod` は `locales.{locale}.updated_at` を使い、本文・メタ・構造化データ・内部リンクが変わった場合だけ更新する。

2言語ページの例:

```xml
<url>
  <loc>https://finitefield.org/learn/gemstones/jade</loc>
  <lastmod>2026-05-05</lastmod>
  <xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/learn/gemstones/jade" />
  <xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/ja/learn/gemstones/jade" />
  <xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/learn/gemstones/jade" />
</url>
<url>
  <loc>https://finitefield.org/ja/learn/gemstones/jade</loc>
  <lastmod>2026-05-05</lastmod>
  <xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/learn/gemstones/jade" />
  <xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/ja/learn/gemstones/jade" />
  <xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/learn/gemstones/jade" />
</url>
```

sitemapが50,000 URLまたは50MBを超える場合は、ビルド時に `/sitemap-index.xml` と `/sitemaps/seo-pages-{n}.xml` に分割する。

### 10.2 robots
`robots.txt` は既存の除外を維持し、sitemap URLを本番ドメインの絶対URLで出す。

追加する除外:

```txt
Disallow: /preview
```

プレビューHTMLを生成する場合は公開コンテナに含めない。ローカル確認用の生成物には `noindex,nofollow` を付ける。

## 11. 内部リンク設計
- ヘッダーまたはフッターに `Learn` / `読みもの` 導線を追加する。
- トップページから `/learn` と主要カテゴリへリンクする。
- デザインページの材質カードから対応する `/learn/materials/{material_key}` へリンクする。
- 材質ガイドから購入導線 `/design` へリンクする。特定材質の直接選択URLを追加する場合は、別途URL仕様を定義する。
- 記事末尾に関連ページを3から5件表示する。
- ハブページは最新記事順ではなく、カテゴリ理解に必要な順序で固定表示する。
- ビルド時に内部リンクの存在チェックを行い、404になるリンクがあれば失敗させる。

## 12. コンテンツ編集フロー

### 12.1 編集方法
SEO情報ページは管理画面ではなく、Pull Requestで編集する。

1. `web/content/seo/pages/{page_id}` に `page.toml` と `body.{locale}.md` を追加する。
2. 画像が必要な場合は `web/static/seo` に追加する。
3. ローカルでSEO HTMLを生成する。
4. 生成後のHTMLをブラウザまたはテストで確認する。
5. PRレビューで本文、翻訳、URL、メタ、内部リンクを確認する。
6. mainへマージ後、Cloud BuildでHTMLを再生成してデプロイする。

### 12.2 バリデーション
ビルド時に次を検証する。

- `page_id` は小文字英数字と `_` のみ。
- `slug` は小文字英数字と `-` のみ。
- `section` と `kind` の組み合わせがURL設計に合うこと。
- `meta_title` / `meta_description` / `title` / `lead` / `body` は公開ロケールで必須。
- `body` が指すMarkdownファイルが存在すること。
- `body` にH1が含まれないこと。
- 見出し階層はH2から始め、H2を飛ばしてH3を出さないこと。
- 画像にはalt、幅、高さがあること。
- 画像ファイルが `web/static/seo` に存在すること。
- 公開URLが重複しないこと。
- 関連ページID、関連材質キー、内部リンクが解決できること。
- 公開済みslug変更時は `redirects.toml` に旧URLがあること。
- 未翻訳ロケールを `hreflang` とsitemapに含めないこと。

### 12.3 公開フロー
初期リリースでは `en` と `ja` が揃ったページだけ `status = "published"` にする。将来ロケールを増やす場合は、翻訳完了ロケールから順にHTML生成できるが、未翻訳ロケールは生成しない。

下書きは `status = "draft"` のままGit管理できる。ビルドは下書きページのHTMLを公開出力しない。

## 13. web実装方針

### 13.1 静的HTML配信
`web` は生成済みHTMLを返すだけにする。

追加する処理:
- `/learn`、`/learn/*`、`/{locale}/learn`、`/{locale}/learn/*` を生成済みHTMLへマップする。
- リクエストパスから `web/generated/seo/public/{path}/index.html` を探して返す。
- ファイルがなければ通常の404を返す。
- `?lang=ja` など旧形式は対応するパス形式へ301リダイレクトする。
- 末尾スラッシュ付きアクセスは末尾スラッシュなしへ301リダイレクトする。
- `web/generated/seo/redirects.json` に一致する旧URLは301を返す。

実行時にSEOページ本文のためFirestoreへアクセスしない。

### 13.2 静的ファイルの配置
コンテナ内では以下を配置する。

```text
/app/generated/seo/public
/app/generated/seo/redirects.json
```

`web/src/main.rs` では環境変数または固定パスで生成物ディレクトリを参照する。

```text
HANKO_WEB_SEO_STATIC_DIR=/app/generated/seo/public
HANKO_WEB_SEO_REDIRECTS_FILE=/app/generated/seo/redirects.json
```

ローカル開発では `web/generated/seo/public` を参照する。

### 13.3 キャッシュ
- SEO情報ページは `Cache-Control: public, max-age=300` 程度から始める。
- 画像やCSSは既存静的アセットのキャッシュ方針に合わせる。
- HTMLにハッシュを付けないため、長期キャッシュは避ける。

## 14. 品質チェック
公開前に以下を確認する。

- [ ] `cd web/tools/seo-pages && go run . ...` が成功する。
- [ ] 生成HTMLが `web/generated/seo/public` に出力される。
- [ ] ページが静的HTMLとして返る。
- [ ] SEOページ本文生成でFirestoreへアクセスしていない。
- [ ] `title` / `meta description` がロケールごとに自然な文になっている。
- [ ] canonicalがself-canonicalになっている。
- [ ] `hreflang` が自分自身と他言語版を双方向に含む。
- [ ] sitemapに公開ロケールURLが入り、未公開ロケールが入っていない。
- [ ] 構造化データがRich Results Testで重大エラーなし。
- [ ] 画像URLがクロール可能で、altが本文文脈に合っている。
- [ ] 内部リンクが孤立していない。
- [ ] ironframe のCSS生成対象にGoテンプレートが含まれている。
- [ ] 下書き・プレビューHTMLが公開出力に含まれていない。
- [ ] 購入導線へのCTAがある。
- [ ] ポーリング、SSE、WebSocketを使っていない。

## 15. 実装タスク
- [ ] `web/content/seo` のディレクトリと初期ページ原稿を追加する。
- [ ] `web/tools/seo-pages` にGoモジュールを追加する。
- [ ] `web/tools/seo-pages/templates/seo_page.gohtml` を追加する。
- [ ] `web/tools/seo-pages/main.go` を追加する。
- [ ] Markdownレンダリング、HTMLサニタイズ、メタ生成、JSON-LD生成をビルド処理に追加する。
- [ ] canonical / hreflang / OG / JSON-LD生成を共通化する。
- [ ] `/sitemap.xml` をビルド時に生成する。
- [ ] `web/content/seo/redirects.toml` と生成済みリダイレクト定義を追加する。
- [ ] `web` に生成済みHTML配信ハンドラと301リダイレクト処理を追加する。
- [ ] `web/Makefile` と `web/Dockerfile.cloudrun` にGo生成器によるSEO HTML生成ステップを追加する。
- [ ] ironframe のCSSスキャン対象に `web/tools/seo-pages/templates/**/*.gohtml` を追加する。
- [ ] `robots.txt` にプレビューURLの除外を追加する。
- [ ] 初期ページの `en` / `ja` 本文を登録する。
- [ ] Search Consoleでsitemap送信とURL検査を行う。

## 16. 参考
- Google Search Central: [Tell Google about localized versions of your page](https://developers.google.com/search/docs/specialty/international/localized-versions)
- Google Search Central: [How to specify a canonical URL with rel="canonical" and other methods](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)
- Google Search Central: [SEO Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)
- Google Search Central: [Build and submit a sitemap](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap)
- Google Search Central: [Structured data markup that Google Search supports](https://developers.google.com/search/docs/appearance/structured-data/search-gallery)
- Google Search Central: [Breadcrumb structured data](https://developers.google.com/search/docs/appearance/structured-data/breadcrumb)
- Google Search Central: [Article structured data](https://developers.google.com/search/docs/appearance/structured-data/article)
- Google Search Central: [General structured data guidelines](https://developers.google.com/search/docs/appearance/structured-data/sd-policies)
- Google Search Central: [FAQPage structured data](https://developers.google.com/search/docs/appearance/structured-data/faqpage)
- Google Search Central: [Product structured data](https://developers.google.com/search/docs/appearance/structured-data/product)
