variable "name" { type = string }
variable "public_ip_name" { type = string }
variable "public_dns_label" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "subnet_id" { type = string }
variable "frontend_backend_fqdn" { type = string }
variable "backend_backend_fqdn" { type = string }
variable "frontend_probe_path" {
  type = string
  default = "/"
}
variable "backend_probe_path" {
  type = string
  default = "/"
}
variable "min_capacity" {
  type = number
  default = 1
}
variable "max_capacity" {
  type = number
  default = 3
}
variable "tags" {
  type = map(string)
  default = {}
}
