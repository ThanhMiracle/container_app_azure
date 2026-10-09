module "key_vault" {
  source = "../../modules/key-vault"

  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  bootstrap_principal_object_id = data.azurerm_client_config.current.object_id

  public_network_access_enabled = true
  network_default_action        = var.key_vault_network_default_action
  allowed_ip_cidrs              = var.key_vault_allowed_ip_cidrs
  purge_protection_enabled      = false

  secrets = {
    database-url  = local.database_url
    jwt-secret    = var.jwt_secret
    smtp-password = var.smtp_password
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "backend_key_vault_secrets_user" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.backend_identity.principal_id
}

resource "time_sleep" "runtime_rbac" {
  create_duration = "30s"

  depends_on = [
    azurerm_role_assignment.frontend_acr_pull,
    azurerm_role_assignment.backend_acr_pull,
    azurerm_role_assignment.backend_storage_blob,
    azurerm_role_assignment.backend_key_vault_secrets_user,
    azurerm_role_assignment.backend_service_bus,
    module.github_acr_publisher
  ]
}
