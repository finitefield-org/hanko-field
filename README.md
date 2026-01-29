# hanko-field

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

### Web のアセット生成（Tailwind standalone）

`make docker-web` は `web/public/assets` を生成するため、コンテナ内に Tailwind standalone が必要です。
初回のみ、以下を実行してください（Linux ARM64 / aarch64 向け）。

```bash
docker compose exec workspace devbox shell
cd /workspace/web
mkdir -p tools
curl -fsSL https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-arm64 -o tools/tailwindcss
chmod +x tools/tailwindcss
exit
```

他のアーキテクチャの場合は、`tailwindcss-linux-x64` など適切なバイナリ名に置き換えてください。

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
