variable "name" { type = string }
variable "container_name" { type = string }
variable "resource_group_name" { type = string }
variable "environment_id" { type = string }
variable "identity_id" { type = string }
variable "registry_identity_id" { type = string }
variable "registry_server" {
  type = string
  default = null
  nullable = true
}
variable "image" { type = string }
variable "cpu" { type = number }
variable "memory" { type = string }
variable "container_port" { type = number }
variable "min_replicas" {
  type = number
  default = 1
}
variable "max_replicas" {
  type = number
  default = 3
}
variable "external_enabled" {
  type = bool
  default = true
}
variable "environment_variables" {
  type = map(string)
  default = {}
}
variable "secret_environment_variables" {
  type = map(string)
  default = {}
}
variable "key_vault_secrets" {
  type = map(object({
    key_vault_secret_id = string
    identity            = string
  }))
  default = {}
}
variable "tags" {
  type = map(string)
  default = {}
}
