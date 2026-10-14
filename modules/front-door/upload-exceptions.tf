# AzureRM 4.81 does not expose URI-scoped managed-rule exceptions.
# AzAPI updates only the exception list on the existing policy, preserving
# Prevention mode, body inspection, managed rules, and the policy resource ID.
resource "azapi_update_resource" "multipart_upload_exceptions" {
  type        = "Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-11-01"
  resource_id = azurerm_cdn_frontdoor_firewall_policy.this.id

  body = {
    properties = {
      managedRules = {
        exceptionsList = {
          exceptions = length(var.multipart_upload_uri_prefixes) == 0 ? [] : [{
            matchVariable      = "RequestUri"
            valueMatchOperator = "StartsWith"
            matchValues        = sort(tolist(var.multipart_upload_uri_prefixes))
            scopes = [{
              ruleSetType     = "Microsoft_DefaultRuleSet"
              ruleSetVersion  = "2.1"
              ruleGroupScopes = [{
                ruleGroupName = "General"
                ruleScopes = [
                  { ruleId = "200002" },
                  { ruleId = "200003" },
                ]
              }]
            }]
          }]
        }
      }
    }
  }

  lifecycle {
    # AzureRM may rewrite the policy without its newer exception properties.
    # Reapply the exception after any AzureRM policy update in the same apply.
    # Replacing this update resource does not delete the underlying WAF policy.
    replace_triggered_by = [azurerm_cdn_frontdoor_firewall_policy.this]
  }

  # Keep this resource when revoking access: applying [] clears the exception;
  # deleting an azapi_update_resource leaves its Azure properties unchanged.
}
