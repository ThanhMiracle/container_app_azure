variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "virtual_network_name" { type = string }
variable "address_prefixes" { type = list(string) }
variable "service_endpoints" {
  type = list(string)
  default = []
}
variable "private_endpoint_network_policies" {
  type    = string
  default = "Enabled"
}
variable "delegation" {
  type = object({
    name         = string
    service_name = string
    actions      = list(string)
  })
  default = null
}
