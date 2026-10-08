output "profile_id" { value = azurerm_cdn_frontdoor_profile.this.id }
output "endpoint_id" { value = azurerm_cdn_frontdoor_endpoint.this.id }
output "endpoint_hostname" { value = azurerm_cdn_frontdoor_endpoint.this.host_name }
output "waf_policy_id" { value = azurerm_cdn_frontdoor_firewall_policy.this.id }
