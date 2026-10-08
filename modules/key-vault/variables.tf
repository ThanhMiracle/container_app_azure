variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "bootstrap_principal_object_id" {
  type = string
  default = null
  nullable = true
}
variable "secrets" {
  type = map(string)
  default = {}
  sensitive = true
}
variable "soft_delete_retention_days" {
  type = number
  default = 7
}
variable "purge_protection_enabled" {
  type = bool
  default = false
}
variable "public_network_access_enabled" {
  type = bool
  default = true
}
variable "network_default_action" {
  type = string
  default = "Allow"
}
variable "allowed_ip_cidrs" {
  type = list(string)
  default = []
}
variable "tags" {
  type = map(string)
  default = {}
}
