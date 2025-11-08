project_id       = "hanko-field-dev"
region           = "asia-northeast1"
location         = "asia-northeast1"
environment      = "dev"
cloud_run_image  = "asia-northeast1-docker.pkg.dev/hanko-field-dev/api/api:dev"
vpc_connector    = "projects/hanko-field-dev/locations/asia-northeast1/connectors/api-dev"
min_instances    = 1
max_instances    = 5

scheduler_jobs = {
  cleanup_reservations = {
    schedule             = "*/30 * * * *"
    uri                  = "https://api-dev.internal.hanko-field.app/internal/maintenance/cleanup-reservations"
    oidc_service_account = "svc-api-scheduler@hanko-field-dev.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
  stock_safety_notify = {
    schedule             = "30 6 * * *"
    uri                  = "https://api-dev.internal.hanko-field.app/internal/maintenance/stock-safety-notify"
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
