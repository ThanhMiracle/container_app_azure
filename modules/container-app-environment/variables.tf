variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "infrastructure_subnet_id" { type = string }
variable "internal_load_balancer_enabled" {
  type = bool
  default = true
}
variable "log_analytics_workspace_id" { type = string }
variable "zone_redundancy_enabled" {
  type = bool
  default = false
}
variable "tags" {
  type = map(string)
  default = {}
}
