variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "replication_type" {
  type    = string
  default = "LRS"
}
variable "public_network_access_enabled" {
  type    = bool
  default = false
}
variable "allowed_ip_addresses" {
  description = "Public IPv4 addresses or CIDR ranges allowed through the storage firewall."
  type        = set(string)
  default     = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
