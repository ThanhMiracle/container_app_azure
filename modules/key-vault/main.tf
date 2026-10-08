locals {
  # Secret names are safe to expose as Terraform resource instance keys.
  # Secret values remain sensitive.
  secret_names = toset(nonsensitive(keys(var.secrets)))
}

resource "azurerm_key_vault" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true

  soft_delete_retention_days    = var.soft_delete_retention_days
  purge_protection_enabled      = var.purge_protection_enabled
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    bypass         = "AzureServices"
    default_action = var.network_default_action
    ip_rules       = var.allowed_ip_cidrs
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "bootstrap_secrets_officer" {
  count = var.bootstrap_principal_object_id == null ? 0 : 1

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.bootstrap_principal_object_id
}

resource "time_sleep" "wait_for_rbac" {
  count = (
    var.bootstrap_principal_object_id == null ||
    length(local.secret_names) == 0
  ) ? 0 : 1

  create_duration = "30s"

  depends_on = [
    azurerm_role_assignment.bootstrap_secrets_officer
  ]
}

resource "azurerm_key_vault_secret" "this" {
  for_each = local.secret_names

  name         = each.key
  value        = var.secrets[each.key]
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    time_sleep.wait_for_rbac
  ]
}