project_id       = "hanko-field-dev"
region           = "asia-northeast1"
location         = "asia-northeast1"
environment      = "dev"
cloud_run_image  = "asia-northeast1-docker.pkg.dev/hanko-field-dev/api/api:dev"
vpc_connector    = "projects/hanko-field-dev/locations/asia-northeast1/connectors/api-dev"
cloud_run_cpu         = "1"
cloud_run_memory      = "512Mi"
cloud_run_concurrency = 20
min_instances    = 1
max_instances    = 5

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

api_oidc_audience = "https://api-dev.internal.hanko-field.app"

scheduler_jobs = {
  cleanup_reservations = {
    schedule             = "*/30 * * * *"
    uri                  = "https://api-dev.internal.hanko-field.app/api/v1/internal/maintenance/cleanup-reservations"
    oidc_service_account = "svc-api-scheduler@hanko-field-dev.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
  stock_safety_notify = {
    schedule             = "30 6 * * *"
    uri                  = "https://api-dev.internal.hanko-field.app/api/v1/internal/maintenance/stock-safety-notify"
    oidc_service_account = "svc-api-scheduler@hanko-field-dev.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
}

admin_alert_notification_emails = [
  "ops-alerts+dev@hanko-field.com",
]

admin_uptime_check_host = "admin.dev.hanko-field.com"

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
