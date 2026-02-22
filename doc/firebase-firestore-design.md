# Firebase Firestore 設計（本番向け・多言語対応）

## 1. 目的
このドキュメントは、Hanko Field の本番環境で利用する Firestore データモデルを定義します。  
対象は `app` / `web` / `admin` / `api` を横断する以下の領域です。

- 表示用マスタ管理（フォント、材質、配送国）
- 注文受付と注文ライフサイクル管理
- 決済連携（Stripe webhook を含む）
- 監査ログと冪等制御
- 多言語対応（初期対応: 日本語 `ja` / 英語 `en`）

## 2. 前提と設計方針
- DB は Cloud Firestore（Native mode）を利用する。
- クライアント（app / web / admin）は Firestore に直接書き込まない。すべて Cloud Run 上の Go API 経由とする。
- 金額（商品価格、送料、税、値引き、合計）は常にサーバー側で再計算し、リクエスト値を信頼しない。
- 注文確定時にマスタ情報を注文へスナップショット保存し、後日のマスタ変更で過去注文が変質しないようにする。
- 注文作成は冪等（idempotent）に実装し、再送による二重注文を防止する。
- 管理画面とユーザ向け画面はポーリング/ストリーミングなしを前提とし、都度の API リクエストで更新する。
- 多言語文字列は Firestore 上で `*_i18n`（`map<string,string>`）として管理する。
- ロケールは BCP 47 準拠の小文字（例: `ja`, `en`）を利用する。
- フォールバック順は `requested_locale` -> `default_locale` -> `ja` とする。
- 材質写真は Firebase Storage に保存し、Firestore には画像メタデータのみを保存する（バイナリは保存しない）。

## 3. コレクション一覧
- `app_config`: 公開設定（対応ロケール、既定ロケール）
- `fonts`: フォントマスタ
- `materials`: 材質マスタ
- `countries`: 配送国マスタ
- `orders`: 注文
- `orders/{order_id}/events`: 注文監査イベント
- `idempotency_keys`: 注文作成の冪等制御
- `order_no_counters`: 注文番号採番カウンタ
- `payment_webhook_events`: Stripe webhook の重複実行防止

## 4. スキーマ詳細

### 4.1 `app_config/public`
公開設定ドキュメント。固定 ID: `public`。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `supported_locales` | array<string> | Yes | サポート言語（例: `["ja", "en"]`） |
| `default_locale` | string | Yes | 既定ロケール（例: `ja`） |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.2 `fonts/{font_key}`
ドキュメント ID は `font_key`（例: `zen_maru_gothic`）。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `label_i18n` | map<string,string> | Yes | 表示名（例: `ja`, `en`） |
| `font_family` | string | Yes | CSS `font-family` 文字列 |
| `font_stylesheet_url` | string | Yes | Google Fonts の CSS URL（例: `https://fonts.googleapis.com/css2?family=ZCOOL+XiaoWei&display=swap`） |
| `is_active` | bool | Yes | 選択可能フラグ |
| `sort_order` | int | Yes | 表示順（昇順） |
| `version` | int | Yes | 業務用バージョン（更新ごとに +1） |
| `created_at` | timestamp | Yes | 作成日時 |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.3 `materials/{material_key}`
ドキュメント ID は `material_key`（例: `boxwood`）。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `label_i18n` | map<string,string> | Yes | 材質名（例: `ja`, `en`） |
| `description_i18n` | map<string,string> | Yes | 説明文（例: `ja`, `en`） |
| `shape` | string | Yes | `square` or `round` |
| `photos` | array<map> | Yes | 材質写真一覧（1件以上、`sort_order` 昇順で利用） |
| `photos[].asset_id` | string | Yes | 画像 ID（例: `mat_xxxxx`） |
| `photos[].storage_path` | string | Yes | Storage パス（例: `materials/boxwood/mat_xxxxx.webp`） |
| `photos[].alt_i18n` | map<string,string> | Yes | 画像代替テキスト（例: `ja`, `en`） |
| `photos[].sort_order` | int | Yes | 表示順（昇順） |
| `photos[].is_primary` | bool | Yes | 代表画像フラグ（1件のみ `true`） |
| `photos[].width` | int | No | 画像幅（px） |
| `photos[].height` | int | No | 画像高さ（px） |
| `price_jpy` | int | Yes | 税抜/税込を決めた単価（システム仕様に合わせて統一） |
| `is_active` | bool | Yes | 選択可能フラグ |
| `sort_order` | int | Yes | 表示順（昇順） |
| `version` | int | Yes | 業務用バージョン |
| `created_at` | timestamp | Yes | 作成日時 |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.4 `countries/{country_code}`
ドキュメント ID は ISO 国コード（例: `JP`, `US`）。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `label_i18n` | map<string,string> | Yes | 表示名（例: `ja`, `en`） |
| `shipping_fee_jpy` | int | Yes | 基本送料（円） |
| `is_active` | bool | Yes | 選択可能フラグ |
| `sort_order` | int | Yes | 表示順（昇順） |
| `version` | int | Yes | 業務用バージョン |
| `created_at` | timestamp | Yes | 作成日時 |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.5 `orders/{order_id}`
ドキュメント ID は Firestore Auto ID。  
`order_no` は別途採番した表示用注文番号（例: `HF-20260209-0001`）。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `order_no` | string | Yes | 表示用注文番号 |
| `channel` | string | Yes | `app` / `web` |
| `locale` | string | Yes | 注文時 UI ロケール（`ja` / `en`） |
| `status` | string | Yes | 注文状態（後述の遷移定義） |
| `status_updated_at` | timestamp | Yes | ステータス更新日時 |
| `seal.line1` | string | Yes | 印影 1 行目（1-2 文字、空白不可） |
| `seal.line2` | string | No | 印影 2 行目（0-2 文字、空白不可） |
| `seal.shape` | string | Yes | `square` or `round` |
| `seal.font_key` | string | Yes | 選択フォントキー |
| `seal.font_label_i18n` | map<string,string> | Yes | 注文時点フォント名スナップショット |
| `seal.font_version` | int | Yes | 注文時点フォントバージョン |
| `material.key` | string | Yes | 選択材質キー |
| `material.label_i18n` | map<string,string> | Yes | 注文時点材質名スナップショット |
| `material.shape` | string | Yes | 注文時点の材質形状（`square` or `round`） |
| `material.unit_price_jpy` | int | Yes | 注文時点の単価 |
| `material.version` | int | Yes | 注文時点の材質バージョン |
| `shipping.country_code` | string | Yes | 配送先国コード |
| `shipping.country_label_i18n` | map<string,string> | Yes | 注文時点国名スナップショット |
| `shipping.country_version` | int | Yes | 注文時点の国マスタバージョン |
| `shipping.fee_jpy` | int | Yes | 注文時点の送料 |
| `shipping.recipient_name` | string | Yes | 届け先氏名 |
| `shipping.phone` | string | Yes | 電話番号 |
| `shipping.postal_code` | string | Yes | 郵便番号 |
| `shipping.state` | string | Yes | 都道府県/州 |
| `shipping.city` | string | Yes | 市区町村/City |
| `shipping.address_line1` | string | Yes | 住所 1 |
| `shipping.address_line2` | string | No | 住所 2 |
| `contact.email` | string | Yes | 連絡先メール |
| `contact.preferred_locale` | string | Yes | 連絡言語（`ja` / `en`） |
| `pricing.subtotal_jpy` | int | Yes | 商品小計 |
| `pricing.shipping_jpy` | int | Yes | 送料 |
| `pricing.tax_jpy` | int | Yes | 税額 |
| `pricing.discount_jpy` | int | Yes | 値引き |
| `pricing.total_jpy` | int | Yes | 請求合計 |
| `pricing.currency` | string | Yes | `JPY` 固定 |
| `payment.provider` | string | Yes | `stripe` |
| `payment.checkout_session_id` | string | No | Checkout Session ID（作成後に更新） |
| `payment.intent_id` | string | No | PaymentIntent ID（作成後に更新） |
| `payment.status` | string | Yes | `unpaid` / `processing` / `paid` / `failed` / `refunded` |
| `payment.last_event_id` | string | No | 最終反映 webhook イベント ID |
| `fulfillment.status` | string | Yes | `pending` / `manufacturing` / `shipped` / `delivered` |
| `fulfillment.tracking_no` | string | No | 追跡番号 |
| `fulfillment.carrier` | string | No | 配送業者 |
| `fulfillment.shipped_at` | timestamp | No | 出荷日時 |
| `fulfillment.delivered_at` | timestamp | No | 配達完了日時 |
| `idempotency_key` | string | Yes | 注文作成時の冪等キー |
| `terms_agreed` | bool | Yes | 利用規約同意 |
| `created_at` | timestamp | Yes | 作成日時 |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.6 `orders/{order_id}/events/{event_id}`
注文の状態変更・重要操作の監査ログ。`event_id` は Auto ID。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `type` | string | Yes | `order_created`, `payment_paid`, `status_changed`, `shipment_registered` など |
| `actor_type` | string | Yes | `system` / `admin` / `webhook` |
| `actor_id` | string | No | 管理者 UID や webhook 名 |
| `before_status` | string | No | 変更前ステータス |
| `after_status` | string | No | 変更後ステータス |
| `payload` | map | No | 変更内容の最小限スナップショット |
| `created_at` | timestamp | Yes | 作成日時 |

### 4.7 `idempotency_keys/{channel}:{idempotency_key}`
注文作成の二重実行防止。例: `web:3f7b...`

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `channel` | string | Yes | `app` / `web` |
| `idempotency_key` | string | Yes | クライアント生成キー |
| `request_hash` | string | Yes | 正規化済み注文入力のハッシュ |
| `order_id` | string | Yes | 紐づく `orders` ドキュメント ID |
| `created_at` | timestamp | Yes | 作成日時 |
| `expire_at` | timestamp | Yes | TTL 期限（例: 30 日） |

### 4.8 `order_no_counters/{yyyyMM}`
注文番号採番カウンタ。例: `202602`。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `last_seq` | int | Yes | 当月最終採番値 |
| `updated_at` | timestamp | Yes | 更新日時 |

### 4.9 `payment_webhook_events/{provider_event_id}`
Stripe webhook の重複処理防止。`provider_event_id` は Stripe event ID。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `provider` | string | Yes | `stripe` |
| `event_type` | string | Yes | `payment_intent.succeeded` など |
| `order_id` | string | No | 対象注文 |
| `processed` | bool | Yes | 反映完了フラグ |
| `created_at` | timestamp | Yes | 受信日時 |
| `expire_at` | timestamp | Yes | TTL 期限（例: 90 日） |

## 5. 多言語仕様
- マスタの翻訳は `*_i18n` に保存する。
- `*_i18n` は少なくとも `ja` と `en` を必須にする（初期要件）。
- 追加言語は `app_config/public.supported_locales` に追加し、各マスタへ同ロケールの翻訳を投入する。
- API は `locale` を受け取り、レスポンスに `label`（解決済み）を返す。
- 管理画面 API は編集用途のため `*_i18n` をそのまま返す。
- `materials.photos[].alt_i18n` も同じフォールバック規則で解決する。
- 注文時は `orders.locale` と `contact.preferred_locale` を保持し、メール/領収書/管理画面表示言語に利用する。
- 受注後のマスタ翻訳更新の影響を避けるため、注文には `*_label_i18n` をスナップショット保存する。

## 6. 注文ステータス遷移
`orders.status` は以下を許可し、遷移時に必ず `orders/{order_id}/events` を 1 件追加する。

| 現在 | 次 | トリガー |
| --- | --- | --- |
| `pending_payment` | `paid` | Stripe webhook 成功 |
| `pending_payment` | `canceled` | 支払い期限切れ/利用者キャンセル |
| `paid` | `manufacturing` | 管理画面で製造開始 |
| `manufacturing` | `shipped` | 管理画面で出荷登録 |
| `shipped` | `delivered` | 配送完了登録 |
| `paid` / `manufacturing` / `shipped` | `refunded` | 返金処理完了 |

注文作成時は `status = pending_payment`、`payment.status = unpaid`、`fulfillment.status = pending` で開始する。

## 7. API アクセスパターン（本番）

### `GET /v1/catalog?locale=ja|en`
- `fonts`, `materials`, `countries` から `is_active == true` を `sort_order asc` で取得。
- `locale` を元に `*_i18n` から表示文字列を解決して返す。
- `materials.photos[].storage_path` から配信用 `asset_url` を生成して返す（Firestore には期限付き URL を保存しない）。

### `GET /v1/config/public`
- `app_config/public` の `supported_locales`, `default_locale` を返す。

### `POST /v1/orders`
- 入力検証後、マスタ参照と価格再計算を実施。
- `locale` と `contact.preferred_locale` が `supported_locales` 内か検証する。
- Firestore トランザクションで以下を同時実行。
- `idempotency_keys` を確認し、既存なら既存 `order_id` を返す。
- 新規時は `order_no_counters` を更新して `order_no` を採番。
- `orders` 作成と `orders/{order_id}/events`（`order_created`）作成。

### `POST /v1/payments/stripe/checkout-session`
- `order_id` を受け取り、`orders.status == pending_payment` かつ `orders.payment.status == unpaid` を検証する。
- Stripe Checkout Session を作成し、`metadata.order_id` を設定する。
- `orders.payment.checkout_session_id` を更新する。

### `POST /v1/payments/stripe/webhook`
- `payment_webhook_events` を先に記録し、未処理イベントのみ反映。
- `orders.payment.*` と `orders.status` を更新。
- 更新内容を `orders/{order_id}/events` に追記。

### `GET /admin/orders`
- `status`, `created_at`, `shipping.country_code`, `contact.email` で絞り込み。
- 画面はページング方式を採用し、リアルタイム購読は利用しない。

### `PATCH /admin/orders/{order_id}`
- 出荷情報登録・ステータス変更をトランザクションで更新。
- `updated_at` と `status_updated_at` を必ず更新。
- 監査イベントを追加。

### `PATCH /admin/materials/{material_key}`
- 材質名・説明・形状・価格に加え、`photos`（追加/削除/並び替え/代表画像変更）を更新する。
- 画像アップロードは API が発行するアップロード手段経由で Firebase Storage に保存し、保存後に `photos[].storage_path` を登録する。

## 8. 必要インデックス

### マスタ
- `fonts`: `is_active ASC`, `sort_order ASC`
- `materials`: `is_active ASC`, `sort_order ASC`
- `countries`: `is_active ASC`, `sort_order ASC`

### 注文一覧・検索（admin）
- `orders`: `status ASC`, `created_at DESC`
- `orders`: `payment.status ASC`, `created_at DESC`
- `orders`: `fulfillment.status ASC`, `created_at DESC`
- `orders`: `shipping.country_code ASC`, `created_at DESC`
- `orders`: `contact.email ASC`, `created_at DESC`
- `orders`: `channel ASC`, `created_at DESC`
- `orders`: `locale ASC`, `created_at DESC`

### TTL 対象フィールド
- `idempotency_keys.expire_at`
- `payment_webhook_events.expire_at`

## 9. セキュリティ方針
- Firestore Security Rules は `deny by default` とし、クライアント SDK からの直接読み書きを許可しない。
- API/Admin の Cloud Run サービスアカウントに IAM で必要最小権限を付与する。
- 管理機能は Firebase Auth の管理者クレームを API 側で検証する。
- PII（住所、電話番号、メール）はログへ平文出力しない。監査イベントにも最小限のみ保存する。
- API 側で `locale` を `supported_locales` と照合し、不正ロケール入力を拒否する。
- Storage への材質写真アップロード/削除は管理 API 経由のみ許可し、クライアント直接書き込みを禁止する。

## 10. 運用方針
- バックアップ: Firestore Export を日次実行し、世代管理する。
- リリース: 新フィールドは後方互換で追加し、既存必須フィールド変更は段階移行で行う。
- 監視: 注文作成失敗率、webhook 再試行率、トランザクション失敗率を監視対象にする。
- 翻訳運用: `*_i18n` に欠損がある場合は `default_locale` へフォールバックし、欠損メトリクスを記録する。
- 画像運用: 原本と表示用サイズ（サムネイル等）を Storage に保持し、`photos[].storage_path` は表示用途ごとに管理する。

## 11. 移行手順（モック設計から）
1. `fonts` / `materials` / `countries` の `label` 系を `*_i18n` へ移行する（`ja` 値は既存文字列を移植）。`materials` は `photos` フィールドを追加する。
2. `app_config/public` を作成し、`supported_locales=["ja","en"]`, `default_locale="ja"` を投入する。
3. `orders` を本番スキーマ（`locale`, `*_label_i18n`, `payment.*`, `fulfillment.*`, `idempotency_key` など）へ切り替える。
4. `idempotency_keys`, `order_no_counters`, `payment_webhook_events` を新規作成する。
5. 複合インデックスと TTL を作成する。
6. `/mock/*` 前提の API を `/v1/*` 前提へ置換する。

## タスク
- [x] Firestore データベース設計書を本番向けへ更新
- [x] 多言語（日本語/英語）対応要件を Firestore 設計へ反映
- [x] `materials` で写真を管理できるスキーマへ更新
- [x] `materials` に材質形状（`square` / `round`）を追加
- [x] `web` で `mock` / `dev` / `prod` を切り替え、Firestore 実データ参照を可能にする
- [x] `admin` で `mock` / `dev` / `prod` を切り替え、Firestore 実データ参照を可能にする
- [x] `api` に Stripe Checkout Session 作成エンドポイントを追加
