# Gateway configuration is supplied as a single object in terraform.tfvars.
variable "app_gateway" {
  description = "Gateway routing configuration. container_app resolves frontend/backend FQDNs automatically; other backends use explicit fqdns or ip_addresses."
  type = object({
    backends = map(object({
      container_app         = optional(string)
      fqdns                 = optional(set(string), [])
      ip_addresses          = optional(set(string), [])
      port                  = optional(number, 443)
      protocol              = optional(string, "Https")
      host_name             = optional(string)
      request_timeout       = optional(number, 30)
      cookie_based_affinity = optional(string, "Disabled")
      probe = optional(object({
        path                = optional(string, "/")
        host                = optional(string)
        interval            = optional(number, 30)
        timeout             = optional(number, 30)
        unhealthy_threshold = optional(number, 3)
      }), {})
    }))
    default_backend = string
    routes = optional(list(object({
      name             = string
      paths            = list(string)
      backend          = string
      rewrite_rule_set = optional(string)
    })), [])
    rewrite_rule_sets = optional(map(list(object({
      name          = string
      rule_sequence = number
      conditions = optional(list(object({
        variable    = string
        pattern     = string
        ignore_case = optional(bool, false)
        negate      = optional(bool, false)
      })), [])
      path         = string
      query_string = optional(string, "{var_query_string}")
      reroute      = optional(bool, false)
    }))), {})
    default_rewrite_rule_set = optional(string)
    min_capacity             = optional(number, 1)
    max_capacity             = optional(number, 3)
    routing_priority         = optional(number, 100)
    waf_mode                 = optional(string, "Prevention")
  })
  default = {
    backends = {
      frontend = { container_app = "frontend" }
      backend  = { container_app = "backend", probe = { path = "/health" } }
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
        conditions = [{
          variable = "var_uri_path"
          pattern  = "^/api/(.*)$"
        }]
        path = "/{var_uri_path_1}"
      }]
    }
  }

  validation {
    condition = length(var.app_gateway.backends) > 0 && alltrue([
      for backend in values(var.app_gateway.backends) :
      contains(["Http", "Https"], backend.protocol) &&
      backend.port >= 1 && backend.port <= 65535 && floor(backend.port) == backend.port &&
      backend.request_timeout >= 1 && backend.request_timeout <= 86400 &&
      floor(backend.request_timeout) == backend.request_timeout &&
      contains(["Disabled", "Enabled"], backend.cookie_based_affinity) &&
      startswith(backend.probe.path, "/") &&
      backend.probe.interval >= 1 && backend.probe.interval <= 86400 &&
      floor(backend.probe.interval) == backend.probe.interval &&
      backend.probe.timeout >= 1 && backend.probe.timeout <= 86400 &&
      floor(backend.probe.timeout) == backend.probe.timeout &&
      backend.probe.unhealthy_threshold >= 1 && backend.probe.unhealthy_threshold <= 20 &&
      floor(backend.probe.unhealthy_threshold) == backend.probe.unhealthy_threshold
    ])
    error_message = "Configure at least one backend with Http/Https, a valid port, affinity, timeout, and health probe (path starting with /, timing 1-86400 seconds, threshold 1-20)."
  }

  validation {
    condition = contains(keys(var.app_gateway.backends), var.app_gateway.default_backend) && alltrue([
      for route in var.app_gateway.routes : contains(keys(var.app_gateway.backends), route.backend)
    ])
    error_message = "default_backend and every route.backend must reference a key in backends."
  }

  validation {
    condition = (
      length(distinct([for route in var.app_gateway.routes : route.name])) == length(var.app_gateway.routes) &&
      alltrue([for route in var.app_gateway.routes :
        length(route.paths) > 0 && alltrue([for path in route.paths : startswith(path, "/")])
      ])
    )
    error_message = "Routes must have unique names and at least one path starting with /."
  }

  validation {
    condition = alltrue([
      for route in var.app_gateway.routes :
      route.rewrite_rule_set == null ? true : contains(keys(var.app_gateway.rewrite_rule_sets), route.rewrite_rule_set)
      ]) && (
      var.app_gateway.default_rewrite_rule_set == null ? true :
      contains(keys(var.app_gateway.rewrite_rule_sets), var.app_gateway.default_rewrite_rule_set)
    )
    error_message = "Every referenced rewrite_rule_set must be defined in rewrite_rule_sets."
  }

  validation {
    condition = alltrue([
      for rules in values(var.app_gateway.rewrite_rule_sets) :
      length(rules) > 0 &&
      length(distinct([for rule in rules : rule.name])) == length(rules) &&
      length(distinct([for rule in rules : rule.rule_sequence])) == length(rules) &&
      alltrue([for rule in rules :
        rule.rule_sequence >= 1 && rule.rule_sequence <= 1000 && floor(rule.rule_sequence) == rule.rule_sequence
      ])
    ])
    error_message = "Each rewrite set needs rules with unique names and unique integer sequences between 1 and 1000."
  }

  validation {
    condition = (
      var.app_gateway.min_capacity >= 0 && var.app_gateway.min_capacity <= 100 && var.app_gateway.max_capacity >= 2 &&
      var.app_gateway.max_capacity <= 125 && var.app_gateway.min_capacity <= var.app_gateway.max_capacity &&
      floor(var.app_gateway.min_capacity) == var.app_gateway.min_capacity &&
      floor(var.app_gateway.max_capacity) == var.app_gateway.max_capacity &&
      var.app_gateway.routing_priority >= 1 && var.app_gateway.routing_priority <= 20000 &&
      floor(var.app_gateway.routing_priority) == var.app_gateway.routing_priority &&
      contains(["Prevention", "Detection"], var.app_gateway.waf_mode)
    )
    error_message = "Use integer autoscale capacities with min 0-100, max 2-125, and min <= max; priority 1-20000; and WAF mode Prevention or Detection."
  }

  validation {
    condition = alltrue([
      for backend in values(var.app_gateway.backends) :
      (backend.container_app == null ? true : contains(["frontend", "backend"], backend.container_app)) &&
      (backend.container_app != null || length(backend.fqdns) + length(backend.ip_addresses) > 0)
    ])
    error_message = "Each backend must select container_app frontend/backend, or supply fqdns/ip_addresses."
  }
}
