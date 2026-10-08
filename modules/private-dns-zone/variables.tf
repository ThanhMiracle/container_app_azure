variable "zone_name" { type = string }
variable "resource_group_name" { type = string }
variable "virtual_network_id" { type = string }
variable "vnet_link_name" { type = string }
variable "a_records" {
  type = map(list(string))
  default = {}
}
variable "a_record_ttl" {
  type = number
  default = 60
}
variable "tags" {
  type = map(string)
  default = {}
}
