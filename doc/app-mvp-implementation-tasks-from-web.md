# Stone Signature App MVP 実装タスク一覧

## 1. 目的

この文書は、新しいアプリ画面設計 `doc/app-mvp-screen-design.md` と既存Webサイト `web` の実装を比較し、Stone Signature App MVP を実装できる粒度までタスク化する実装契約である。

実装者はこの文書を起点に、画面、API、Firestore、Storage、admin確認、Stripe Checkout、テストまでを進める。Webの既存実装は参考・互換対象であり、アプリの体験をWebに寄せることは目的ではない。

## 2. ゴールと非ゴール

### ゴール

- Flutterアプリで `Design` / `My Seals` / `Stones` の3タブを持つMVPを実装する。
- ユーザーが名前から漢字候補を選び、固定UIで印影スタイルを選び、AI印影候補を3件生成して選べるようにする。
- 選択した印影を端末内ローカル保存し、後で確認・削除・注文用選択ができるようにする。
- 販売中の一点物宝石材を一覧/詳細で確認し、選択した印影と組み合わせて注文できるようにする。
- Stripe Checkoutで決済し、決済確定はStripe Webhook反映後のサーバー状態を正とする。
- ログインなしで注文番号とメールアドレスから注文状態を確認できるようにする。
- app注文では、AI印影画像URL相当、AI Variant ID、選択スタイル詳細、顧客確認チェック記録を `orders` に保存し、既存adminで確認できるようにする。

### 非ゴール

- Gen UIは使わない。
- アプリMVPにログイン、Firebase Auth、クラウド同期、ユーザーアカウントを追加しない。
- 保存済み印影を端末間同期しない。
- 3文字以上の印影、細線デザイン、複雑な装飾印影は扱わない。
- 運営側とのデザイン確認・修正ワークフローは作らない。
- 新しい別adminを作らない。
- Web/adminにポーリング、SSE、WebSocketなどのストリーミング更新を追加しない。
- 既存Webの1ページ購入フォームをそのままアプリに移植しない。

## 3. リポジトリ制約

| 領域 | 制約 |
| --- | --- |
| app | Flutter、MVVM + feature-first、`miniriverpod`、`declarative_nav` を使う。`go_router` など他のナビゲーションライブラリは使わない |
| api | Rust、Cloud Run、Firestore、Firebase Storage、Stripe |
| admin | Rust、htmx、ironframe、Askama。ポーリング/ストリーミング禁止 |
| web | Rust、htmx、ironframe、Askama。Firebase連携は `firebase-sdk-rust`。ポーリング/ストリーミング禁止 |
| docs | 画面コードは `doc/app-mvp-screen-design.md` を正とする |
| data | 既存Firestoreコレクション構成は維持し、必要なフィールドだけ追加する |

### 3.1 Web/admin更新方式ポリシー

Webとadminの画面更新は、ユーザー操作に応じた通常のHTTPリクエスト、フォーム送信、htmxリクエストで行う。以下はWeb/adminでは実装しない。

- `setInterval` / timer / `hx-trigger="every ..."` などによる定期ポーリング。
- SSE / `EventSource` / Server-Sent Events。
- WebSocket。
- 長時間接続やstreaming responseを使う画面更新。

許可するもの:

- ユーザーがクリック、入力、送信、戻る、再読み込みをした時の単発HTTPリクエスト。
- htmxの明示的なユーザーイベントによる部分更新。
- アプリのStripe戻り直後に限る短時間の注文状態再取得。これはFlutterアプリの前景画面だけで扱い、Web/adminには展開しない。

マイルストーン実装時は、Web/admin関連TaskにSSE、WebSocket、streaming、定期ポーリングを追加しない。必要な最新状態確認は、ユーザー操作による再読み込み、詳細画面再表示、または通常のPOST/GET完了後のHTML再描画で解決する。

## 4. 現状実装の棚卸し

### 4.1 既存Web

関連ファイル:

- `web/src/main.rs`
- `web/templates/top.html`
- `web/templates/index.html`
- `web/templates/kanji_suggestions.html`
- `web/templates/purchase_result.html`
- `web/templates/payment_success.html`
- `web/templates/payment_failure.html`
- `web/static/app.js`

既存Webの主なルート:

| ルート | 現状 |
| --- | --- |
| `GET /` / `GET /{locale}` | マーケティングトップ、Journal導線 |
| `GET /design` / `GET /{locale}/design` | 1ページ内の `Design -> Listing -> Purchase` ステップ式フォーム |
| `POST /kanji` | htmx向け漢字候補生成結果HTMLを返す |
| `POST /purchase` | 注文作成後、Stripe Checkout URLへ遷移 |
| `GET /payment/success` | 支払い成功表示。Webhook反映確認はしない |
| `GET /payment/failure` | 支払い未完了/失敗表示。キャンセルと失敗は同一表示 |
| `GET /about` | Aboutページ |
| `GET /terms` | 利用規約 |
| `GET /blog` / `GET /blog/{slug}` | Journal |

既存Webで流用できる実装:

- `web/static/app.js` の2文字制限、形状選択、出品個体フィルタ、価格/送料サマリー、入力不足表示、送信中状態。
- `web/templates/index.html` の購入フォーム項目、注文サマリー、Stripe Checkout前の送信導線。
- `web/templates/payment_success.html` と `web/templates/payment_failure.html` の注文後コピー、問い合わせ導線。
- `web/src/main.rs` のロケール解決、通貨表示、カタログ読み込み、Stripe Checkout Session作成呼び出し。

既存Webとの差分:

- Webは購入主導の1ページフォームで、アプリは作成・保存・比較を中心にする。
- Webはフォント描画プレビューで、AI印影画像生成はない。
- Webに `My Seals`、端末内保存、注文照会、石詳細画面、画像ギャラリーはない。
- Web成功画面はWebhook反映を待たない。アプリはサーバー注文状態を確認する。

#### 4.1.1 Web機能分類サマリー

既存Web機能は、アプリMVPへそのまま移植せず、以下の4分類で扱う。この表を比較サマリーの正本とし、以降のマイルストーンで実装範囲が変わる場合は分類も更新する。

| 分類 | Web機能 / 参照元 | アプリMVPでの扱い | 関連タスク |
| --- | --- | --- | --- |
| 流用 | ロケール解決、通貨選択、金額表示: `web/src/main.rs` | API/DTO境界と表示ロジックの参考にする。価格・送料・通貨はWeb同様にサーバー由来を正とし、アプリ表示値は注文確定に使わない | M02-T03, M07-T01, M09-T01 |
| 流用 | カタログ読み込み、素材/配送国/価格データ取得: `web/src/main.rs`, `web/templates/index.html` | Stones一覧、Checkout入力、注文確認で同じカタログ/API契約を使う。アプリ用には一点物一覧/詳細表示へ分割する | M07-T01, M07-T02, M09-T01 |
| 流用 | 2文字制限、形状選択、入力不足表示、送信中状態: `web/static/app.js` | Validationと状態表示の挙動を参考にし、Flutter ViewModelと画面状態へ置き換える | M04-T01, M04-T02, M05-T01, M09-T02 |
| 流用 | Stripe Checkout Session作成呼び出し、購入前の注文作成: `web/src/main.rs`, `web/templates/index.html` | API経由で注文作成後にCheckout Sessionを作る流れは維持する。app注文用のAI印影/顧客確認フィールドを追加する | M09-T04, M09-T07, M09-T08 |
| 流用 | 支払い成功/失敗時のコピー、問い合わせ導線: `web/templates/payment_success.html`, `web/templates/payment_failure.html` | アプリの完了/失敗/メール案内/問い合わせ導線の文言材料として使う | M09-T10, M09-T11, M12-T01, M12-T03 |
| 変更 | `GET /design` の1ページ `Design -> Listing -> Purchase` フォーム | アプリでは `Design` / `My Seals` / `Stones` / `Checkout` の複数スタックに分割し、購入前の保存・比較を主導線にする | M02-T01, M04, M05, M06, M07, M08, M09 |
| 変更 | `POST /kanji` のhtmx HTML返却 | アプリは既存API `POST /v1/kanji-candidates` のJSONを直接呼び、domain modelへ変換して表示する | M04-T03, M04-T04 |
| 変更 | Webのフォント描画プレビュー | アプリMVPではAI印影画像候補を3件生成して選ぶ。フォントキーは互換フィールドとして残す | M05-T02, M05-T05, M09-T06 |
| 変更 | Webの材質選択カードとフィルタ | アプリでは一点物宝石材の一覧/詳細/売り切れ状態/画像ギャラリーとして再構成する | M07-T01, M07-T03, M07-T05, M07-T06, M07-T07 |
| 変更 | Web成功画面はStripe戻りURLだけで成功表示 | アプリは戻り後に注文状態APIを確認し、Webhook未反映ならPendingを表示する | M09-T09, M10-T01 |
| 変更 | Webのキャンセル/失敗共通表示 | アプリではキャンセル、決済失敗、未反映Pendingを分ける | M09-T09, M09-T10 |
| 新規 | AI印影生成APIとStorage保存 | Webにはないため、`POST /v1/seal-designs/generate` とStorage保存を新規実装する | M05-T02, M05-T03 |
| 新規 | 端末内の保存済み印影 `My Seals` | Webにはないため、ローカルDB/画像保存、一覧、詳細、削除、注文用選択を新規実装する | M06-T01, M06-T03, M06-T04, M06-T05 |
| 新規 | 印影 + 宝石材の組み合わせ確認 | Webの1ページ確認から分離し、選択不足状態と変更導線を新規画面として実装する | M08-T01, M08-T02, M08-T03, M08-T04 |
| 新規 | 注文状態取得、注文照会 | Webにはないため、`GET /v1/orders/{order_id}/status` と `POST /v1/orders/lookup`、Order Lookup画面を新規実装する | M10-T01, M10-T02, M10-T03, M10-T05 |
| 新規 | adminでのAI印影画像、AI Variant ID、スタイル、顧客確認表示 | Web注文の既存admin表示に追加し、app注文の制作確認に使えるようにする | M11-T01, M11-T02, M11-T03, M11-T04, M11-T05 |
| 廃止 | Webの1ページ購入フォームをアプリへそのまま移植すること | アプリ体験と矛盾するため廃止。Webは互換維持のみで、アプリは画面コードベースで再設計する | M02-T02, M04-M09 |
| 廃止 | Web専用のhtmx部分更新HTMLをアプリUIへ持ち込むこと | FlutterではJSON/API + ViewModel + Widget状態で表現し、htmxテンプレートは移植しない | M02-T03, M04-T03 |
| 廃止 | WebのJournal/マーケティングトップをアプリMVPの主導線にすること | App Store向けの制作・保存体験を優先し、ブログ/SEO導線はWebに残す | M03, M12 |
| 廃止 | Web成功画面と同じ「Webhook確認なし」の確定扱い | 決済確定はサーバー注文状態を正とするため、アプリでは採用しない | M09-T09, M10-T01 |

### 4.2 既存API

関連ファイル:

- `api/src/main.rs`
- `api/src/bin/seed_catalog.rs`
- `doc/firebase-firestore-design.md`

既存APIで確認済みの主なエンドポイント:

| API | 現状 |
| --- | --- |
| `GET /v1/config/public` | 公開設定、ロケール、通貨ポリシー |
| `GET /v1/catalog` | フォント、素材、配送国、公開カタログ |
| `GET /v1/stone-listings` | Firestore設計上存在。アプリでは一覧/詳細用途で利用する |
| `POST /v1/kanji-candidates` | 名前から漢字候補生成 |
| `POST /v1/orders` | 注文作成、価格再計算、在庫予約。現状の `seal` 入力は `line1` / `line2` / `shape` / `font_key` 中心 |
| `POST /v1/payments/stripe/checkout-session` | Stripe Checkout Session作成 |
| `POST /v1/payments/stripe/webhook` | Stripe Webhook反映 |

API側の重要な現状制約:

- `CreateOrderRequest` は `serde(deny_unknown_fields)` のため、app注文用の新フィールドを送る前に構造体拡張が必要。
- API JSONは既存Rust実装に合わせて原則 `snake_case` とする。Dart domain modelはDart慣習に合わせて `camelCase` でよいが、DTOで明示的に変換する。
- 既存Web注文はAI印影情報を持たないため、`channel = web` では旧形式を許容する必要がある。
- app注文では `seal.ai_variant_id`、`seal.preview_image.storage_path`、`seal.style.*`、`customer_confirmation.*` を必須として検証する。
- 価格、送料、在庫状態、決済金額はアプリ表示値を信用せず、APIで必ず再計算する。

### 4.3 既存admin

関連ファイル:

- `admin/src/main.rs`
- `admin/templates/orders_list.html`
- `admin/templates/order_detail.html`
- `admin/templates/orders_page.html`

既存adminの現状:

- Orders一覧は `Order No`、Status、Payment、配送、国、合計、詳細導線を表示する。
- Order Detailは注文日時、ステータス、支払い、配送進捗、チャネル、ロケール、配送国、Email、印面、出品個体、合計、追跡番号を表示する。
- ステータス更新、出荷情報更新、監査イベント表示は既にある。

adminとの差分:

- AI印影画像表示がない。
- AI Generation ID、AI Variant ID、選択スタイル詳細の表示がない。
- 顧客確認チェック記録の表示がない。
- 既存Web注文など、新フィールド欠損注文との互換表示が必要。

### 4.4 既存app

関連ファイル:

- `app/lib/main.dart`
- `app/lib/app/app.dart`
- `app/pubspec.yaml`

アプリ実装は現在大きく変更中のため、実装開始時に最新のworktreeを確認する。設計上は、既存の旧注文フローを前提にせず、`doc/app-mvp-screen-design.md` の画面コードを正としてfeature-firstで再構成する。

## 5. 対象アーキテクチャ

### 5.1 Flutter feature-first構成

推奨ディレクトリ:

```text
app/lib/
├─ app/
│  ├─ app.dart
│  ├─ navigation/
│  ├─ theme/
│  └─ localization/
├─ core/
│  ├─ api/
│  ├─ errors/
│  ├─ storage/
│  └─ widgets/
└─ features/
   ├─ common/
   ├─ design/
   ├─ my_seals/
   ├─ stones/
   ├─ order/
   ├─ order_lookup/
   └─ settings/
```

各featureは原則として以下を持つ。

```text
data/
domain/
presentation/
```

`presentation` には `screen`、`view_model`、小さなfeature専用widgetを置く。共通部品は `core/widgets` に置く。

### 5.2 状態管理

- `miniriverpod` を使う。
- 画面状態は `idle` / `loading` / `success` / `empty` / `error` を明示する。
- Design作成途中、注文下書き、選択中の印影、選択中の石、Checkout入力はそれぞれViewModelで所有を分ける。
- My Sealsの保存済みデータはローカルRepositoryを通して読み書きする。

### 5.3 ナビゲーション

- `declarative_nav` を使う。
- `COM-003 BottomNavigationShell` 配下に3タブを持ち、各タブは独立したstackを保持する。
- Order Stack、Order Lookup Stack、Settings Stackはタブ外のstackとして扱う。
- `go_router` は使わない。

### 5.4 ローカル保存

保存対象:

- `LocalSealDesign`
- `hasSeenOnboarding`
- 必要最小限の注文下書き
- 言語設定

保存しないもの:

- カード情報
- Stripe Checkout Sessionの秘密情報
- Firebase Authユーザー情報
- 端末間同期を期待させるデータ

画像保存:

- AI印影画像は端末ファイルとして保存し、メタデータはローカルDBに保存する。
- MVPのローカル保存は `sqflite` + `path_provider` を採用する。`sqflite` には `LocalSealDesign` メタデータ、`path_provider` で取得したアプリ文書領域には印影PNGを保存する。
- `app/pubspec.yaml` に `sqflite`、`path_provider`、`path` を追加する。
- 保存失敗時は `ERR-005 PermissionStorageErrorScreen` または同等の状態表示を出す。

## 6. 画面コードと実装責任

| 画面群 | 実装責任 | 主な保存先 | 主なAPI |
| --- | --- | --- | --- |
| `COM-*` | 初回表示、Settings、法務/FAQ/問い合わせ導線 | 端末設定 | `GET /v1/config/public` |
| `DES-*` | 名前入力、漢字候補、スタイル選択、AI印影生成、保存 | ローカルDB、注文下書き | `POST /v1/kanji-candidates`, `POST /v1/seal-designs/generate` |
| `MYS-*` | 保存済み印影一覧、詳細、削除、注文用選択 | ローカルDB | なし |
| `STN-*` | 石一覧、詳細、フィルタ、選択 | 注文下書き | `GET /v1/catalog`, `GET /v1/stone-listings` |
| `CMB-*` | 印影と石の組み合わせ確認、変更導線 | 注文下書き | `GET /v1/stone-listings/{listing_id}` による最新在庫確認、最終価格は `POST /v1/orders` で再計算 |
| `CHK-*` | Checkout入力、注文確認、同意、Stripe遷移、戻り後確認 | Firestore via API | `POST /v1/orders`, `POST /v1/payments/stripe/checkout-session`, `GET /v1/orders/{order_id}/status` |
| `LKP-*` | 注文照会、注文状態、追跡表示 | Firestore via API | `POST /v1/orders/lookup` |
| `NTC-*` / `ERR-*` | 通知、メール案内、共通エラー | なし | 呼び出し元に依存 |

## 7. データ契約

### 7.1 LocalSealDesign

端末内に保存する。クラウド同期しない。
この例はDart側のローカルモデル名に合わせて `camelCase` で記載する。API境界のJSONは `snake_case` とし、DTOで相互変換する。

```json
{
  "id": "local_seal_001",
  "inputName": "Michael",
  "selectedKanji": "美空",
  "reading": "Misora",
  "meaning": "Beautiful sky",
  "impression": ["Elegant", "Gentle", "Poetic"],
  "characterCount": 2,
  "strokeComplexity": "medium",
  "engravingSuitability": "high",
  "shape": "square",
  "style": "elegant",
  "strokeWeight": "standard",
  "balance": "balanced",
  "aiGenerationId": "seal_request_001",
  "aiVariantId": "seal_variant_001",
  "previewImageStoragePath": "seal_designs/seal_request_001/seal_variant_001.png",
  "previewImageDownloadUrl": "https://firebasestorage.googleapis.com/...",
  "localImagePath": "local/path/seal_variant_001.png",
  "isFavorite": false,
  "createdAt": "2026-05-21T11:00:00+09:00",
  "updatedAt": "2026-05-21T11:10:00+09:00"
}
```

### 7.2 漢字候補生成

既存 `POST /v1/kanji-candidates` をアプリから直接呼ぶ。現行APIは `serde(deny_unknown_fields)` のため、まず既存フィールド名に合わせる。MVPで必要な表示項目が既存レスポンスに不足する場合は、API側のresponseを拡張してからアプリで表示する。

Request:

```json
{
  "real_name": "Michael",
  "reason_language": "en",
  "kanji_style": "japanese",
  "gender": "unspecified",
  "count": 5
}
```

Response:

```json
{
  "candidates": [
    {
      "kanji": "美空",
      "reading": "Misora",
      "meaning": "Beautiful sky",
      "impression": ["Elegant", "Gentle", "Poetic"],
      "reason": "A graceful two-character option with a soft and natural impression.",
      "character_count": 2,
      "stroke_complexity": "medium",
      "engraving_suitability": "high"
    }
  ]
}
```

Validation:

- `real_name` は空不可。
- 候補の漢字は1から2文字。
- 空白、3文字以上、難字、旧字体、攻撃的/不吉な意味は避ける。
- 表示候補数は3から5件。
- 現行responseは `kanji`、`reading`、`reason` のみ。`meaning`、`impression`、`character_count`、`stroke_complexity`、`engraving_suitability` を表示する場合は、API responseとGemini prompt/parserを拡張する。

### 7.3 AI印影生成

新規APIとして `POST /v1/seal-designs/generate` を実装する。

Request:

```json
{
  "input_name": "Michael",
  "kanji": "美空",
  "shape": "square",
  "style": "elegant",
  "stroke_weight": "standard",
  "balance": "balanced",
  "variant_count": 3,
  "generation_rules": {
    "max_characters": 2,
    "avoid_complex_characters": true,
    "engraving_friendly": true,
    "avoid_thin_lines": true,
    "avoid_decorative_details": true,
    "plain_background": true
  }
}
```

Response:

```json
{
  "request_id": "seal_request_001",
  "variants": [
    {
      "id": "seal_variant_001",
      "storage_path": "seal_designs/seal_request_001/seal_variant_001.png",
      "download_url": "https://firebasestorage.googleapis.com/...",
      "label": "Elegant and balanced",
      "width": 1024,
      "height": 1024
    }
  ]
}
```

APIの責務:

- 生成AIの一時URLを注文の正本にしない。
- Firebase Storageへ保存した `storage_path` を正とする。
- 外部URLや期限付きURLを `orders.seal.preview_image.storage_path` として受け付けない。
- 生成結果が指定漢字以外、3文字以上、細線、背景模様、読めない字形の場合は破棄または失敗扱いにする。

### 7.4 app注文作成

既存 `POST /v1/orders` を拡張する。`channel = app` のとき、AI印影と顧客確認を必須にする。`channel = web` の既存注文は後方互換を維持する。

Request:

```json
{
  "channel": "app",
  "locale": "en",
  "idempotency_key": "uuid",
  "terms_agreed": true,
  "seal": {
    "line1": "美",
    "line2": "空",
    "shape": "square",
    "font_key": "ai_generated_seal",
    "ai_generation_id": "seal_request_001",
    "ai_variant_id": "seal_variant_001",
    "preview_image": {
      "storage_path": "seal_designs/seal_request_001/seal_variant_001.png",
      "download_url": "https://firebasestorage.googleapis.com/...",
      "width": 1024,
      "height": 1024
    },
    "style": {
      "name": "elegant",
      "stroke_weight": "standard",
      "balance": "balanced",
      "prompt_summary": "Elegant, standard stroke, balanced spacing."
    }
  },
  "listing_id": "stone_listing_001",
  "shipping": {
    "country_code": "US",
    "recipient_name": "Michael Smith",
    "phone": "+1-000-000-0000",
    "postal_code": "10001",
    "state": "NY",
    "city": "New York",
    "address_line1": "123 Example Street",
    "address_line2": "Apt 1"
  },
  "contact": {
    "email": "customer@example.com",
    "preferred_locale": "en"
  },
  "customer_confirmation": {
    "kanji_and_design": true,
    "custom_made_policy": true,
    "confirmed_at": "2026-05-21T11:00:00Z",
    "confirmed_seal_text": "美空"
  },
  "order_note": "Optional note"
}
```

Response:

```json
{
  "order_id": "order_001",
  "order_no": "HF-20260521-0001",
  "status": "pending_payment",
  "payment_status": "unpaid",
  "fulfillment_status": "pending",
  "total": 21000,
  "currency": "JPY"
}
```

Validation:

- `terms_agreed == true`。
- `customer_confirmation.kanji_and_design == true`。
- `customer_confirmation.custom_made_policy == true`。
- `customer_confirmation.confirmed_at` はISO 8601 timestampとしてparseできる。保存時はAPI受信時刻で上書きしてよい。
- `customer_confirmation.confirmed_seal_text` は `seal.line1 + seal.line2` と一致。
- `seal.ai_variant_id` は空不可。
- `seal.preview_image.storage_path` は許可されたStorage prefix配下。
- `seal.style.name` は `traditional` / `elegant` / `soft` / `bold`。
- `seal.style.stroke_weight` は `standard` / `bold`。`fine` はMVPでは不可。
- `seal.style.balance` は `airy` / `balanced` / `dense`。
- `order_note` は任意。保存する場合は最大1000文字に制限し、`orders.order_note` として保存する。admin表示は任意だが、保存するならOrder Detailで確認できるようにする。
- 価格、送料、税、合計はAPI側で再計算。
- `listing.status == published` のみ注文可能。注文作成時に `reserved` へ更新。
- app注文の `font_key` は既存 `orders.seal.font_key` との互換フィールドとして保持する。
- `fonts` に active system record `ai_generated_seal` を用意し、既存のfont lookupを通す。
- `ai_generated_seal` の表示名は `AI generated seal preview`、versionは通常のfont version管理に従う。
- 制作確認の正本は `seal.preview_image.storage_path`、`seal.ai_variant_id`、`seal.style.*` とする。

### 7.5 注文状態取得

新規 `GET /v1/orders/{order_id}/status`。

Response:

```json
{
  "order_id": "order_001",
  "order_no": "HF-20260521-0001",
  "status": "paid",
  "payment": {
    "status": "paid",
    "checkout_session_id": "cs_test_xxx",
    "payment_intent_id": "pi_xxx"
  },
  "fulfillment": {
    "status": "pending",
    "carrier": null,
    "tracking_no": null
  },
  "updated_at": "2026-05-21T11:15:00Z"
}
```

用途:

- `CHK-011` でStripeから戻った後に確認する。
- Webhook未反映なら `CHK-014 PaymentPendingScreen` を表示する。
- アプリ側の再取得はCheckout戻り直後の前景画面に限り、例として `2秒間隔で最大3回` のような短時間・明示的な確認に限定する。Web/adminにはポーリングを実装しない。

### 7.6 注文照会

新規 `POST /v1/orders/lookup`。

Request:

```json
{
  "order_no": "HF-20260521-0001",
  "email": "customer@example.com"
}
```

Response:

```json
{
  "order_id": "order_001",
  "order_no": "HF-20260521-0001",
  "created_at": "2026-05-21T11:00:00Z",
  "status": "paid",
  "payment_status": "paid",
  "fulfillment_status": "pending",
  "seal": {
    "confirmed_seal_text": "美空",
    "preview_image_url": "https://..."
  },
  "listing": {
    "id": "stone_listing_001",
    "title": "Soft Pink Rose Quartz Seal Stone"
  },
  "fulfillment": {
    "carrier": null,
    "tracking_no": null,
    "shipped_at": null
  }
}
```

Security:

- 注文番号とメールが一致しない場合は詳細を返さない。
- not found と email mismatch はユーザーには同じ `not found` 表示でよい。
- 返す個人情報は注文者本人が入力した内容と注文状態に限定する。

### 7.7 石一覧・石詳細

既存 `GET /v1/stone-listings` を `STN-001` の一覧取得に使う。`STN-007 Stone Detail` のため、`GET /v1/stone-listings/{listing_id}?locale=en` を追加し、単一の出品個体詳細を返す。

Detail responseに必要な項目:

```json
{
  "id": "stone_listing_001",
  "code": "RQZ-0001",
  "material_key": "rose_quartz",
  "material_label": "Rose quartz",
  "title": "Soft Pink Rose Quartz Seal Stone",
  "description": "A soft pink rose quartz seal stone with a gentle and elegant impression.",
  "story": "A one-of-a-kind piece with a soft natural tone and delicate translucency.",
  "price": {
    "amount": 18000,
    "currency": "JPY",
    "display": "JPY 18,000"
  },
  "size": {
    "width_mm": 24,
    "height_mm": 24,
    "depth_mm": 60
  },
  "facets": {
    "color_family": "pink",
    "pattern_primary": "plain",
    "stone_shape": "square"
  },
  "photos": [
    {
      "asset_id": "asset_001",
      "asset_url": "https://...",
      "alt": "Soft Pink Rose Quartz Seal Stone photo",
      "is_primary": true
    }
  ],
  "status": "published"
}
```

Rules:

- アプリに非公開・予約済み・販売済みの出品個体を注文可能として返さない。
- detail取得時点で `status != published` の場合、アプリは `STN-010 SoldOutStoneState` を表示する。
- 画像URLはStorage pathからAPIが配信用URLを生成する。Firestoreに期限付きURLを保存しない。

### 7.8 APIエラー形式と画面マッピング

既存APIのエラー形式に合わせる。

```json
{
  "error": {
    "code": "validation_error",
    "message": "invalid input"
  }
}
```

| API error code | 主な画面状態 |
| --- | --- |
| `validation_error` | `DES-013`, `CHK-005`, `LKP-004` |
| `unsupported_locale` | `ERR-007` |
| `invalid_reference` | `ERR-007` または対象画面の再選択導線 |
| `inactive_reference` | `STN-010`, `CMB-003` |
| `material_shape_mismatch` | `CMB-003` または `CHK-005` |
| `idempotency_conflict` | `ERR-007` |
| `gemini_not_configured` | `DES-011` |
| `gemini_generation_failed` | `DES-011` |
| `seal_generation_failed` | `DES-012` |
| `stripe_not_configured` | `CHK-013` |
| `stripe_checkout_failed` | `CHK-013` |
| `not_found` | `LKP-004` |
| `internal` | `ERR-002` |

アプリはHTTP statusだけで分岐せず、`error.code` を優先して表示状態を決める。未知のcodeは `ERR-007 GenericErrorScreen` に寄せる。

## 8. UI仕様

### 8.1 共通UI

- 画面コードをWidget test名、ログ、スクリーンショット名に使う。
- Loading、Empty、Error、Successは画面コードがあっても同一Screen内状態として実装してよい。
- ボタンは主要操作と副操作を明確に分ける。
- 画面上の金額はAPIから取得した通貨で表示する。
- タップ可能要素は十分なタップ領域を持つ。
- 入力エラーは該当フィールド近くと画面上部サマリーの両方で伝える。

### 8.2 Design

対象画面:

- `DES-001` から `DES-015`

必須状態:

| 状態 | 表示 |
| --- | --- |
| 名前未入力 | `DES-013` として同一画面内エラー表示 |
| 漢字候補生成中 | `DES-003` |
| 漢字候補なし | `DES-014` |
| 漢字候補生成失敗 | `DES-011` |
| 印影生成中 | `DES-007` |
| 印影生成失敗 | `DES-012` |
| 再生成上限 | `DES-015` |

スタイル選択:

| 項目 | 選択肢 | 初期値 |
| --- | --- | --- |
| Shape | `square` / `round` | `square` |
| Style | `traditional` / `elegant` / `soft` / `bold` | `elegant` |
| Stroke Weight | `standard` / `bold` | `standard` |
| Balance | `airy` / `balanced` / `dense` | `balanced` |

### 8.3 My Seals

対象画面:

- `MYS-001` から `MYS-008`

必須操作:

- 保存済み印影一覧表示。
- 空状態表示。
- 詳細表示。
- 削除確認。
- 注文用印影として選択。

MVPで後回し可能:

- 編集再生成。
- 2から4件比較。
- お気に入りの高度な並び替え。

### 8.4 Stones

対象画面:

- `STN-001` から `STN-010`

一覧表示項目:

- 商品画像
- 素材名
- 一点物タイトル
- 価格
- 色
- 模様
- 在庫状態
- Select Stone

詳細表示項目:

- メイン画像
- サブ画像
- 素材名
- 一点物タイトル
- 説明
- 作品紹介
- 価格
- サイズ
- 色
- 模様
- 質感
- 重さ
- 在庫状態
- 注意事項

### 8.5 Checkout

対象画面:

- `CHK-001` から `CHK-015`

入力項目:

- Email
- Full name
- Country / Region
- Postal code
- Address line 1
- Address line 2
- City
- State / Province
- Phone number
- Order note 任意

注文前確認:

- 印影画像
- 彫刻する漢字
- 漢字の意味
- 選択スタイル
- 宝石材
- 配送先
- メールアドレス
- 商品価格
- 送料
- 合計金額
- 注意事項
- `I confirm that the selected kanji and seal design are correct.`
- `I understand that this is a custom-made item and cannot be changed after production begins.`

### 8.6 Order Lookup

対象画面:

- `LKP-001` から `LKP-006`

入力:

- Order No
- Email

表示:

- 注文番号
- 注文日
- 注文ステータス
- 決済ステータス
- 制作ステータス
- 発送ステータス
- 追跡番号
- 注文内容

### 8.7 MVP必須/後回し画面のタスク分解

`doc/app-mvp-screen-design.md` の「MVPで必須の画面」と「MVPでは後回しでもよい画面」は、以下のTask IDで実装する。状態画面やセクションとして扱うものも、対応する親ScreenのTask IDに含めて検証する。

#### MVP必須画面

| 画面コード | 実装タスク | MVPでの到達点 |
| --- | --- | --- |
| `COM-001` | M03-T01 | 初回判定後にOnboardingまたはShellへ遷移 |
| `COM-002` | M03-T02 | 価値説明とローカル保存注意を表示し、完了状態を端末保存 |
| `COM-003` | M02-T01 | 3タブ切り替えと各タブstack保持 |
| `DES-001` | M04-T01 | 名前入力導線から候補生成へ進める |
| `DES-004` | M04-T03, M04-T04 | 漢字候補API結果と候補詳細項目を表示 |
| `DES-006` | M05-T01 | Shape/Style/Stroke/Balanceを固定UIで選択 |
| `DES-008` | M05-T05 | AI印影候補3件から1件を選択 |
| `DES-009` | M05-T06 | 選択印影を拡大確認し、保存または注文導線へ進める |
| `MYS-001` | M06-T03 | 保存済み印影カードと空状態を表示 |
| `MYS-003` | M06-T04 | 印影画像、漢字、意味、スタイル、作成日を表示 |
| `STN-001` | M07-T01 | 石一覧のLoading/Error/Listを表示 |
| `STN-007` | M07-T05 | 石詳細、サイズ、価格、在庫、注意事項を表示 |
| `CMB-001` | M08-T02 | 印影と宝石材の組み合わせを確認 |
| `CHK-001` | M09-T01 | 連絡先、配送先、注文メモを入力 |
| `CHK-006` | M09-T03 | 注文前確認と2つの確認チェックを必須化 |
| `CHK-008` | M09-T07 | 注文作成とCheckout Session作成中を表示 |
| `CHK-011` | M09-T09 | Stripe戻り後に注文状態を確認 |
| `CHK-012` | M09-T10 | Stripeキャンセル時の表示 |
| `CHK-015` | M09-T11 | 注文番号、概要、メール案内、照会導線を表示 |
| `LKP-001` | M10-T03 | 注文番号とメールを入力 |
| `LKP-003` | M10-T05 | 注文、決済、制作、発送、追跡を表示 |
| `COM-004` | M03-T03 | 言語、About、FAQ、Privacy、Terms、Contact、versionへ遷移 |
| `COM-005` | M03-T04 | Aboutをアプリ向けに表示 |
| `COM-007` | M03-T04 | FAQをアプリ向けに表示 |
| `COM-009` | M03-T04 | Privacyをアプリ向けに表示 |
| `COM-010` | M03-T04 | Termsをアプリ向けに表示 |
| `ERR-001` | M12-T04 | 通信エラーを共通表示 |
| `ERR-007` | M12-T04 | 未知のAPIエラー/想定外エラーを共通表示 |

#### MVPでは後回しでもよい画面

| 画面コード | 実装タスク | 後回し時の扱い |
| --- | --- | --- |
| `DES-005` | M04-T05 | 候補カード内表示で代替し、詳細画面は後続実装 |
| `MYS-004` | M06-T06 | 編集再生成導線は無効または説明表示に留める |
| `MYS-005` | M06-T06 | 比較選択は後続実装 |
| `MYS-006` | M06-T06 | 比較表示は後続実装 |
| `STN-006` | M07-T04 | 初期表示順で代替し、ソートUIは後続実装 |
| `STN-008` | M07-T06 | 詳細画面内の画像表示で代替し、拡大ギャラリーは後続実装 |
| `CMB-004` | M08-T04 | My Sealsへ戻る導線で代替 |
| `CMB-005` | M08-T04 | Stonesへ戻る導線で代替 |
| `LKP-006` | M10-T06 | 照会結果画面内の追跡番号表示で代替 |
| `COM-006` | M03-T05 | Settings導線が破綻しない範囲で後続実装 |
| `COM-008` | M03-T05 | Contact導線は外部問い合わせ/メール案内で代替 |
| `ERR-003` | M12-T06 | 公開設定による制御は後続実装 |
| `ERR-004` | M12-T06 | 強制アップデート表示は後続実装 |

## 9. 実装マイルストーン

### M01: 要件固定と差分棚卸し

| Task ID | 領域 | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M01-T01 | docs | [x] 画面コードを実装/テスト/スクリーンショットの固定IDとして採用する | `doc/app-mvp-screen-design.md` | 全必須画面にコードがあり、実装名に対応できる |
| M01-T02 | docs | [x] 既存Web機能を `流用` / `変更` / `新規` / `廃止` に分類する | この文書 | 比較サマリーが保守されている |
| M01-T03 | docs | [x] MVP必須画面と後回し画面をタスクへ分解する | この文書 | M01からM13までのタスクがある |
| M01-T04 | policy | [x] Web/adminのポーリング/ストリーミング禁止を実装計画に反映する | `AGENTS.md`, この文書 | Web/adminタスクにSSE/WebSocket/定期ポーリングがない |

### M02: Flutterアプリ基盤

| Task ID | 領域 | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M02-T01 | app nav | [x] `COM-003` Bottom Navigation Shellを `declarative_nav` で実装する | `app/lib/app/navigation/`, `app/lib/app/app.dart` | `Design` / `My Seals` / `Stones` の3タブが切り替わり、各stackが保持される |
| M02-T02 | app structure | [x] feature-first構成を作る | `app/lib/features/**` | design/my_seals/stones/order/order_lookup/settings が分離される |
| M02-T03 | app data | [x] API client/Repository/DTOの境界を作る | `app/lib/core/api/`, `app/lib/features/*/data/` | APIレスポンスをdomain modelへ変換できる |
| M02-T04 | app ui | [x] 共通テーマと共通Widgetを作る | `app/lib/core/widgets/`, `app/lib/app/theme/` | 主要画面が共通ボタン/カード/フォーム/状態表示を使う |
| M02-T05 | app i18n | [x] `ja` / `en` 文言管理を用意する | `app/lib/app/localization/` | 主要文言がロケールで切り替わる |
| M02-T06 | app storage | [x] ローカル保存依存関係を追加 | `app/pubspec.yaml` | `sqflite`、`path_provider`、`path` を追加し、端末内メタデータ/画像保存の基盤を作る |

### M03: 共通・初回画面

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M03-T01 | `COM-001` | [x] Splash画面 | `features/common/presentation/` | 初回判定後にOnboardingまたはShellへ遷移 |
| M03-T02 | `COM-002` | [x] Onboarding画面 | `features/common/presentation/` | 価値説明とローカル保存注意を表示し、完了状態を端末保存 |
| M03-T03 | `COM-004` | [x] Settings画面 | `features/settings/presentation/` | 言語、About、FAQ、Privacy、Terms、Contact、versionへ遷移 |
| M03-T04 | `COM-005` `COM-007` `COM-009` `COM-010` | [x] About、FAQ、Privacy、Terms | `features/settings/presentation/` | Web文言/法務リンクをアプリ向けに表示 |
| M03-T05 | `COM-006` `COM-008` | [x] How It Works、Contact | `features/settings/presentation/` | 後回しでもSettings導線が破綻しない |

### M04: Designタブ - 漢字候補

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M04-T01 | `DES-001` `DES-002` | [x] 名前入力導線 | `features/design/presentation/` | 名前を入力し、候補生成へ進める |
| M04-T02 | `DES-003` `DES-011` `DES-013` `DES-014` | [x] Loading/Error/Invalid/No result状態 | `features/design/presentation/` | 状態ごとの表示と再試行導線がある |
| M04-T03 | `DES-004` | 漢字候補API接続 | `features/design/data/` | `POST /v1/kanji-candidates` の結果を表示 |
| M04-T04 | `DES-004` | 候補カード詳細項目 | `features/design/domain/` | 漢字、読み方、意味、印象、理由、彫刻適性を表示 |
| M04-T05 | `DES-005` | 候補詳細 | `features/design/presentation/` | 候補の詳細を確認して選択できる |

### M05: Designタブ - AI印影生成

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M05-T01 | `DES-006` | スタイル選択固定UI | `features/design/presentation/` | Shape/Style/Stroke/Balanceを選べる |
| M05-T02 | API | AI印影生成API | `api/src/main.rs` | `POST /v1/seal-designs/generate` が3variantを返す |
| M05-T03 | Storage | 生成画像のStorage保存 | `api/src/main.rs` | `storage_path` と表示用URLを返す |
| M05-T04 | `DES-007` `DES-012` `DES-015` | 生成中/失敗/上限状態 | `features/design/presentation/` | 再試行と上限表示がある |
| M05-T05 | `DES-008` | 3候補選択 | `features/design/presentation/` | AI印影候補から1件選べる |
| M05-T06 | `DES-009` | プレビュー詳細 | `features/design/presentation/` | 拡大確認後、保存または注文導線へ進める |

### M06: My Seals ローカル保存

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M06-T01 | `MYS-*` | `LocalSealDesign` domain/data実装 | `features/my_seals/domain/`, `features/my_seals/data/` | ローカル保存/読込/削除ができる |
| M06-T02 | `DES-010` | 保存完了画面 | `features/design/presentation/` | My Sealsへ移動、石選択へ移動、Designへ戻る導線 |
| M06-T03 | `MYS-001` `MYS-002` | 一覧/空状態 | `features/my_seals/presentation/` | 保存済み印影カードと空状態を表示 |
| M06-T04 | `MYS-003` | 詳細 | `features/my_seals/presentation/` | 印影画像、漢字、意味、スタイル、作成日を表示 |
| M06-T05 | `MYS-007` `MYS-008` | 削除確認/注文用選択 | `features/my_seals/presentation/` | 削除とOrder Draft反映ができる |
| M06-T06 | `MYS-004` `MYS-005` `MYS-006` | 編集/比較 | `features/my_seals/presentation/` | MVP後回し可能。導線は破綻させない |

### M07: Stonesタブ

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M07-T01 | `STN-001` `STN-003` `STN-004` | 石一覧取得と状態表示 | `features/stones/data/`, `features/stones/presentation/` | Loading/Error/Listが表示できる |
| M07-T02 | API | 石一覧/詳細API | `api/src/main.rs` | `GET /v1/stone-listings` をアプリ一覧で使えるレスポンスにし、`GET /v1/stone-listings/{listing_id}` を追加する |
| M07-T03 | `STN-005` | フィルタ | `features/stones/presentation/` | Material/Color/Pattern/Availabilityで絞り込み |
| M07-T04 | `STN-006` | ソート | `features/stones/presentation/` | 後回し可能。仕様は新着/価格順 |
| M07-T05 | `STN-007` | 詳細 | `features/stones/presentation/` | 画像、説明、サイズ、価格、在庫、注意事項を表示 |
| M07-T06 | `STN-008` | 画像ギャラリー | `features/stones/presentation/` | 複数画像を拡大表示 |
| M07-T07 | `STN-009` `STN-010` | 選択確認/売り切れ | `features/stones/presentation/` | 売り切れ時は注文へ進めない |

### M08: 印影 + 宝石材 組み合わせ

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M08-T01 | Order Draft | 注文下書きモデル | `features/order/domain/`, `features/order/data/` | タブをまたいで選択印影/石/入力が保持される |
| M08-T02 | `CMB-001` | 組み合わせ確認 | `features/order/presentation/` | 印影画像、漢字、スタイル、石、価格、送料、合計を表示 |
| M08-T03 | `CMB-002` `CMB-003` | Missing状態 | `features/order/presentation/` | 印影または石未選択時に次アクションを提示 |
| M08-T04 | `CMB-004` `CMB-005` | 変更導線 | `features/order/presentation/` | My Seals/Stonesへ戻って選び直せる |

### M09: Checkout / Stripe Checkout

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M09-T01 | `CHK-001` `CHK-002` `CHK-003` `CHK-004` | Checkout入力 | `features/order/presentation/` | 連絡先、配送先、注文メモを入力 |
| M09-T02 | `CHK-005` | 入力不備表示 | `features/order/presentation/` | 不備をまとめて表示し、該当入力へ戻れる |
| M09-T03 | `CHK-006` `CHK-007` | 注文前確認/同意 | `features/order/presentation/` | 漢字/印影確認とcustom-made確認が必須 |
| M09-T04 | API | app注文用Request拡張 | `api/src/main.rs` | app注文でAI印影と顧客確認を保存 |
| M09-T05 | API | web注文互換 | `api/src/main.rs`, `web/src/main.rs` | 既存Web注文が壊れない |
| M09-T06 | seed/data | AI生成印影用font record追加 | `api/src/bin/seed_catalog.rs` または既存seed運用 | `fonts/ai_generated_seal` がactiveで作成され、APIの既存font lookupを通る |
| M09-T07 | `CHK-008` | Checkout Session作成中 | `features/order/presentation/` | 注文作成とSession作成中を表示 |
| M09-T08 | `CHK-009` `CHK-010` | Stripe外部遷移 | `features/order/presentation/` | Checkout URLを開き、戻りURLを処理 |
| M09-T09 | `CHK-011` `CHK-014` | 成功確認/Pending | `features/order/presentation/`, `api/src/main.rs` | 戻り後に注文状態を確認し、未反映ならPending |
| M09-T10 | `CHK-012` `CHK-013` | キャンセル/失敗 | `features/order/presentation/` | キャンセルと失敗を分ける |
| M09-T11 | `CHK-015` | 注文完了 | `features/order/presentation/` | 注文番号、概要、メール案内、照会導線を表示 |

### M10: 注文状態取得・Order Lookup

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M10-T01 | API | 注文状態取得 | `api/src/main.rs` | `GET /v1/orders/{order_id}/status` が状態を返す |
| M10-T02 | API | 注文照会 | `api/src/main.rs` | `POST /v1/orders/lookup` が注文番号+メールで検索 |
| M10-T03 | `LKP-001` | 照会入力 | `features/order_lookup/presentation/` | 注文番号とメールを入力 |
| M10-T04 | `LKP-002` `LKP-004` `LKP-005` | Loading/Not found/Error | `features/order_lookup/presentation/` | 状態を区別して表示 |
| M10-T05 | `LKP-003` | 照会結果 | `features/order_lookup/presentation/` | 注文、決済、制作、発送、追跡を表示 |
| M10-T06 | `LKP-006` | 追跡詳細 | `features/order_lookup/presentation/` | 後回し可能 |

### M11: admin連携

| Task ID | 領域 | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M11-T01 | admin一覧 | 彫刻文字、AI Variant ID、決済/発送状態の表示改善 | `admin/templates/orders_list.html`, `admin/src/main.rs` | app注文を一覧で識別できる |
| M11-T02 | admin詳細 | AI印影画像表示 | `admin/templates/order_detail.html`, `admin/src/main.rs` | `seal.preview_image.storage_path` から画像を表示 |
| M11-T03 | admin詳細 | AI Generation/Variant/Style表示 | `admin/templates/order_detail.html`, `admin/src/main.rs` | `seal.ai_generation_id`, `seal.ai_variant_id`, `seal.style.*` を表示 |
| M11-T04 | admin詳細 | 顧客確認チェック表示 | `admin/templates/order_detail.html`, `admin/src/main.rs` | `customer_confirmation.*` と確認時刻を表示 |
| M11-T05 | admin互換 | 欠損データ対応 | `admin/src/main.rs` | 既存Web注文で詳細画面が壊れない |
| M11-T06 | admin操作 | app注文のステータス/出荷操作確認 | `admin/src/main.rs` | app注文でも既存操作が使える |

### M12: 通知・メール・共通エラー

| Task ID | 画面コード | タスク | 主要ファイル | 完了条件 |
| --- | --- | --- | --- | --- |
| M12-T01 | `NTC-001` | メール送信済み案内 | `features/order/presentation/`, `features/order_lookup/presentation/` | 注文完了/照会で表示 |
| M12-T02 | `NTC-002` | メール未着ガイド | `features/order/presentation/` | 確認事項と問い合わせ導線 |
| M12-T03 | `NTC-003` | 問い合わせ導線 | `features/settings/`, `core/widgets/` | 困った時にContactへ遷移 |
| M12-T04 | `ERR-001` `ERR-002` `ERR-007` | 共通エラー | `core/errors/`, `core/widgets/` | API失敗を統一表示 |
| M12-T05 | `ERR-005` `ERR-006` | Storage/Deep Linkエラー | `features/design/`, `features/order/` | 保存失敗/戻りURL失敗を表示 |
| M12-T06 | `ERR-003` `ERR-004` | Maintenance/App Update | `features/common/` | 後回し可能。公開設定で将来制御 |

### M13: QA・テスト・リリース準備

| Task ID | 領域 | タスク | 主要ファイル/コマンド | 完了条件 |
| --- | --- | --- | --- | --- |
| M13-T01 | Flutter unit | ViewModel/Repository単体テスト | `app/test/**` | 漢字候補、印影生成、保存、注文下書き、Checkout状態をテスト |
| M13-T02 | Flutter widget | 必須画面Widget test | `app/test/**` | MVP必須画面の主要状態を描画確認 |
| M13-T03 | API tests | app注文Request拡張テスト | `api/src/main.rs` tests | app channel必須項目、web channel互換を確認 |
| M13-T04 | API tests | 注文状態/照会APIテスト | `api/src/main.rs` tests | paid/pending/failed/not found/email不一致を確認 |
| M13-T05 | Stripe | Checkout/webhook結合テスト | Stripe test mode | success/cancel/failure/webhook反映を確認 |
| M13-T06 | Inventory | 二重販売防止テスト | API integration | 同一listingを同時注文できない |
| M13-T07 | AI品質 | 生成品質テスト | API integration/manual | 1から2文字、可読性、線の太さ、背景なし、余白を確認 |
| M13-T08 | Accessibility | アクセシビリティ確認 | Flutter semantics/manual | 主要状態が読み上げとフォーカス移動に対応 |
| M13-T09 | Release | Deep Link/Universal Links/環境設定確認 | app platform config | Stripeからアプリへ復帰できる |

## 10. 受け入れ基準

### アプリ

- 初回起動時にSplashとOnboardingが表示され、完了後はBottom Navigation Shellへ遷移する。
- `Design` タブで名前入力から漢字候補、スタイル選択、AI印影3候補生成、候補選択、保存まで完了できる。
- `My Seals` タブで保存済み印影を一覧/詳細表示し、削除と注文用選択ができる。
- `Stones` タブで石一覧、フィルタ、詳細、選択ができる。
- 印影と石が揃った状態で注文前確認へ進める。
- Checkout入力、注文確認、2つの確認チェック、Stripe Checkout遷移ができる。
- Stripe戻り後に注文状態をAPIへ問い合わせ、paidならOrder Complete、未反映ならPending、キャンセルならCancelledを表示する。
- 注文番号とメールで注文照会ができる。

### API

- `POST /v1/seal-designs/generate` が3件の印影variantを返し、画像をFirebase Storageへ保存する。
- `POST /v1/orders` は `channel = app` でAI印影情報と顧客確認チェックを必須化する。
- `channel = web` の既存注文作成は壊れない。
- 価格、送料、在庫、合計はサーバー側で再計算される。
- Stripe Webhookで `orders.payment.*`、`orders.status`、在庫状態が更新される。
- 注文状態取得と注文照会APIが、必要最小限の情報だけ返す。

### admin

- Orders一覧でapp注文を判別できる。
- Order DetailでAI印影画像、AI Generation ID、AI Variant ID、スタイル、顧客確認チェック、Stripe ID、発送情報を確認できる。
- AI印影情報がない既存Web注文でも表示が壊れない。
- admin画面にポーリング、SSE、WebSocketを追加していない。

## 11. テスト計画

### Flutter unit test

- `DesignViewModel`: 名前入力、候補生成成功/失敗、候補選択、スタイル選択、生成上限。
- `SealGenerationRepository`: request shape、response parse、error mapping。
- `LocalSealDesignRepository`: 保存、読込、削除、破損データ処理。
- `OrderDraftViewModel`: 印影/石/配送先/同意の状態遷移。
- `CheckoutViewModel`: 注文作成、Checkout Session作成、戻り後状態確認。
- `OrderLookupViewModel`: found/not found/error。

### Flutter widget test

- `COM-002`, `COM-003`, `DES-004`, `DES-006`, `DES-008`, `MYS-001`, `STN-001`, `STN-007`, `CMB-001`, `CHK-001`, `CHK-006`, `CHK-011`, `CHK-015`, `LKP-001`, `LKP-003`。
- Loading/Empty/Error状態は同一Screen内状態として確認する。

### API unit/integration test

- `POST /v1/seal-designs/generate`: 不正文字数、未許可style、生成失敗、Storage保存失敗。
- `POST /v1/orders`: app必須フィールド不足、web互換、価格再計算、在庫予約、冪等性。
- `POST /v1/payments/stripe/checkout-session`: pending_payment/unpaid以外の拒否。
- Stripe webhook: completed、failed、refunded、重複イベント。
- `GET /v1/orders/{order_id}/status`: not found、paid、pending。
- `POST /v1/orders/lookup`: email一致、不一致、not found。

### admin test

- AI印影あり注文のOrder Detail描画。
- AI印影なしWeb注文のOrder Detail描画。
- Orders一覧に新項目を表示。
- ステータス更新/出荷更新が既存通り動く。

### 手動E2E

1. 初回起動 -> Onboarding完了。
2. Designで名前入力 -> 漢字候補選択 -> スタイル選択 -> AI印影生成 -> 保存。
3. My Sealsで保存済み印影を確認。
4. Stonesで石を選択。
5. Seal + Stone Confirmation -> Checkout Information -> Order Confirmation。
6. Stripe Checkout test cardで成功。
7. Order Completeを確認。
8. Order Lookupで注文状態を確認。
9. adminでAI印影画像と顧客確認チェックを確認。
10. Stripe失敗/キャンセルを確認。

## 12. リリース・互換・ロールバック

### 互換

- 既存Web注文はAI印影情報なしで継続可能にする。
- Firestoreの新フィールドは optional として読み、app注文ではAPI validationで必須化する。
- adminは新フィールド欠損時に `-` や「Web注文」と表示する。

### Rollout

- API拡張を先にdeployし、web互換テストを通す。
- admin表示を次にdeployし、新旧注文の表示を確認する。
- appをdev環境でAI生成/Checkout/Lookupまで確認する。
- prod公開前にStripe test modeとFirestore dev/prod設定を確認する。

### Rollback

- app公開後にAI印影生成に問題が出た場合、アプリ側で生成導線を一時停止し、既存Web注文は維持する。
- APIのapp注文拡張に問題が出た場合、`channel = web` の互換を維持したままapp注文をメンテナンス表示にする。
- admin表示追加は欠損時表示へフォールバックできるようにし、注文処理を止めない。

## 13. 未確定事項

| ID | 未確定事項 | 現時点の扱い |
| --- | --- | --- |
| OQ-001 | AI画像生成プロバイダ | API内部実装として扱い、アプリは `POST /v1/seal-designs/generate` の契約だけに依存する |
| OQ-002 | 注文確認メール送信の実装場所 | 既存API/運用に合わせる。アプリ画面はメール送信済み/未着案内を表示できるようにする |
| OQ-003 | Web版への新画面展開 | この文書の対象外。既存Webは互換維持のみ |

## 14. 実装順の推奨

1. `M01` から `M03` でアプリの土台、画面コード、共通導線を固める。
2. `M04` と `M05` で漢字候補とAI印影生成を成立させる。
3. `M06` と `M07` で保存済み印影と宝石材選択をタブとして成立させる。
4. `M08` と `M09` で注文下書き、確認、Stripe Checkoutを接続する。
5. `M10` と `M11` で注文後の確認とadmin確認を完成させる。
6. `M12` と `M13` でエラー、通知、品質、リリース準備を仕上げる。
