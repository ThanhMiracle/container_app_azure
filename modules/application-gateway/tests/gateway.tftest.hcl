mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Network/publicIPAddresses/test-appgw-pip"
    }
  }
  mock_resource "azurerm_web_application_firewall_policy" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies/test-appgw-waf"
    }
  }
}

variables {
  name                = "test-appgw"
  public_ip_name      = "test-appgw-pip"
  public_dns_label    = "test-appgw"
  resource_group_name = "test-rg"
  location            = "japanwest"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/gateway"

  config = {
    backends = {
      frontend = { fqdns = ["frontend.example.com"] }
      backend  = { fqdns = ["backend.example.com"], probe = { path = "/health" } }
    }
    default_backend = "frontend"
    routes = [{
      name             = "backend-api"
      paths            = ["/api", "/api/*"]
      backend          = "backend"
      rewrite_rule_set = "backend-api-prefix"
    }]
    rewrite_rule_sets = {
      backend-api-prefix = [{
        name          = "remove-api-prefix"
        rule_sequence = 100
        conditions    = [{ variable = "var_uri_path", pattern = "^/api/(.*)$" }]
        path          = "/{var_uri_path_1}"
      }]
    }
  }
}

run "existing_application" {
  command = apply

  assert {
    condition = (
      length(azurerm_application_gateway.this.backend_address_pool) == 2 &&
      one(azurerm_application_gateway.this.request_routing_rule).rule_type == "PathBasedRouting" &&
      one(azurerm_application_gateway.this.url_path_map).default_backend_address_pool_name == "frontend" &&
      one(one(azurerm_application_gateway.this.url_path_map).path_rule).backend_address_pool_name == "backend"
    )
    error_message = "The existing frontend fallback and API backend routing must remain intact."
  }

  assert {
    condition = (
      one([for probe in azurerm_application_gateway.this.probe : probe if probe.name == "backend"]).path == "/health" &&
      alltrue([for settings in azurerm_application_gateway.this.backend_http_settings :
        settings.protocol == "Https" && settings.port == 443 && settings.pick_host_name_from_backend_address
      ]) &&
      one(one(azurerm_application_gateway.this.rewrite_rule_set).rewrite_rule).url[0].query_string == "{var_query_string}"
    )
    error_message = "Keep HTTPS backend hosts, the API health check, and query parameters in rewrites."
  }
}

run "additional_application" {
  command = apply
  variables {
    config = {
      backends = {
        site = { fqdns = ["site.example.com"] }
        reports = {
          fqdns           = ["reports.example.com"]
          protocol        = "Http"
          port            = 8080
          request_timeout = 60
          probe           = { path = "/ready", interval = 15, timeout = 10 }
        }
        legacy = { fqdns = ["legacy.example.com"] }
      }
      default_backend  = "site"
      min_capacity     = 2
      max_capacity     = 5
      routing_priority = 200
      waf_mode         = "Detection"
      routes = [
        { name = "reports-detail", paths = ["/reports/detail/*"], backend = "legacy" },
        { name = "reports", paths = ["/reports/*"], backend = "reports", rewrite_rule_set = "reports-prefix" },
      ]
      rewrite_rule_sets = {
        reports-prefix = [{
          name          = "remove-reports-prefix"
          rule_sequence = 50
          conditions    = [{ variable = "var_uri_path", pattern = "^/reports/(.*)$" }]
          path          = "/{var_uri_path_1}"
        }]
      }
    }
  }

  assert {
    condition = (
      length(azurerm_application_gateway.this.backend_address_pool) == 3 &&
      one([for settings in azurerm_application_gateway.this.backend_http_settings : settings if settings.name == "reports"]).port == 8080 &&
      one([for settings in azurerm_application_gateway.this.backend_http_settings : settings if settings.name == "reports"]).request_timeout == 60 &&
      one([for probe in azurerm_application_gateway.this.probe : probe if probe.name == "reports"]).path == "/ready" &&
      one([for probe in azurerm_application_gateway.this.probe : probe if probe.name == "reports"]).protocol == "Http"
    )
    error_message = "Custom backends must receive their own port, timeout, and probe settings."
  }

  assert {
    condition = (
      one(azurerm_application_gateway.this.url_path_map).path_rule[0].name == "reports-detail" &&
      one(azurerm_application_gateway.this.url_path_map).path_rule[1].rewrite_rule_set_name == "reports-prefix" &&
      azurerm_application_gateway.this.autoscale_configuration[0].max_capacity == 5 &&
      one(azurerm_application_gateway.this.request_routing_rule).priority == 200 &&
      azurerm_web_application_firewall_policy.this.policy_settings[0].mode == "Detection"
    )
    error_message = "Route order, rewrite selection, autoscaling, priority, and WAF mode must follow configuration."
  }
}

run "single_ip_backend" {
  command = apply
  variables {
    config = {
      backends = {
        service = { ip_addresses = ["10.20.8.10"], protocol = "Http", port = 8080 }
      }
      default_backend = "service"
    }
  }

  assert {
    condition = (
      length(azurerm_application_gateway.this.url_path_map) == 0 &&
      length(azurerm_application_gateway.this.rewrite_rule_set) == 0 &&
      one(azurerm_application_gateway.this.request_routing_rule).rule_type == "Basic" &&
      one(azurerm_application_gateway.this.request_routing_rule).backend_address_pool_name == "service" &&
      one(azurerm_application_gateway.this.backend_http_settings).pick_host_name_from_backend_address == false &&
      one(azurerm_application_gateway.this.probe).host == "127.0.0.1" &&
      one(azurerm_application_gateway.this.probe).pick_host_name_from_backend_http_settings == false
    )
    error_message = "IP-only backends need a valid probe host and Basic routing without path maps or rewrites."
  }
}

run "explicit_hosts_and_default_rewrite" {
  command = apply
  variables {
    config = {
      backends = {
        service = {
          fqdns     = ["service.example.com"]
          host_name = "virtual-host.example.com"
          probe     = { path = "/health", host = "probe.example.com" }
        }
      }
      default_backend          = "service"
      default_rewrite_rule_set = "all"
      rewrite_rule_sets = {
        all = [{ name = "all", rule_sequence = 1, path = "/landing", query_string = "" }]
      }
    }
  }

  assert {
    condition = (
      one(azurerm_application_gateway.this.backend_http_settings).host_name == "virtual-host.example.com" &&
      one(azurerm_application_gateway.this.backend_http_settings).pick_host_name_from_backend_address == false &&
      one(azurerm_application_gateway.this.probe).host == "probe.example.com" &&
      one(azurerm_application_gateway.this.probe).pick_host_name_from_backend_http_settings == false &&
      one(azurerm_application_gateway.this.request_routing_rule).rewrite_rule_set_name == "all" &&
      one(one(azurerm_application_gateway.this.rewrite_rule_set).rewrite_rule).url[0].query_string == ""
    )
    error_message = "Explicit HTTP/probe hosts and deliberate query replacement must be honored."
  }
}

run "reject_missing_backend" {
  command = plan
  variables {
    config = {
      backends        = { site = { fqdns = ["site.example.com"] } }
      default_backend = "site"
      routes          = [{ name = "missing", paths = ["/missing/*"], backend = "missing" }]
    }
  }
  expect_failures = [var.config]
}

run "reject_missing_rewrite" {
  command = plan
  variables {
    config = {
      backends        = { site = { fqdns = ["site.example.com"] } }
      default_backend = "site"
      routes          = [{ name = "missing", paths = ["/missing/*"], backend = "site", rewrite_rule_set = "missing" }]
    }
  }
  expect_failures = [var.config]
}

run "reject_invalid_probe_and_scaling" {
  command = plan
  variables {
    config = {
      backends        = { site = { fqdns = ["site.example.com"], probe = { path = "invalid", timeout = 0 } } }
      default_backend = "site"
      min_capacity    = 5
      max_capacity    = 3
    }
  }
  expect_failures = [var.config]
}

run "reject_empty_targets" {
  command = plan
  variables {
    config = {
      backends        = { site = {} }
      default_backend = "site"
    }
  }
  expect_failures = [var.config]
}
