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
    API_ENVIRONMENT              = var.environment
    API_FIREBASE_PROJECT_ID      = var.project_id
    API_FIRESTORE_PROJECT_ID     = var.project_id
    API_SECURITY_ENVIRONMENT     = var.environment
    API_SECRET_DEFAULT_PROJECT_ID = var.project_id
    API_STORAGE_ASSETS_BUCKET    = module.storage.bucket_names["design_assets"]
    API_STORAGE_EXPORTS_BUCKET   = module.storage.bucket_names["exports"]
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
  jobs         = var.scheduler_jobs
  service_account_email = module.service_accounts.service_account_emails["scheduler_invoker"]
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
