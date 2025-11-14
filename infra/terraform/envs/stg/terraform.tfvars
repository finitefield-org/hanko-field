project_id       = "hanko-field-stg"
region           = "asia-northeast1"
location         = "asia-northeast1"
environment      = "stg"
cloud_run_image  = "asia-northeast1-docker.pkg.dev/hanko-field-stg/api/api:stg"
vpc_connector    = "projects/hanko-field-stg/locations/asia-northeast1/connectors/api-stg"
cloud_run_cpu         = "2"
cloud_run_memory      = "1Gi"
cloud_run_concurrency = 60
min_instances    = 2
max_instances    = 10

cloud_run_secret_mounts = {
  API_PSP_STRIPE_API_KEY = {
    secret_key = "stripe_api_key"
  }
  API_PSP_STRIPE_WEBHOOK_SECRET = {
    secret_key = "stripe_webhook_secret"
  }
  API_PSP_PAYPAL_SECRET = {
    secret_key = "paypal_secret"
  }
  API_AI_AUTH_TOKEN = {
    secret_key = "ai_worker_token"
  }
  API_WEBHOOK_SIGNING_SECRET = {
    secret_key = "webhook_signing"
  }
}

api_oidc_audience = "https://api-stg.internal.hanko-field.app"

scheduler_jobs = {
  cleanup_reservations = {
    schedule             = "*/15 * * * *"
    uri                  = "https://api-stg.internal.hanko-field.app/api/v1/internal/maintenance/cleanup-reservations"
    oidc_service_account = "svc-api-scheduler@hanko-field-stg.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
  stock_safety_notify = {
    schedule             = "0 */2 * * *"
    uri                  = "https://api-stg.internal.hanko-field.app/api/v1/internal/maintenance/stock-safety-notify"
    oidc_service_account = "svc-api-scheduler@hanko-field-stg.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
}

admin_alert_notification_emails = [
  "ops-alerts+stg@hanko-field.com",
]

admin_uptime_check_host = "admin.stg.hanko-field.com"

admin_uptime_endpoints = {
  login = {
    path          = "/admin/login"
    content_match = "Hanko Admin"
  }
  orders = {
    path          = "/admin/uptime/orders"
    content_match = "\"component\":\"orders\""
  }
  notifications = {
    path          = "/admin/uptime/notifications"
    content_match = "\"component\":\"notifications\""
  }
}
