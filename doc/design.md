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
