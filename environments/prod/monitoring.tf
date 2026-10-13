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

locals {
  monitored_container_apps = {
    frontend = { id = module.frontend.id, min_replicas = var.frontend_min_replicas }
    backend  = { id = module.backend.id, min_replicas = var.backend_min_replicas }
  }

  monitor_metric_alerts = merge(
    {
      for name, app in local.monitored_container_apps : "${name}-low-replicas" => {
        resource_id      = app.id
        description      = "${name} stays below its configured HA minimum replica count during the five-minute window."
        metric_namespace = "Microsoft.App/containerapps"
        metric_name      = "Replicas"
        aggregation      = "Maximum"
        operator         = "LessThan"
        threshold        = app.min_replicas
        severity         = 1
      }
    },
    {
      for name, app in local.monitored_container_apps : "${name}-http-5xx" => {
        resource_id      = app.id
        description      = "${name} returns at least ${var.monitor_thresholds.app_http_5xx_count} HTTP 5xx responses in five minutes."
        metric_namespace = "Microsoft.App/containerapps"
        metric_name      = "Requests"
        aggregation      = "Total"
        operator         = "GreaterThanOrEqual"
        threshold        = var.monitor_thresholds.app_http_5xx_count
        severity         = 2
        dimensions       = { statusCodeCategory = ["5xx"] }
      }
    },
    {
      gateway-unhealthy-backends = {
        resource_id      = module.application_gateway.id
        description      = "Application Gateway has unhealthy backend hosts over a five-minute window."
        metric_namespace = "Microsoft.Network/applicationGateways"
        metric_name      = "UnhealthyHostCount"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = 0
        severity         = 1
      }
      gateway-failed-requests = {
        resource_id      = module.application_gateway.id
        description      = "Application Gateway fails at least ${var.monitor_thresholds.gateway_failed_requests} requests in five minutes."
        metric_namespace = "Microsoft.Network/applicationGateways"
        metric_name      = "FailedRequests"
        aggregation      = "Total"
        operator         = "GreaterThanOrEqual"
        threshold        = var.monitor_thresholds.gateway_failed_requests
      }
      postgres-high-cpu = {
        resource_id      = module.postgresql.id
        description      = "PostgreSQL average CPU exceeds ${var.monitor_thresholds.postgres_cpu_percent}% over fifteen minutes."
        metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
        metric_name      = "cpu_percent"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = var.monitor_thresholds.postgres_cpu_percent
        window_size      = "PT15M"
      }
      postgres-high-memory = {
        resource_id      = module.postgresql.id
        description      = "PostgreSQL average memory exceeds ${var.monitor_thresholds.postgres_memory_percent}% over fifteen minutes."
        metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
        metric_name      = "memory_percent"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = var.monitor_thresholds.postgres_memory_percent
        window_size      = "PT15M"
      }
      postgres-high-storage = {
        resource_id      = module.postgresql.id
        description      = "PostgreSQL used storage exceeds ${var.monitor_thresholds.postgres_storage_percent}% over five minutes."
        metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
        metric_name      = "storage_percent"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = var.monitor_thresholds.postgres_storage_percent
        severity         = 1
      }
      front-door-unhealthy-origin = {
        resource_id      = module.front_door.profile_id
        description      = "Front Door successful origin probes fall below ${var.monitor_thresholds.front_door_origin_health}% over five minutes."
        metric_namespace = "Microsoft.Cdn/profiles"
        metric_name      = "OriginHealthPercentage"
        aggregation      = "Average"
        operator         = "LessThan"
        threshold        = var.monitor_thresholds.front_door_origin_health
        severity         = 1
      }
      front-door-http-5xx = {
        resource_id      = module.front_door.profile_id
        description      = "Front Door HTTP 5xx percentage exceeds ${var.monitor_thresholds.front_door_http_5xx_percent}% over five minutes."
        metric_namespace = "Microsoft.Cdn/profiles"
        metric_name      = "Percentage5XX"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = var.monitor_thresholds.front_door_http_5xx_percent
      }
    }
  )
}

module "azure_monitor" {
  source = "../../modules/azure-monitor"

  name_prefix                = local.prefix
  resource_group_name        = data.azurerm_resource_group.this.name
  resource_group_id          = data.azurerm_resource_group.this.id
  location                   = var.location
  log_analytics_workspace_id = module.log_analytics.id
  application_insights_id    = module.application_insights.id
  alert_email_addresses      = var.monitor_alert_email_addresses
  enabled                    = var.monitor_alerts_enabled
  metric_alerts              = local.monitor_metric_alerts
  tags                       = local.tags

  # Container Apps logs already go directly to this workspace through the
  # environment. Application Insights also uses it; do not duplicate those logs.
  diagnostic_resources = merge({
    application-gateway = module.application_gateway.id
    front-door          = module.front_door.profile_id
    postgresql          = module.postgresql.id
    key-vault           = module.key_vault.id
    blob-storage        = "${module.storage.id}/blobServices/default"
    container-registry  = module.acr.id
  }, var.deploy_service_bus ? { service-bus = module.service_bus[0].id } : {})

  availability_urls = var.monitor_availability_tests_enabled ? {
    frontend = "${local.frontend_public_url}/"
    backend  = "${local.frontend_public_url}/api/health"
  } : {}
}


