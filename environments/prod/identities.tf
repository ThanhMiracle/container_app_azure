module "frontend_identity" {
  source = "../../modules/managed-identity"

  name                = "${local.prefix}-fe-mi"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

module "backend_identity" {
  source = "../../modules/managed-identity"

  name                = "${local.prefix}-be-mi"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

module "github_acr_publisher" {
  source = "../../modules/github-acr-publisher"

  name                = "${local.prefix}-github-acr-mi"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  acr_id              = module.acr.id
  issuer              = var.github_oidc_issuer
  subjects            = var.github_oidc_subjects
  tags                = local.tags
}

resource "azurerm_role_assignment" "frontend_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.frontend_identity.principal_id
}

resource "azurerm_role_assignment" "backend_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.backend_identity.principal_id
}

resource "azurerm_role_assignment" "backend_storage_blob" {
  scope                = module.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.backend_identity.principal_id
}

resource "azurerm_role_assignment" "backend_service_bus" {
  count = var.deploy_service_bus ? 1 : 0

  scope                = module.service_bus[0].id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = module.backend_identity.principal_id
}
