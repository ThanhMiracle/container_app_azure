variable "monitor_alert_email_addresses" {
  description = "Email recipients for Azure Monitor alerts. Empty means alerts remain visible in Azure without email."
  type        = set(string)
  default     = []
}

variable "monitor_alerts_enabled" {
  description = "Enable notifications, metric alerts, resource health alerts, and availability tests. Log collection stays enabled."
  type        = bool
  default     = true
}

variable "monitor_availability_tests_enabled" {
  description = "Run billed Standard availability checks through Front Door for frontend and backend health."
  type        = bool
  default     = true
}

variable "monitor_thresholds" {
  description = "Initial alert thresholds; tune them to normal production traffic."
  type = object({
    app_http_5xx_count          = optional(number, 10)
    gateway_failed_requests     = optional(number, 20)
    postgres_cpu_percent        = optional(number, 80)
    postgres_memory_percent     = optional(number, 85)
    postgres_storage_percent    = optional(number, 80)
    front_door_origin_health    = optional(number, 90)
    front_door_http_5xx_percent = optional(number, 5)
  })
  default  = {}
  nullable = false
  validation {
    condition = (
      var.monitor_thresholds.app_http_5xx_count >= 1 &&
      floor(var.monitor_thresholds.app_http_5xx_count) == var.monitor_thresholds.app_http_5xx_count &&
      var.monitor_thresholds.gateway_failed_requests >= 1 &&
      floor(var.monitor_thresholds.gateway_failed_requests) == var.monitor_thresholds.gateway_failed_requests &&
      alltrue([for value in [
        var.monitor_thresholds.postgres_cpu_percent,
        var.monitor_thresholds.postgres_memory_percent,
        var.monitor_thresholds.postgres_storage_percent,
        var.monitor_thresholds.front_door_origin_health,
        var.monitor_thresholds.front_door_http_5xx_percent
      ] : value > 0 && value <= 100])
    )
    error_message = "Request thresholds must be positive integers; percentage thresholds must be greater than zero and at most 100."
  }
}
