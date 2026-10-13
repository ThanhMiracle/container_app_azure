mock_provider "azurerm" {
  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Insights/actionGroups/test-monitor-ag"
    }
  }
  mock_data "azurerm_monitor_diagnostic_categories" {
    defaults = {
      log_category_types  = ["AuditEvent"]
      log_category_groups = ["allLogs", "audit"]
      metrics             = ["AllMetrics"]
    }
  }
  mock_resource "azurerm_application_insights_standard_web_test" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Insights/webTests/test-availability"
    }
  }
}

variables {
  name_prefix                = "test"
  resource_group_name        = "test-rg"
  resource_group_id          = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg"
  location                   = "japanwest"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law"
  application_insights_id    = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Insights/components/test-appi"
  alert_email_addresses      = ["operator@example.com"]
  availability_urls          = { frontend = "https://example.com/" }
  diagnostic_resources = {
    vault = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.KeyVault/vaults/test-vault"
  }
  metric_alerts = {
    server-errors = {
      resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.App/containerApps/test-app"
      description      = "App server failures"
      metric_namespace = "Microsoft.App/containerapps"
      metric_name      = "Requests"
      aggregation      = "Total"
      operator         = "GreaterThanOrEqual"
      threshold        = 10
      dimensions       = { statusCodeCategory = ["5xx"] }
    }
  }
}

run "notification_routing" {
  command = apply
  assert {
    condition = (
      alltrue([for alert in azurerm_monitor_metric_alert.this : one(alert.action).action_group_id == azurerm_monitor_action_group.this.id]) &&
      alltrue([for alert in azurerm_monitor_metric_alert.availability : one(alert.action).action_group_id == azurerm_monitor_action_group.this.id]) &&
      one(azurerm_monitor_activity_log_alert.resource_health.action).action_group_id == azurerm_monitor_action_group.this.id &&
      one(azurerm_monitor_action_group.this.email_receiver).email_address == "operator@example.com" &&
      one(azurerm_monitor_action_group.this.email_receiver).use_common_alert_schema
    )
    error_message = "Infrastructure and availability alerts must reach the configured email action group."
  }
  assert {
    condition = (
      toset(one(one(azurerm_monitor_metric_alert.this["server-errors"].criteria).dimension).values) == toset(["5xx"]) &&
      one(azurerm_monitor_metric_alert.availability["frontend"].application_insights_web_test_location_availability_criteria).failed_location_count == 3 &&
      length(azurerm_application_insights_standard_web_test.this["frontend"].geo_locations) == 5
    )
    error_message = "Server-error alerts must exclude successful requests, and availability needs failures from three of five locations."
  }
}

run "portal_only_and_disabled_alerts" {
  command = apply
  variables {
    enabled               = false
    alert_email_addresses = []
    availability_urls     = {}
  }
  assert {
    condition = (
      length(azurerm_monitor_action_group.this.email_receiver) == 0 &&
      !azurerm_monitor_action_group.this.enabled &&
      !azurerm_monitor_metric_alert.this["server-errors"].enabled &&
      !azurerm_monitor_activity_log_alert.resource_health.enabled &&
      length(azurerm_application_insights_standard_web_test.this) == 0 &&
      length(azurerm_monitor_metric_alert.availability) == 0 &&
      length(azurerm_monitor_diagnostic_setting.this["vault"].enabled_log) == 1 &&
      length(azurerm_monitor_diagnostic_setting.this["vault"].enabled_metric) == 0
    )
    error_message = "Disabling alerts must preserve diagnostic logs without duplicating metric ingestion or sending email."
  }
}

run "reject_invalid_recipient" {
  command = plan
  variables {
    alert_email_addresses = ["not-an-email"]
  }
  expect_failures = [var.alert_email_addresses]
}

run "reject_non_https_availability" {
  command = plan
  variables {
    availability_urls = { frontend = "http://example.com/" }
  }
  expect_failures = [var.availability_urls]
}
