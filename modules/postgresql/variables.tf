variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "administrator_login" { type = string }
variable "database_name" { type = string }
variable "postgres_version" {
  type = string
  default = "16"
}
variable "sku_name" {
  type = string
  default = "GP_Standard_D2s_v3"
}
variable "storage_mb" {
  type = number
  default = 32768
}
variable "backup_retention_days" {
  type = number
  default = 14
}
variable "geo_redundant_backup_enabled" {
  type = bool
  default = false
}
variable "high_availability_mode" {
  type = string
  default = null
  nullable = true
}
variable "tags" {
  type = map(string)
  default = {}
}

variable "administrator_password" {
  type        = string
  description = "PostgreSQL administrator password."
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.administrator_password) >= 12
    error_message = "PostgreSQL administrator password must be at least 12 characters long."
  }
}
