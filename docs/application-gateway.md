# Configuring Application Gateway

Edit `app_gateway` in `environments/prod/terraform.tfvars`. The checked-in configuration keeps the current frontend as the fallback, sends `/api` and `/api/*` to the backend, and removes the `/api/` prefix while preserving query parameters (including WebSocket authentication tokens).

Gateway resource addresses and existing pool, probe, route, and rewrite names are preserved. The listener remains HTTP on port 80 behind Front Door; changing TLS or host-based listeners requires coordinated changes to Front Door, certificates, and networking.

## Backends

Each key in `backends` creates a backend pool, HTTP settings, and a health probe with that name. `default_backend` selects the fallback backend. The environment's `container_app` selector accepts `frontend` or `backend` and resolves that app's FQDN automatically. For additional applications, supply their reachable FQDNs or IP addresses.

| Backend option | Default |
| --- | --- |
| `container_app` | None; environment-only selector |
| `fqdns`, `ip_addresses` | Empty sets; at least one target or selector is required |
| `port`, `protocol` | `443`, `"Https"` |
| `host_name` | Use the backend FQDN as the HTTP host; IP-only pools preserve the incoming host |
| `request_timeout` | `30` seconds |
| `cookie_based_affinity` | `"Disabled"` |
| `probe.path` | `"/"` |
| `probe.host` | Inherit the HTTP settings' host; IP-only pools default to `"127.0.0.1"` |
| `probe.interval`, `probe.timeout` | `30` seconds each |
| `probe.unhealthy_threshold` | `3` |

`port` is the port reached by Application Gateway. Container Apps with HTTPS ingress use 443 here even when their container listens on 8000 or 8080.

## Adding another application

Add a backend and a route to the existing `app_gateway` object:

```hcl
# Add inside app_gateway.backends:
reports = {
  fqdns           = ["reports.internal.example.com"]
  port            = 8080
  protocol        = "Http"
  request_timeout = 60
  probe = {
    path     = "/ready"
    interval = 15
    timeout  = 10
  }
}

# Append inside app_gateway.routes:
{
  name    = "reports"
  paths   = ["/reports", "/reports/*"]
  backend = "reports"
}
```

The example preserves the `/reports` prefix. The application must serve those paths. To strip the prefix, add a rewrite set and reference it from the route:

```hcl
# Add inside app_gateway.rewrite_rule_sets:
reports-prefix = [{
  name          = "remove-reports-prefix"
  rule_sequence = 100
  conditions = [{
    variable = "var_uri_path"
    pattern  = "^/reports/?(.*)$"
  }]
  path = "/{var_uri_path_1}"
}]

# Add to the reports route:
rewrite_rule_set = "reports-prefix"
```

`query_string` defaults to `"{var_query_string}"` and `reroute` defaults to `false`. Use `query_string = ""` only when deliberately dropping query parameters. Rewrite conditions optionally accept `ignore_case` and `negate`, both defaulting to `false`.

Routes are evaluated in list order: put specific paths before overlapping wildcard paths. Each route needs a unique name and a valid backend key. Rewrite references must identify a defined set.

These settings route traffic to existing applications; they do not create another Container App or its DNS/network connectivity.

## One application without path routing

This complete alternative sends every request to the backend without rewriting its URL:

```hcl
app_gateway = {
  backends = {
    service = {
      container_app = "backend"
      probe         = { path = "/health" }
    }
  }
  default_backend = "service"
}
```

Omitting `routes` (or setting `routes = []`) selects Basic routing. Omitting `rewrite_rule_sets` creates no rewrite sets. A custom `app_gateway` object replaces the default routing configuration; include every backend, route, and rewrite you want to keep.

## Other settings

| Option | Default | Meaning |
| --- | --- | --- |
| `min_capacity` | `1` | Minimum autoscale instance count, 0–100 |
| `max_capacity` | `3` | Maximum autoscale instance count, 2–125 and at least the minimum |
| `routing_priority` | `100` | Routing rule priority, 1–20000 |
| `waf_mode` | `"Prevention"` | `Prevention` or `Detection` |
| `default_rewrite_rule_set` | None | Rewrite for fallback traffic, or all traffic in Basic routing |

To use the reusable module directly, pass the same object as `config`, supplying explicit `fqdns`/`ip_addresses` instead of the environment-only `container_app` selector.

## Validate and deploy

From the repository root, with the usual Terraform credentials and secret variables available:

```powershell
terraform -chdir=environments/prod validate
terraform -chdir=environments/prod plan -out=gateway-change.tfplan
terraform -chdir=environments/prod apply gateway-change.tfplan
```

Review the plan before applying. Configuration-only module tests use mock providers and do not contact Azure:

```powershell
terraform -chdir=modules/application-gateway init -backend=false
terraform -chdir=modules/application-gateway test
```
