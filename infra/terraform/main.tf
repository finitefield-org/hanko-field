locals {
  environment_suffix = var.environment == "prod" ? "" : "-${var.environment}"
  name_prefix        = "hanko-field${local.environment_suffix}"

  bucket_names = {
    for key, value in var.storage_buckets : key => "${local.name_prefix}-${key}"
  }

  secret_ids = {
    for key, _ in var.secret_ids : key => "${local.name_prefix}-${key}"
  }
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
  environment           = var.environment
  env_vars = {
    API_ENVIRONMENT             = var.environment
    API_SECURITY_OIDC_AUDIENCE  = var.api_oidc_audience
  }
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

module "storage" {
  source = "./modules/storage_buckets"

  project_id    = var.project_id
  buckets       = var.storage_buckets
  name_override = local.bucket_names
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

module "secrets" {
  source = "./modules/secret_manager"

  project_id = var.project_id
  secrets    = local.secret_ids
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
