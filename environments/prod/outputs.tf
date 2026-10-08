output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "subscription_id" {
  value = var.subscription_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "acr_name" {
  value = module.acr.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "github_acr_push_client_id" {
  description = "GitHub OIDC client ID for publishing images to ACR."
  value       = module.github_acr_publisher.client_id
}

output "github_acr_push_identity_name" {
  value = module.github_acr_publisher.name
}

output "github_container_app_deploy_client_id" {
  description = "Separate GitHub OIDC client ID for deploying images to the frontend and backend Container Apps."
  value       = module.github_container_app_deployer.client_id
}

output "github_container_app_deploy_identity_name" {
  value = module.github_container_app_deployer.name
}

output "frontend_container_app_name" {
  value = module.frontend.name
}

output "backend_container_app_name" {
  value = module.backend.name
}

output "frontend_container_app_fqdn" {
  value = module.frontend.fqdn
}

output "backend_container_app_fqdn" {
  value = module.backend.fqdn
}

output "front_door_hostname" {
  value = module.front_door.endpoint_hostname
}

output "application_gateway_origin_fqdn" {
  value = module.application_gateway.public_fqdn
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "database_url_secret_name" {
  value = "database-url"
}

output "postgres_fqdn" {
  value = module.postgresql.fqdn
}

output "postgres_database_name" {
  value = module.postgresql.database_name
}

output "storage_blob_endpoint" {
  value = module.storage.primary_blob_endpoint
}
