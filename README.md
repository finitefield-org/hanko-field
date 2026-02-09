# hanko-field

## 前提

このリポジトリの `devbox.json` は Jetify の devbox CLI を前提にしています。
[Jetify Devbox のインストール手順](https://www.jetify.com/docs/devbox/installing_devbox/) を使ってセットアップしてください。

## Docker + devbox でのローカル環境

Docker と devbox で、Go/Flutter と Firebase テスト環境向けのローカル作業環境を用意できます。

```bash
make docker-up
make docker-shell
```

Docker が起動済みの場合は、以下でコンテナ内から各サービスを起動できます。

```bash
make docker-api
make docker-admin
make docker-web
make docker-dev
```

### Docker Compose で直接起動する手順

`make` を使わずに直接起動する場合は以下を実行してください。
この構成では Firebase Emulator は起動せず、Firebase 上のテストプロジェクトを使います。

```bash
cd /Users/kazuyoshitoshiya/Documents/GitHub/hanko-field

# test project settings (example)
export FIREBASE_PROJECT_ID=<your-firebase-test-project-id>
export GOOGLE_APPLICATION_CREDENTIALS=/workspace/<service-account-json-path>
export API_FIREBASE_CREDENTIALS_FILE=/workspace/<service-account-json-path>
```

```bash
cd /Users/kazuyoshitoshiya/Documents/GitHub/hanko-field

# build and start workspace only
docker compose build
docker compose up -d workspace
```

別ターミナルで開発シェルに入ります。

```bash
cd /Users/kazuyoshitoshiya/Documents/GitHub/hanko-field
docker compose exec workspace devbox shell
```

停止時は以下を実行します。

```bash
cd /Users/kazuyoshitoshiya/Documents/GitHub/hanko-field
docker compose down
```

### Web/Admin のアセット生成（ironframe）

`ironframe` は `devbox run ironframe` で実行し、`0.3.1` に固定しています。
初回実行時に `cargo install` で `.devbox/bin/ironframe` を作成します。

```bash
devbox run ironframe -- --version
```

ビルド・ウォッチは以下のように実行してください。

```bash
# build
devbox run ironframe -- build -i <input.css> -o <output.css> "<glob>..."

# watch
devbox run ironframe -- watch -i <input.css> -o <output.css> "<glob>..."
```

### 開発サーバー例（ポート競合を避ける）

API / Admin / Web の既定ポートはそれぞれ `3050 / 3051 / 3052` です。

```bash
# API (uses Firebase test project)
API_SERVER_PORT=3050 \
API_FIREBASE_PROJECT_ID=hanko-field-dev \
API_FIRESTORE_PROJECT_ID=hanko-field-dev \
API_STORAGE_ASSETS_BUCKET=local-assets \
make -C api run

# Admin
ADMIN_HTTP_ADDR=:3051 \
ADMIN_ALLOW_INSECURE_AUTH=1 \
FIRESTORE_PROJECT_ID=hanko-field-dev \
make -C admin dev

# Web
HANKO_WEB_PORT=3052 \
make -C web dev
```

### Web データソース切替（mock / Firebase dev / Firebase prod）

`web` は `HANKO_WEB_MODE` でデータソースを切り替えられます。

- `mock` (既定): 内蔵モックデータを使用
- `dev`: Firestore（開発用プロジェクト）を使用
- `prod`: Firestore（本番プロジェクト）を使用

主要な環境変数:

- `HANKO_WEB_MODE`: `mock` / `dev` / `prod`
- `HANKO_WEB_LOCALE`: 表示ロケール（既定 `ja`）
- `HANKO_WEB_DEFAULT_LOCALE`: i18n フォールバック（既定 `ja`）
- `HANKO_WEB_FIREBASE_PROJECT_ID_DEV`: `dev` モードの project id
- `HANKO_WEB_FIREBASE_PROJECT_ID_PROD`: `prod` モードの project id
- `HANKO_WEB_FIREBASE_CREDENTIALS_FILE_DEV`: `dev` モードの認証 JSON パス（任意）
- `HANKO_WEB_FIREBASE_CREDENTIALS_FILE_PROD`: `prod` モードの認証 JSON パス（任意）
- `GOOGLE_APPLICATION_CREDENTIALS`: サービスアカウント JSON パス（ADC 使用時は不要）

`make -C web dev` 利用時は、`MODE` と `LOCALE` も指定できます。

```bash
# mock (default)
make -C web dev

# Firebase dev
HANKO_WEB_FIREBASE_PROJECT_ID_DEV=hanko-field-dev \
GOOGLE_APPLICATION_CREDENTIALS=/workspace/<service-account-json-path> \
make -C web dev MODE=dev LOCALE=ja

# Firebase prod
HANKO_WEB_FIREBASE_PROJECT_ID_PROD=hanko-field-prod \
GOOGLE_APPLICATION_CREDENTIALS=/workspace/<service-account-json-path> \
make -C web dev MODE=prod LOCALE=ja
```
