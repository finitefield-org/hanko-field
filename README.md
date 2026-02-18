# hanko-field

## 前提

- [Jetify Devbox のインストール](https://www.jetify.com/docs/devbox/installing_devbox/)
- Docker / Docker Compose

`.env` ファイルをまだ作っていない場合だけ実行してください。

```bash
cp .env.dev.example .env.dev
cp .env.prod.example .env.prod
```

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

## モード切替（mock / dev / prod）

既定は `mock` です。`dev` や `prod` を使うときは `.env.dev` / `.env.prod` に必要な Firebase 設定を入れてください。

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
```

## 補足

- Web/Admin の CSS (`ironframe`) は `make docker-admin` / `make docker-web` / `make docker-dev` 実行時に自動ビルドされます。
- 通常開発では `docker compose` 直実行や `ironframe` 手動インストールは不要です。
