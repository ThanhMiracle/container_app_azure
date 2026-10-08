variable "subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "resource_group_name" {
  type        = string
  description = "Existing Resource Group name. This repository never creates the Resource Group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "project_name" {
  type    = string
  default = "myapp"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "app_gateway_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.1.0/24"]
}

variable "container_apps_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.8.0/21"]
}

variable "postgres_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.4.0/24"]
}

variable "private_endpoint_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.5.0/24"]
}

variable "acr_name" {
  type        = string
  description = "Globally unique ACR name, 5-50 alphanumeric characters."
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique Storage Account name."
}

variable "key_vault_name" {
  type        = string
  description = "Globally unique Key Vault name."
}

variable "front_door_endpoint_name" {
  type        = string
  description = "Globally unique Azure Front Door endpoint name."
}

variable "app_gateway_public_dns_label" {
  type        = string
  description = "Unique regional DNS label used by the Application Gateway public IP."
}

variable "github_oidc_subjects" {
  type        = map(string)
  description = "GitHub OIDC subjects keyed by federated credential name."

  validation {
    condition = length(var.github_oidc_subjects) > 0 && alltrue([
      for _, subject in var.github_oidc_subjects :
      can(regex(
        "^repo:[A-Za-z0-9_.-]+(@[0-9]+)?/[A-Za-z0-9_.-]+(@[0-9]+)?:(ref:refs/heads/[^*]+|environment:[^*]+)$",
        subject
      ))
    ])

    error_message = "Each subject must be repo:OWNER/REPO:ref:refs/heads/BRANCH or repo:OWNER/REPO:environment:NAME, optionally with GitHub numeric IDs such as OWNER@123/REPO@456, and without wildcards."
  }
}

variable "github_oidc_issuer" {
  type    = string
  default = "https://token.actions.githubusercontent.com"
}

variable "container_app_placeholder_image" {
  type    = string
  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "frontend_cpu" {
  type    = number
  default = 0.5
}

variable "frontend_memory" {
  type    = string
  default = "1Gi"
}

variable "frontend_container_port" {
  type    = number
  default = 80
}

variable "frontend_min_replicas" {
  type    = number
  default = 1
}

variable "frontend_max_replicas" {
  type    = number
  default = 3
}

variable "backend_cpu" {
  type    = number
  default = 0.5
}

variable "backend_memory" {
  type    = string
  default = "1Gi"
}

variable "backend_container_port" {
  type    = number
  default = 8080
}

variable "backend_min_replicas" {
  type    = number
  default = 1
}

variable "backend_max_replicas" {
  type    = number
  default = 5
}

variable "postgres_administrator_password" {
  type        = string
  description = "PostgreSQL administrator password."
  sensitive   = true
  nullable    = false
}

variable "postgres_server_name" {
  type        = string
  description = "Globally unique PostgreSQL Flexible Server name."
}

variable "postgres_database_name" {
  type    = string
  default = "appdb"
}

variable "postgres_admin_username" {
  type    = string
  default = "pgadminuser"
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_sku_name" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_backup_retention_days" {
  type    = number
  default = 14
}

variable "postgres_geo_redundant_backup_enabled" {
  type    = bool
  default = false
}

variable "key_vault_network_default_action" {
  type        = string
  default     = "Allow"
  description = "Keep Allow while Terraform runs from a workstation and manages Key Vault secrets."

  validation {
    condition     = contains(["Allow", "Deny"], var.key_vault_network_default_action)
    error_message = "Use Allow or Deny."
  }
}

variable "key_vault_allowed_ip_cidrs" {
  type    = list(string)
  default = []
}

variable "deploy_service_bus" {
  type        = bool
  default     = false
  description = "Enable only when the application needs Service Bus. Premium is used to support Private Link."
}

variable "service_bus_namespace_name" {
  type    = string
  default = ""
}

variable "service_bus_queue_name" {
  type    = string
  default = "jobs"
}
