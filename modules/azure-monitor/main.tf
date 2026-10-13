resource "azurerm_monitor_action_group" "this" {
  name                = "${var.name_prefix}-monitor-ag"
  resource_group_name = var.resource_group_name
  short_name          = substr("${var.name_prefix}-mon", 0, 12)
  location            = "global"
  enabled             = var.enabled
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = { for index, email in sort(tolist(var.alert_email_addresses)) : "email-${index}" => email }
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "this" {
  for_each    = var.diagnostic_resources
  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each                   = var.diagnostic_resources
  name                       = "${var.name_prefix}-${each.key}-logs"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id
  # Use the compatible AzureDiagnostics table across these resource types.
  log_analytics_destination_type = "AzureDiagnostics"

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.this[each.key].log_category_types
    content {
      category = enabled_log.value
    }
  }

  lifecycle {
    precondition {
      condition     = length(data.azurerm_monitor_diagnostic_categories.this[each.key].log_category_types) > 0
      error_message = "The diagnostic target must support at least one log category."
    }
  }
}

resource "azurerm_monitor_metric_alert" "this" {
  for_each            = var.metric_alerts
  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value.resource_id]
  description         = each.value.description
  severity            = each.value.severity
  enabled             = var.enabled
  auto_mitigate       = true
  frequency           = "PT1M"
  window_size         = each.value.window_size
  tags                = var.tags

  criteria {
    metric_namespace = each.value.metric_namespace
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold

    dynamic "dimension" {
      for_each = each.value.dimensions
      content {
        name     = dimension.key
        operator = "Include"
        values   = dimension.value
      }
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_monitor_activity_log_alert" "resource_health" {
  name                = "${var.name_prefix}-resource-health"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [var.resource_group_id]
  description         = "Azure reports a resource in this resource group as degraded or unavailable."
  enabled             = var.enabled
  tags                = var.tags

  criteria {
    category = "ResourceHealth"
    resource_health {
      current = ["Degraded", "Unavailable"]
    }
  }
  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_application_insights_standard_web_test" "this" {
  for_each                = var.availability_urls
  name                    = "${var.name_prefix}-${each.key}-availability"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = var.application_insights_id
  geo_locations           = var.availability_locations
  description             = "Check ${each.key} through the public HTTPS entry point every five minutes."
  enabled                 = var.enabled
  frequency               = 300
  timeout                 = 30
  retry_enabled           = true
  tags                    = var.tags

  request {
    url                              = each.value
    http_verb                        = "GET"
    follow_redirects_enabled         = true
    parse_dependent_requests_enabled = false
  }
  validation_rules {
    expected_status_code = 200
    ssl_check_enabled    = true
  }
}

resource "azurerm_monitor_metric_alert" "availability" {
  for_each            = var.availability_urls
  name                = "${var.name_prefix}-${each.key}-unavailable"
  resource_group_name = var.resource_group_name
  scopes = [
    azurerm_application_insights_standard_web_test.this[each.key].id,
    var.application_insights_id
  ]
  description              = "${each.key} fails availability checks in at least three locations."
  target_resource_type     = "Microsoft.Insights/components"
  target_resource_location = var.location
  severity                 = 1
  enabled                  = var.enabled
  auto_mitigate            = true
  frequency                = "PT1M"
  window_size              = "PT5M"
  tags                     = var.tags

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.this[each.key].id
    component_id          = var.application_insights_id
    failed_location_count = 3
  }
  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
