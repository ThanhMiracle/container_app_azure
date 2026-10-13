output "action_group_id" { value = azurerm_monitor_action_group.this.id }
output "metric_alert_ids" { value = { for name, alert in azurerm_monitor_metric_alert.this : name => alert.id } }
output "resource_health_alert_id" { value = azurerm_monitor_activity_log_alert.resource_health.id }
output "availability_test_ids" { value = { for name, test in azurerm_application_insights_standard_web_test.this : name => test.id } }
output "availability_alert_ids" { value = { for name, alert in azurerm_monitor_metric_alert.availability : name => alert.id } }
output "diagnostic_setting_ids" { value = { for name, setting in azurerm_monitor_diagnostic_setting.this : name => setting.id } }
