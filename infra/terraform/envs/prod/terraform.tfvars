project_id       = "hanko-field-prod"
region           = "asia-northeast1"
location         = "asia-northeast1"
environment      = "prod"
cloud_run_image  = "asia-northeast1-docker.pkg.dev/hanko-field-prod/api/api:prod"
vpc_connector    = "projects/hanko-field-prod/locations/asia-northeast1/connectors/api-prod"
cloud_run_cpu         = "4"
cloud_run_memory      = "2Gi"
cloud_run_concurrency = 80
min_instances    = 3
max_instances    = 30

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

api_oidc_audience = "https://api.internal.hanko-field.app"

scheduler_jobs = {
  cleanup_reservations = {
    schedule             = "*/10 * * * *"
    uri                  = "https://api.internal.hanko-field.app/api/v1/internal/maintenance/cleanup-reservations"
    oidc_service_account = "svc-api-scheduler@hanko-field-prod.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
  stock_safety_notify = {
    schedule             = "0 * * * *"
    uri                  = "https://api.internal.hanko-field.app/api/v1/internal/maintenance/stock-safety-notify"
    oidc_service_account = "svc-api-scheduler@hanko-field-prod.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
}

admin_alert_notification_emails = [
  "ops-alerts@hanko-field.com",
  "engineering-oncall@hanko-field.com",
]

admin_uptime_check_host = "admin.hanko-field.com"

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
