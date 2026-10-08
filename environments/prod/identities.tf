
# ==============================================================================
# Container App Managed Identities
# ==============================================================================

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

# ==============================================================================
# GitHub ACR Publisher Identity
# ==============================================================================

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

# ==============================================================================
# GitHub Container Apps Deployment Identity
# ==============================================================================

module "github_container_app_deployer" {
  source = "../../modules/managed-identity"

  name                = "${local.prefix}-github-deploy-mi"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_container_app_deploy" {
  for_each = var.github_deploy_oidc_subjects

  name                      = each.key
  user_assigned_identity_id = module.github_container_app_deployer.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.github_oidc_issuer
  subject                   = each.value
}

# ==============================================================================
# GitHub Deployment RBAC Permissions
# ==============================================================================

# Deploy frontend Container App
resource "azurerm_role_assignment" "github_frontend_deploy" {
  scope                = module.frontend.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = module.github_container_app_deployer.principal_id
}

# Deploy backend Container App
resource "azurerm_role_assignment" "github_backend_deploy" {
  scope                = module.backend.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = module.github_container_app_deployer.principal_id
}

# NEW: Allow GitHub Actions to read the Container Apps Environment
# Required for: az containerapp env show
resource "azurerm_role_assignment" "github_container_apps_environment_reader" {
  scope                = module.container_apps_environment.id
  role_definition_name = "Reader"
  principal_id         = module.github_container_app_deployer.principal_id
}

# ==============================================================================
# Container App Runtime RBAC Permissions
# ==============================================================================

# Frontend pulls images from ACR
resource "azurerm_role_assignment" "frontend_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.frontend_identity.principal_id
}

# Backend pulls images from ACR
resource "azurerm_role_assignment" "backend_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.backend_identity.principal_id
}

# Backend accesses Blob Storage
resource "azurerm_role_assignment" "backend_storage_blob" {
  scope                = module.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.backend_identity.principal_id
}

# Backend accesses Service Bus
resource "azurerm_role_assignment" "backend_service_bus" {
  count = var.deploy_service_bus ? 1 : 0

  scope                = module.service_bus[0].id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = module.backend_identity.principal_id
}
