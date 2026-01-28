# hanko-field

## Docker + devbox でのローカル環境

Docker と devbox で、Go/Flutter/Firebase Emulator をまとめて用意できます。

```bash
docker compose up -d --build
docker compose exec workspace devbox shell
```

### 開発サーバー例（ポート競合を避ける）

API / Admin / Web は既定で `:8080` を使うため、同時起動する場合はポートを分けてください。

```bash
# API (Firestore emulator uses firebase:8081 from compose env)
API_SERVER_PORT=8081 \
API_FIREBASE_PROJECT_ID=hanko-field-dev \
API_FIRESTORE_PROJECT_ID=hanko-field-dev \
API_STORAGE_ASSETS_BUCKET=local-assets \
make -C api run

# Admin
ADMIN_HTTP_ADDR=:8082 \
ADMIN_ALLOW_INSECURE_AUTH=1 \
FIRESTORE_PROJECT_ID=hanko-field-dev \
make -C admin dev

# Web
HANKO_WEB_PORT=8083 \
make -C web dev
```

Firebase Emulator UI は `http://localhost:4000` で確認できます。
