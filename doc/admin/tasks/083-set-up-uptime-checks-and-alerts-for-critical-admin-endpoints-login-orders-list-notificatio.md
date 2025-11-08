# Set up uptime checks and alerts for critical admin endpoints (login, orders list, notifications).

**Parent Section:** 16. Observability & Maintenance
**Task ID:** 083

## Goal
Set up uptime checks and alerts for critical admin endpoints.

## Implementation Steps
1. Configure Cloud Monitoring uptime checks for `/admin/login`, `/admin/orders` (non-auth alternative via synthetic?).
2. Use service account token or headless browser script for auth-protected checks.
3. Set alert notification channels.

## Status

- ✅ `/admin/uptime/orders` と `/admin/uptime/notifications` の軽量プローブを追加。アプリ層から Orders/Notifications サービスを実際に呼び出してレスポンスを検証し、結果を JSON で返すため Cloud Monitoring からの GET で監視可能になった。
- ✅ `ADMIN_UPTIME_ENABLED/ADMIN_UPTIME_TIMEOUT/ADMIN_UPTIME_SERVICE_TOKEN` でモニタリング挙動を制御可能にし、将来的にサービスアカウント経由でトークンを渡す余地を確保。
- ✅ Terraform に監視リソースを追加し、`google_monitoring_uptime_check_config` で `/admin/login` / `/admin/uptime/*` を 60 秒間隔でチェック。通知チャンネル（メール）と `monitoring.googleapis.com/uptime_check/check_passed` を使った Alert Policy を環境ごとに作成済み。
- ✅ `infra/terraform/envs/*/terraform.tfvars` にホスト名・エンドポイントマップ・通知メールを定義。`admin.dev|stg|prod.hanko-field.com` に対して監視が走る。

## Rollout / Verification

1. `terraform -chdir=infra/terraform init` (初回のみ) → `terraform -chdir=infra/terraform plan -var-file=envs/<env>/terraform.tfvars` を実行して Monitoring リソースの差分を確認。
2. 適用後、Cloud Monitoring → Uptime Check で `admin-<env>-*` が healthy であることを確認。
3. `curl -s https://admin.<env>.hanko-field.com/admin/uptime/orders | jq` で 200/`status=ok` を手動確認。
4. Alert Policy でテスト通知を実施し、`admin_alert_notification_emails` で指定したメールに届くことを確認。
