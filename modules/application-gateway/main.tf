resource "azurerm_public_ip" "this" {
  name                = var.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.public_dns_label
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = "${var.name}-waf"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id
  http2_enabled       = true
  tags                = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.this.id
  }

  backend_address_pool {
    name  = "frontend"
    fqdns = [var.frontend_backend_fqdn]
  }

  backend_address_pool {
    name  = "backend"
    fqdns = [var.backend_backend_fqdn]
  }

  probe {
    name                                      = "frontend"
    protocol                                  = "Https"
    path                                      = var.frontend_probe_path
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  probe {
    name                                      = "backend"
    protocol                                  = "Https"
    path                                      = var.backend_probe_path
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true
  }

  backend_http_settings {
    name                                = "frontend"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "frontend"
  }

  backend_http_settings {
    name                                = "backend"
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 30
    pick_host_name_from_backend_address = true
    probe_name                          = "backend"
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  rewrite_rule_set {
    name = "backend-api-prefix"

    rewrite_rule {
      name          = "remove-api-prefix"
      rule_sequence = 100

      condition {
        variable    = "var_uri_path"
        pattern     = "^/api/(.*)$"
        ignore_case = false
        negate      = false
      }

      url {
        path         = "/{var_uri_path_1}"
        query_string = "{var_query_string}"
        reroute      = false
      }
    }
  }

  url_path_map {
    name                               = "application-routes"
    default_backend_address_pool_name  = "frontend"
    default_backend_http_settings_name = "frontend"

    path_rule {
      name                       = "backend-api"
      paths                      = ["/api", "/api/*"]
      backend_address_pool_name  = "backend"
      backend_http_settings_name = "backend"
      rewrite_rule_set_name      = "backend-api-prefix"
    }
  }

  request_routing_rule {
    name               = "application"
    rule_type          = "PathBasedRouting"
    http_listener_name = "http"
    url_path_map_name  = "application-routes"
    priority           = 100
  }
}
