module "log_analytics" {
  source = "../../modules/log-analytics"

  name                = "${local.prefix}-law"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  retention_in_days   = 30
  tags                = local.tags
}

module "application_insights" {
  source = "../../modules/application-insights"

  name                = "${local.prefix}-appi"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  workspace_id        = module.log_analytics.id
  tags                = local.tags
}
