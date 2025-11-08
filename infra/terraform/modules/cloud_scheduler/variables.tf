variable "project_id" {
  type        = string
  description = "Project ID"
}

variable "location" {
  type        = string
  description = "Region for scheduler"
}

variable "service_account_email" {
  type        = string
  description = "Service account used for OIDC invocation"
}

variable "default_audience" {
  type        = string
  description = "Default OIDC audience applied when a job does not specify one"
  default     = null
}

variable "jobs" {
  description = "Scheduler jobs keyed by name"
  type = map(object({
    schedule             = optional(string)
    http_method          = optional(string, "POST")
    uri                  = optional(string)
    body                 = optional(string)
    time_zone            = optional(string, "UTC")
    oidc_service_account = optional(string)
    audience             = optional(string)
  }))
}
