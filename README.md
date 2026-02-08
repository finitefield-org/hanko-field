# hanko-field

## 前提

このリポジトリの `devbox.json` は Jetify の devbox CLI を前提にしています。
[Jetify Devbox のインストール手順](https://www.jetify.com/docs/devbox/installing_devbox/) を使ってセットアップしてください。

## Docker + devbox でのローカル環境

Docker と devbox で、Go/Flutter/Firebase Emulator をまとめて用意できます。

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
# API (Firestore emulator uses firebase:8081 from compose env)
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

Firebase Emulator UI は `http://localhost:3053` で確認できます。
