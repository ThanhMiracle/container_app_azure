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
    mode                        = var.config.waf_mode
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
    min_capacity = var.config.min_capacity
    max_capacity = var.config.max_capacity
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

  dynamic "backend_address_pool" {
    for_each = var.config.backends
    content {
      name         = backend_address_pool.key
      fqdns        = backend_address_pool.value.fqdns
      ip_addresses = backend_address_pool.value.ip_addresses
    }
  }

  dynamic "probe" {
    for_each = var.config.backends
    content {
      name                = probe.key
      protocol            = probe.value.protocol
      path                = probe.value.probe.path
      interval            = probe.value.probe.interval
      timeout             = probe.value.probe.timeout
      unhealthy_threshold = probe.value.probe.unhealthy_threshold
      # DNS backends use their HTTP settings' host. IP-only pools use the
      # default probe host unless an explicit probe.host is supplied.
      pick_host_name_from_backend_http_settings = (
        probe.value.probe.host == null &&
        (probe.value.host_name != null || length(probe.value.fqdns) > 0)
      )
      host = probe.value.probe.host != null ? probe.value.probe.host : (
        probe.value.host_name != null || length(probe.value.fqdns) > 0 ? null : "127.0.0.1"
      )
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.config.backends
    content {
      name                  = backend_http_settings.key
      cookie_based_affinity = backend_http_settings.value.cookie_based_affinity
      port                  = backend_http_settings.value.port
      protocol              = backend_http_settings.value.protocol
      request_timeout       = backend_http_settings.value.request_timeout
      host_name             = backend_http_settings.value.host_name
      pick_host_name_from_backend_address = (
        backend_http_settings.value.host_name == null &&
        length(backend_http_settings.value.fqdns) > 0
      )
      probe_name = backend_http_settings.key
    }
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  dynamic "rewrite_rule_set" {
    for_each = var.config.rewrite_rule_sets
    content {
      name = rewrite_rule_set.key

      dynamic "rewrite_rule" {
        for_each = rewrite_rule_set.value
        content {
          name          = rewrite_rule.value.name
          rule_sequence = rewrite_rule.value.rule_sequence

          dynamic "condition" {
            for_each = rewrite_rule.value.conditions
            content {
              variable    = condition.value.variable
              pattern     = condition.value.pattern
              ignore_case = condition.value.ignore_case
              negate      = condition.value.negate
            }
          }

          url {
            path         = rewrite_rule.value.path
            query_string = rewrite_rule.value.query_string
            reroute      = rewrite_rule.value.reroute
          }
        }
      }
    }
  }

  dynamic "url_path_map" {
    for_each = length(var.config.routes) > 0 ? [var.config.routes] : []
    content {
      name                               = "application-routes"
      default_backend_address_pool_name  = var.config.default_backend
      default_backend_http_settings_name = var.config.default_backend
      default_rewrite_rule_set_name      = var.config.default_rewrite_rule_set

      dynamic "path_rule" {
        for_each = url_path_map.value
        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = path_rule.value.backend
          backend_http_settings_name = path_rule.value.backend
          rewrite_rule_set_name      = path_rule.value.rewrite_rule_set
        }
      }
    }
  }

  request_routing_rule {
    name                       = "application"
    rule_type                  = length(var.config.routes) > 0 ? "PathBasedRouting" : "Basic"
    http_listener_name         = "http"
    url_path_map_name          = length(var.config.routes) > 0 ? "application-routes" : null
    backend_address_pool_name  = length(var.config.routes) > 0 ? null : var.config.default_backend
    backend_http_settings_name = length(var.config.routes) > 0 ? null : var.config.default_backend
    rewrite_rule_set_name      = length(var.config.routes) > 0 ? null : var.config.default_rewrite_rule_set
    priority                   = var.config.routing_priority
  }
}
