# ハンコフィールド

ハンコフィールドは、アプリでユーザが自分の印鑑をデザインし、注文できるサービスです。

- アプリフレームワーク: Flutter
- ウェブ: Cloud Run (Rust)
- 管理画面: Cloud Run (Rust)
- データベース: Firestore
- API: Cloud Run (Rust)
- ストレージ: Firebase Storage
- 認証: Firebase Auth
- 支払い: Stripe
- 管理画面/ウェブ: ポーリングやストリーミング（SSE / WebSocket 等）を実装しない
- 対応言語: 日本語（`ja`）/ 英語（`en`）を初期対応し、追加可能な多言語設計にする

## 関連ドキュメント
- Firebase Firestore 設計（本番向け・多言語対応）: `doc/firebase-firestore-design.md`

## 印影生成方針

- アプリの印影スタイル選択画面で、形、雰囲気、線の太さ、バランスのカスタマイズを完了させる。
- AIは最終印影画像を直接生成せず、許可されたスタイルレシピを3件提案する役割に限定する。
- 最終印影PNGは、API側のプログラムレンダラが実在フォントの漢字グリフを使って生成する。
- 生成印影は常に赤文字、赤枠1本、白背景、固定外枠サイズ、中央配置にする。
- 候補表示画面以降は、生成済み3候補から選択するだけにし、追加カスタマイズUIを出さない。

## 印影生成MVP運用（M15時点）

- 承認済みフォントプロファイルは `formal_serif`（Noto Serif JP）、`soft_sans`（Noto Sans JP）、`bold_brush`（Yuji Syuku）、`classic_seal`（Kaisei Tokumin Bold）の4件に固定する。
- フォントassetは `api/assets/fonts/` 配下に同梱し、licenseはすべて SIL Open Font License 1.1 とする。profile、license、checksum、coverageの正本は `api/assets/fonts/README.md`、`api/assets/fonts/profiles.json`、`api/src/seal_fonts.rs` に揃える。
- 描画時は要求profile、`formal_serif`、`soft_sans` の順にグリフ対応を確認する。どの承認済みフォントでも描画できない文字は `seal_generation_failed` とし、AI画像や未検証字形へ切り替えない。
- MVPで扱う印影文字は1から2文字のCJK Han文字のみ。3文字以上、空白、非漢字、細線、複雑背景、2本枠、白以外の背景は扱わない。
- M15時点のPNGレンダラは `font_profile`、`spacing`、`frame` を画へ反映し、`impression`、`weight`、`texture` は保存、表示、admin確認用のrecipeメタデータとして保持する。
- 生成導線に問題が出た場合は、アプリの生成CTAをメンテナンス表示にするhotfix、またはAPIの直前Cloud Run revisionへのrollbackで止める。既存Web注文と保存済みStorage印影の表示は維持する。

## タスク
- [x] 管理画面（`admin`）の初期モック実装を追加
- [x] 管理画面（`admin`）で `mock` / `dev` / `prod` のデータソース切替を追加
- [x] `api` / `admin` / `web` の実装言語を Rust に統一
- [x] 管理画面（`admin`）を注文管理・材質マスタ・材質マスタ編集のページに分割
- [x] 管理画面（`admin`）に材質マスタ作成ページを追加
- [x] 管理画面（`admin`）の材質マスタ一覧に削除導線と確認ダイアログを追加
- [x] 管理画面（`admin`）で材質写真（Storage パス）を登録・編集できるようにする
- [x] 管理画面（`admin`）で画像ファイルをアップロードし、材質写真の Storage パスを自動入力できるようにする
- [x] 管理画面（`admin`）の材質画像アップロードで即時プレビューとエラーフィードバックを表示する
- [x] 管理画面（`admin`）の材質マスタ登録項目を材質キー・材質名・説明・公開状態に絞る
- [x] 材質マスタに木材・青田石・寿山石・巴林石・伊犁石・ラオス石・西峡石・凍石を登録する
- [x] 管理画面（`admin`）にフォントマスタ編集ページを追加
- [x] 管理画面（`admin`）で配送国マスタの送料を国ごとに編集できるようにする
- [x] 管理画面（`admin`）で配送国マスタを追加・削除できるようにする
- [x] 材質マスタに印面形状（角印/丸印）を保持できるようにする
- [x] `web` の候補生成を `api` の Gemini エンドポイント経由に切り替え、候補ごとに漢字・読み方（`reading`）・言語指定理由を返す
- [x] `web` の候補生成で理由言語指定UIを廃止し画面ロケールを利用、性別（選択なし/男性/女性）指定を Gemini プロンプトに反映
- [x] `api` に Stripe Checkout Session 作成エンドポイントを追加
- [x] `web` の購入フローを Stripe Checkout に接続
- [x] `web` に支払い成功画面と支払い失敗画面を追加
- [x] Stripe Checkout の商品名をロケール別に変更（日本語: `宝石印鑑 (材質、丸/角)` / 英語: `Stone seal (material; circle/square)`）、住所・電話番号を渡す
- [x] Stripe / Web の金額表示を `pricing.currency` に基づく通貨別表示へ対応
- [x] 材質・送料マスタ金額を `price_by_currency` / `shipping_fee_by_currency`（`map<string,int>`）で管理
- [x] 将来のロケール別通貨切り替えを見据え、`app_config/public` に通貨ポリシー（`default_currency` / `currency_by_locale`）を追加
- [x] `ja` ロケールの決済通貨を `JPY` に設定（`en` は `USD`）
- [x] 管理画面（材質/配送国マスタ）で USD に加えて JPY 金額も編集できるようにする
- [x] `orders.pricing` の金額フィールドを通貨非依存名（`subtotal` / `shipping` / `tax` / `discount` / `total`）へ変更
- [x] 互換用の旧金額フィールド（`price_usd` / `price_jpy` / `shipping_fee_usd` / `shipping_fee_jpy` / `total_usd`）の読み書きを削除
- [x] `api` の Stripe Checkout 連携を `crates.io/stripe-sdk` ベースへ移行
- [x] `api` の Stripe Webhook 検証/パースを `stripe-sdk v0.3.0` の `webhook` ヘルパーへ移行
- [x] フォントマスタのフォント名を言語別（`ja` / `en`）ではなく単一 `label` で管理する
- [x] 漢字名提案の読み方表示をスタイル別に変更し、日本スタイルはローマ字、中国/台湾スタイルは声調なし拼音で表示する
- [x] 漢字名提案レスポンスの読み方キーを `reading` に統一し、ひらがな項目を廃止する
- [x] `app` に `web` と同等の注文フロー画面（デザイン/材質/購入）と支払い成功・失敗画面を追加
- [x] `app` を `api`（`/v1/config/public`, `/v1/catalog`, `/v1/kanji-candidates`, `/v1/orders`, `/v1/payments/stripe/checkout-session`）に接続し、実データを利用する
- [x] `web` / `app` のロケール切替で入力途中の注文内容を保持し、再読込で消えないようにする
- [x] `web` / `app` の入力例・案内文をロケール別に整え、英語ユーザにも自然に伝わるようにする
- [x] `app` の購入ステップで、配送国選択メニューをフォントスタイルと同じ見た目のボトムシートにする
- [x] `web` の公開ページで canonical / hreflang を絶対URL + `x-default` 付きで整え、英語 URL を正規、`/ja/` を日本語代替として公開する
- [x] `web` の主要 SEO メタ（title / meta description / robots / OG / Twitter）をロケール別に整え、英語 URL で英語表示にする
- [x] `web` / `app` のデザインステップで、印影テキスト・フォント・形状の選択状態とエラー表示をより明確にする
- [x] 材質マスタの比較情報を拡充し、質感・重さ・用途が判断しやすい説明を表示する
- [x] `web` の公開画面で `facet_tags` 由来の色・模様ラベルを材質カードに表示する
- [x] `web` の公開画面で色・模様・石の形で材質を絞り込めるようにする
- [x] 管理画面（`admin`）の一点物登録項目にサイズを追加する
- [x] 形状変更による材質の自動切替をユーザに明示する
- [x] 漢字名提案 UI を任意導線として整理し、購入の主導線を邪魔しない配置にする
- [x] `web` / `app` の購入ステップで、送信中状態・入力不足・同意未完了を分かりやすく表示する
- [x] `web` / `app` の購入完了・失敗画面に、次のアクション、注文 ID、問い合わせ導線を追加する
- [x] `web` / `app` のモバイル表示で、ステップ表示・材質一覧・フォント一覧の視認性を改善する
- [x] `app` の確認用導線を `mock` / `dev` のみに限定し、本番ユーザには表示しない
- [x] `web` の結果更新領域に `aria-live` を付け、購入結果や候補更新が読み上げられるようにする
- [x] Firebase の dev / prod プロジェクトを `hanko-field` / `hanko-field-prod` に分け、Firestore は `(default)` を使う
- [x] `app` の Google Play Store 掲載準備として Android の release signing / app icon / app name を整備する
- [x] 管理画面（`admin`）の最大表示幅を広げる
- [x] 管理画面（`admin`）と Web を本番環境へデプロイする
- [x] `web` に STONE SIGNATURE のブログセクションと `/blog/{slug}` の記事ページを追加する
- [x] `web` の公開 URL を英語は言語コードなし、その他言語は `/{languageCode}/` 始まりに統一する
- [x] `web` のジャーナルに「What Is a Hanko? A Complete Guide to Japanese Personal Seals」を追加する
- [x] `web` のジャーナル記事メタデータを JSON から HTML front matter へ移管し、記事SEOメタを最適化する
- [x] `web` のジャーナルに「Hanko vs Inkan: What's the Difference?」を追加する
- [x] `web` のジャーナルに「What Is a Personal Seal? History, Meaning, and Modern Uses」を追加する
- [x] `web` のジャーナルから初期サンプル記事3本を削除する
- [x] `web` のジャーナルに「Why a Custom Stone Seal Makes a Meaningful Gift」と日本語記事を追加する
- [x] `web` のジャーナルに「Custom Jade Seal: Meaning, Materials, and How to Choose One」と日本語記事を追加する
- [x] `web` のジャーナルに「Japanese Hanko as a Souvenir: A Personal Piece of Japan」と日本語記事を追加する
- [x] `web` のジャーナルに「How to Choose the Right Stone for Your Personal Seal」と日本語記事を追加する
- [x] `web` のジャーナルに「Jade, Agate, or Qingtian Stone: Which Seal Material Is Best?」と日本語記事を追加する
- [x] `web` のジャーナルに「A Personal Seal as a Symbol of Identity」と日本語記事を追加する
- [x] `web` のジャーナルに「Luxury Personal Seals: A New Way to Express Your Signature」と日本語記事を追加する
- [x] `web` に追加した7本のジャーナル記事の sitemap 出力とSEOタグを検証・調整する
- [x] `web` のジャーナルに「How to Turn Your English Name into a Japanese or Chinese Seal」と日本語記事を追加する
- [x] `web` のジャーナルに「What to Engrave on a Custom Personal Seal」と日本語記事を追加する
- [x] `web` のジャーナルに「Personal Seals for Artists, Writers, and Creators」と日本語記事を追加する
- [x] `web` のジャーナルに「Chinese Chop Seal vs Japanese Hanko: Similarities and Differences」と日本語記事を追加する
- [x] `web` のジャーナルに「The Beauty of One-of-a-Kind Stone Seals」と日本語記事を追加する
- [x] app注文で生成印影画像、AI Variant ID、選択スタイル詳細、顧客確認チェック記録を保存・admin確認できるデータ設計を追加する
- [x] Stone SignatureアプリMVPの画面一覧を画面コード付き構成へ置き換える
- [x] `doc/screens` のPNGファイル名を画面コード形式へ変更する
- [x] 新しいアプリ画面設計と既存Webサイトを比較し、マイルストーン付き実装タスク一覧を追加する
- [x] 印影生成方針をAIレシピ提案 + 実在フォントのプログラム描画へ更新する
