variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "application_insights_id" { type = string }

variable "alert_email_addresses" {
  type    = set(string)
  default = []
  validation {
    condition     = alltrue([for email in var.alert_email_addresses : can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", email))])
    error_message = "Alert recipients must be valid email addresses."
  }
}

variable "enabled" {
  type    = bool
  default = true
}

variable "diagnostic_resources" {
  description = "Resources whose supported log categories are sent to the existing workspace."
  type        = map(string)
  default     = {}
}

variable "metric_alerts" {
  type = map(object({
    resource_id      = string
    description      = string
    metric_namespace = string
    metric_name      = string
    aggregation      = string
    operator         = string
    threshold        = number
    severity         = optional(number, 2)
    window_size      = optional(string, "PT5M")
    dimensions       = optional(map(list(string)), {})
  }))
  default = {}
}

variable "availability_urls" {
  description = "Public HTTPS endpoints checked by Standard availability tests. An empty map disables tests."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for url in values(var.availability_urls) : can(regex("^https://", url))])
    error_message = "Availability tests require public HTTPS URLs."
  }
}

variable "availability_locations" {
  description = "Azure Application Insights availability location population tags."
  type        = set(string)
  default = [
    "apac-jp-kaw-edge", "apac-sg-sin-azr", "apac-hk-hkn-azr",
    "emea-nl-ams-azr", "us-va-ash-azr"
  ]
  validation {
    condition     = length(var.availability_locations) >= 5 && length(var.availability_locations) <= 16
    error_message = "Use between five and sixteen availability test locations."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
