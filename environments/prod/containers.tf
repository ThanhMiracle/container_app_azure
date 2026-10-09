module "container_apps_environment" {
  source = "../../modules/container-app-environment"

  name                           = "${local.prefix}-cae"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  infrastructure_subnet_id       = module.container_apps_subnet.id
  internal_load_balancer_enabled = true
  log_analytics_workspace_id     = module.log_analytics.id
  zone_redundancy_enabled        = false
  tags                           = local.tags
}

module "container_apps_private_dns" {
  source = "../../modules/private-dns-zone"

  zone_name           = module.container_apps_environment.default_domain
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-aca-dns-link"

  a_records = {
    "*" = [module.container_apps_environment.static_ip_address]
  }

  tags = local.tags
}


module "frontend" {
  source = "../../modules/container-app"

  name                = "${local.prefix}-fe"
  container_name      = "frontend"
  resource_group_name = data.azurerm_resource_group.this.name
  environment_id      = module.container_apps_environment.id

  identity_id          = module.frontend_identity.id
  registry_identity_id = module.frontend_identity.id
  registry_server      = module.acr.login_server

  image  = var.container_app_placeholder_image
  cpu    = var.frontend_cpu
  memory = var.frontend_memory

  container_port = var.frontend_container_port
  min_replicas   = var.frontend_min_replicas
  max_replicas   = var.frontend_max_replicas

  # Environment variables from terraform.tfvars
  # Azure-generated variables remain managed by Terraform.
  environment_variables = merge(
    var.frontend_environment_variables,
    {
      APPLICATIONINSIGHTS_CONNECTION_STRING = module.application_insights.connection_string
    }
  )

  tags = local.tags

  depends_on = [
    time_sleep.runtime_rbac,
    module.container_apps_private_dns,
    module.acr_private_endpoint
  ]
}




module "backend" {
  source = "../../modules/container-app"

  name                = "${local.prefix}-be"
  container_name      = "backend"
  resource_group_name = data.azurerm_resource_group.this.name
  environment_id      = module.container_apps_environment.id

  identity_id          = module.backend_identity.id
  registry_identity_id = module.backend_identity.id
  registry_server      = module.acr.login_server

  image  = var.container_app_placeholder_image
  cpu    = var.backend_cpu
  memory = var.backend_memory

  container_port = var.backend_container_port
  min_replicas   = var.backend_min_replicas
  max_replicas   = var.backend_max_replicas

  # ==========================================================
  # Regular environment variables
  # ==========================================================

  environment_variables = merge(
    var.backend_environment_variables,
    {
      APPLICATIONINSIGHTS_CONNECTION_STRING = module.application_insights.connection_string

      STORAGE_BLOB_ENDPOINT     = module.storage.primary_blob_endpoint
      AZURE_STORAGE_ACCOUNT_URL = module.storage.primary_blob_endpoint
      AZURE_CLIENT_ID           = module.backend_identity.client_id

      # Automatically retrieved from Azure Front Door
      CORS_ORIGINS       = local.frontend_public_url
      FRONTEND_BASE_URL = local.frontend_public_url
    }
  )

  # ==========================================================
  # Azure Key Vault secrets
  # Use versionless URLs to avoid apply-time version changes
  # ==========================================================

  key_vault_secrets = {
    database-url = {
      key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/database-url"
      identity            = module.backend_identity.id
    }

    jwt-secret = {
      key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/jwt-secret"
      identity            = module.backend_identity.id
    }

    smtp-password = {
      key_vault_secret_id = "https://${var.key_vault_name}.vault.azure.net/secrets/smtp-password"
      identity            = module.backend_identity.id
    }
  }

  # ==========================================================
  # Map Key Vault secrets to container environment variables
  # ==========================================================

  secret_environment_variables = {
    DATABASE_URL  = "database-url"
    JWT_SECRET    = "jwt-secret"
    SMTP_PASSWORD = "smtp-password"
  }

  tags = local.tags

  depends_on = [
    module.key_vault,
    time_sleep.runtime_rbac,
    module.container_apps_private_dns,
    module.acr_private_endpoint,
    module.key_vault_private_endpoint,
    module.storage_blob_private_endpoint
  ]
}


