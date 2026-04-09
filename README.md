# hanko-field

## 前提

- [Jetify Devbox のインストール](https://www.jetify.com/docs/devbox/installing_devbox/)
- Docker / Docker Compose

`.env` ファイルをまだ作っていない場合だけ実行してください。

```bash
cp .env.dev.example .env.dev
cp .env.prod.example .env.prod
```

`make docker-dev ENV=dev` や `cargo run` では、Google ADC を使います。
事前に `gcloud auth application-default login` を実行して、
`hanko-field` / `hanko-field-prod` へアクセスできる状態にしてください。
`.env.dev` / `.env.prod` に `GOOGLE_APPLICATION_CREDENTIALS` や
`API_FIREBASE_CREDENTIALS_FILE` は設定しません。

## クイックスタート（推奨）

開発用途でまず動かすなら、以下の 2 コマンドだけで十分です。

```bash
make docker-up ENV=dev
make docker-dev ENV=dev
```

起動後:

- API: `http://localhost:3050`
- Admin: `http://localhost:3051`
- Web: `http://localhost:3052`

停止:

```bash
make docker-down ENV=dev
```

## 単体で起動する

Docker コンテナを先に起動:

```bash
make docker-up ENV=dev
```

必要なサービスだけ起動:

```bash
make docker-api ENV=dev
make docker-admin ENV=dev
make docker-web ENV=dev
```

## よく使うコマンド

```bash
# コンテナ内シェル
make docker-shell ENV=dev

# 使えるターゲット一覧
make help
```

## Stripe webhook をローカルで受ける

API の受け口は固定で `http://localhost:3050/v1/payments/stripe/webhook` です。
Stripe Dashboard から localhost へ直接送れないので、Stripe CLI で転送します。

```bash
make stripe-listen ENV=dev
```

必要なら `STRIPE_WEBHOOK_URL` で転送先を上書きできます。

## モード切替（mock / dev / prod）

既定は `mock` です。`dev` や `prod` を使うときは `.env.dev` / `.env.prod` に必要な Firebase 設定を入れてください。
`make docker-*` は `.env.dev` / `.env.prod` を読みますが、`HANKO_ADMIN_MODE` / `HANKO_WEB_MODE` をコマンドラインで渡した場合はその値を優先します。
Firestore を触らずに `docker-dev` を起動したい場合は、`admin` と `web` の両方を `mock` にします。

Firebase の project ID は次の通りです。

- 開発: `hanko-field`
- 本番: `hanko-field-prod`
- Firestore: どちらも `(default)` データベース

`ENV=prod` で Flutter/App の本番ビルドをする場合は、`.env.prod` の `API_FIRESTORE_PROJECT_ID` を `hanko-field-prod` にし、`API_PSP_STRIPE_API_KEY` は Stripe の live secret key を入れてください。アプリは Firestore や Stripe に直接つながらず、API 経由でこれらの設定を使います。

```bash
# 全サービスを本番相当設定で起動
make docker-up ENV=prod
make docker-dev ENV=prod
```

```bash
# Admin だけ dev モードで起動
HANKO_ADMIN_MODE=dev make docker-admin ENV=dev

# Web だけ prod モードで起動
HANKO_WEB_MODE=prod make docker-web ENV=prod

# Firestore を使わずに dev 環境を起動
HANKO_ADMIN_MODE=mock HANKO_WEB_MODE=mock make docker-dev ENV=dev
```

Firebase CLI で Firestore / Storage のルールをデプロイする場合は、`dev` / `prod` の alias を使って切り替えます。

```bash
firebase deploy --project dev
firebase deploy --project prod
```

## 補足

- Web/Admin の CSS (`ironframe`) は `make docker-admin` / `make docker-web` / `make docker-dev` 実行時に自動ビルドされます。
- 通常開発では `docker compose` 直実行や `ironframe` 手動インストールは不要です。
