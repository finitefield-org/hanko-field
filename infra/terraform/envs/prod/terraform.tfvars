project_id       = "hanko-field-prod"
region           = "asia-northeast1"
location         = "asia-northeast1"
environment      = "prod"
cloud_run_image  = "asia-northeast1-docker.pkg.dev/hanko-field-prod/api/api:prod"
vpc_connector    = "projects/hanko-field-prod/locations/asia-northeast1/connectors/api-prod"
min_instances    = 3
max_instances    = 30

scheduler_jobs = {
  cleanup_reservations = {
    schedule             = "*/10 * * * *"
    uri                  = "https://api.internal.hanko-field.app/internal/maintenance/cleanup-reservations"
    oidc_service_account = "svc-api-scheduler@hanko-field-prod.iam.gserviceaccount.com"
    time_zone            = "Asia/Tokyo"
  }
  stock_safety_notify = {
    schedule             = "0 * * * *"
    uri                  = "https://api.internal.hanko-field.app/internal/maintenance/stock-safety-notify"
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
