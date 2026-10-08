variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "sku" {
  type = string
  default = "Premium"
}
variable "public_network_access_enabled" {
  type = bool
  default = true
}
variable "zone_redundancy_enabled" {
  type = bool
  default = false
}
variable "tags" {
  type = map(string)
  default = {}
}
