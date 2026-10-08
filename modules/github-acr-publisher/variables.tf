variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "acr_id" { type = string }
variable "issuer" {
  type = string
  default = "https://token.actions.githubusercontent.com"
}
variable "subjects" { type = map(string) }
variable "tags" {
  type = map(string)
  default = {}
}
