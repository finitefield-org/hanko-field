locals {
  environment_suffix = var.environment == "prod" ? "" : "-${var.environment}"
  name_prefix        = "hanko-field${local.environment_suffix}"

  bucket_names = {
    for key, value in var.storage_buckets : key => "${local.name_prefix}-${key}"
  }

  secret_ids = {
    for key, _ in var.secret_ids : key => "${local.name_prefix}-${key}"
  }

  admin_uptime_enabled = var.admin_uptime_check_host != "" && length(var.admin_uptime_endpoints) > 0
}

data "google_project" "current" {
  project_id = var.project_id
}

module "service_accounts" {
  source = "./modules/service_accounts"

  project_id       = var.project_id
  service_accounts = var.service_accounts
  name_prefix      = local.name_prefix
}

module "storage" {
  source = "./modules/storage_buckets"

  project_id    = var.project_id
  buckets       = var.storage_buckets
  name_override = local.bucket_names
}

module "secrets" {
  source = "./modules/secret_manager"

  project_id = var.project_id
  secrets    = local.secret_ids
}

locals {
  cloud_run_env_defaults = {
    API_ENVIRONMENT               = var.environment
    API_FIREBASE_PROJECT_ID       = var.project_id
    API_FIRESTORE_PROJECT_ID      = var.project_id
    API_SECURITY_ENVIRONMENT      = var.environment
    API_SECURITY_OIDC_AUDIENCE    = var.api_oidc_audience
    API_SECRET_DEFAULT_PROJECT_ID = var.project_id
    API_STORAGE_ASSETS_BUCKET     = module.storage.bucket_names["design_assets"]
    API_STORAGE_EXPORTS_BUCKET    = module.storage.bucket_names["exports"]
  }

  cloud_run_secret_bindings = {
    for env_name, config in var.cloud_run_secret_mounts : env_name => {
      env     = env_name
      secret  = module.secrets.secret_ids[config.secret_key]
      version = try(config.version, "latest")
    }
  }
}

module "cloud_run" {
  source = "./modules/cloud_run_service"

  project_id            = var.project_id
  region                = var.region
  service_name          = "api-service"
  image                 = var.cloud_run_image
  service_account_email = module.service_accounts.service_account_emails["api_runtime"]
  ingress               = var.ingress
  min_instances         = var.min_instances
  max_instances         = var.max_instances
  vpc_connector         = var.vpc_connector
  cpu                   = var.cloud_run_cpu
  memory                = var.cloud_run_memory
  concurrency           = var.cloud_run_concurrency
  env_vars              = merge(local.cloud_run_env_defaults, var.cloud_run_env_vars)
  secrets               = local.cloud_run_secret_bindings
  environment           = var.environment
  invokers = [
    module.service_accounts.service_account_emails["scheduler_invoker"],
  ]
}

locals {
  scheduler_job_defaults = {
    cleanup_reservations = {
      schedule             = "*/15 * * * *"
      http_method          = "POST"
      uri                  = "${module.cloud_run.service_url}/api/v1/internal/maintenance/cleanup-reservations"
      time_zone            = "Asia/Tokyo"
      oidc_service_account = module.service_accounts.service_account_emails["scheduler_invoker"]
      audience             = var.api_oidc_audience
    }
    stock_safety_notify = {
      schedule             = "0 * * * *"
      http_method          = "POST"
      uri                  = "${module.cloud_run.service_url}/api/v1/internal/maintenance/stock-safety-notify"
      time_zone            = "Asia/Tokyo"
      oidc_service_account = module.service_accounts.service_account_emails["scheduler_invoker"]
      audience             = var.api_oidc_audience
    }
  }

  scheduler_jobs = merge(
    local.scheduler_job_defaults,
    {
      for name, override in var.scheduler_jobs :
      name => merge(
        lookup(local.scheduler_job_defaults, name, {}),
        override,
      )
    },
  )
}

module "firestore" {
  source = "./modules/firestore"

  project_id = var.project_id
  location   = var.location
}

module "pubsub" {
  source = "./modules/pubsub"

  project_id = var.project_id
  topics     = var.psp_topics
}

module "scheduler" {
  source = "./modules/cloud_scheduler"

  project_id   = var.project_id
  location     = var.region
  jobs         = local.scheduler_jobs
  service_account_email = module.service_accounts.service_account_emails["scheduler_invoker"]
  default_audience      = var.api_oidc_audience
}

resource "google_service_account_iam_member" "scheduler_token_creator" {
  service_account_id = module.service_accounts.service_account_ids["scheduler_invoker"]
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
}

resource "google_monitoring_notification_channel" "admin_alerts" {
  for_each = toset(var.admin_alert_notification_emails)

  display_name = "Admin ${var.environment} ${each.value}"
  type         = "email"

  labels = {
    email_address = each.value
  }

  user_labels = {
    environment = var.environment
    component   = "admin"
  }
}

resource "google_monitoring_uptime_check_config" "admin" {
  for_each = local.admin_uptime_enabled ? var.admin_uptime_endpoints : {}

  display_name    = "admin-${var.environment}-${each.key}"
  timeout         = "10s"
  period          = "60s"
  selected_regions = var.admin_uptime_regions

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.admin_uptime_check_host
    }
  }

  http_check {
    path          = each.value.path
    port          = 443
    use_ssl       = true
    validate_ssl  = true
    request_method = "GET"
  }

  content_matchers {
    matcher = "MATCHES_REGEX"
    content = each.value.content_match
  }

  user_labels = {
    environment = var.environment
    component   = "admin"
    endpoint    = each.key
  }
}

resource "google_monitoring_alert_policy" "admin_uptime" {
  for_each = google_monitoring_uptime_check_config.admin

  display_name = "Admin ${var.environment} ${each.value.display_name} availability"
  combiner     = "OR"

  notification_channels = [for _, channel in google_monitoring_notification_channel.admin_alerts : channel.name]

  documentation {
    content  = "${each.value.display_name} is failing in ${var.environment}."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Uptime failure ${each.value.display_name}"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.\"check_id\"=\"${each.value.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  user_labels = {
    environment = var.environment
    component   = "admin"
    endpoint    = each.key
  }
}
output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = module.cloud_run.service_name
}

output "cloud_run_service_url" {
  description = "Default URL for the Cloud Run service"
  value       = module.cloud_run.service_url
}

output "service_account_emails" {
  description = "Map of provisioned service account emails"
  value       = module.service_accounts.service_account_emails
}

output "storage_bucket_names" {
  description = "Map of logical bucket keys to full bucket names"
  value       = module.storage.bucket_names
}

output "pubsub_topics" {
  description = "Map of topic IDs"
  value       = module.pubsub.topic_ids
}

output "secret_ids" {
  description = "Map of logical secret keys to Secret Manager IDs"
  value       = module.secrets.secret_ids
}
