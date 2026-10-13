# Existing subscription / Resource Group
subscription_id     = "223b3cc4-6941-480a-81ec-4825adcd8b0e"
resource_group_name = "ThanhDT03-Lab"
location            = "japanwest"

project_name = "myapp"
environment  = "prod"

# Azure Monitor alert notifications and public HTTPS availability checks.
monitor_alert_email_addresses      = ["dtthanh2909@gmail.com"]
monitor_alerts_enabled             = true
monitor_availability_tests_enabled = true

# Networking
vnet_address_space               = ["10.20.0.0/16"]
app_gateway_subnet_prefixes      = ["10.20.1.0/24"]
container_apps_subnet_prefixes   = ["10.20.8.0/21"]
postgres_subnet_prefixes         = ["10.20.4.0/24"]
private_endpoint_subnet_prefixes = ["10.20.5.0/24"]


# Globally unique names. Change any value if Azure reports a name collision.
acr_name                     = "myappprodacrthanhdt03"
storage_account_name         = "thanhdzvl2001"
storage_replication_type     = "LRS"
key_vault_name               = "myapp-prod-kv-thanhdt03"
postgres_server_name         = "myapp-prod-pg-thanhdt03"
front_door_endpoint_name     = "myapp-prod-fd-thanhdt03"
app_gateway_public_dns_label = "myapp-prod-appgw-thanhdt03"

# GitHub OIDC publisher identity. Change this if the application repository differs.
github_oidc_subjects = {
  master = "repo:Dev-MT10-SI@330316027/VNN-Agent-orchestrator@1374089373:ref:refs/heads/master"
}

# ==============================================================================
# GitHub Actions - Container Apps Deployer
# ==============================================================================

github_deploy_oidc_subjects = {
  production = "repo:Dev-MT10-SI@330316027/VNN-Agent-orchestrator@1374089373:environment:production"
}

# Terraform creates the Container Apps now with this public image.
# Future CI/CD replaces the image and Terraform ignores that image change.
container_app_placeholder_image = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

# container_app_port
backend_container_port  = 8000
frontend_container_port = 8080

# Container Apps HA: keep replicas available across multiple zones.
frontend_min_replicas = 2
frontend_max_replicas = 3
backend_min_replicas  = 2
backend_max_replicas  = 5

# Probes use TCP on each app's container port by default. Once the deployed
# images expose these endpoints, enable HTTP application checks, for example:
# frontend_health_probe_paths = { readiness = "/", liveness = "/" }
# backend_health_probe_paths  = { readiness = "/health", liveness = "/health" }


# ============================================================
# FRONTEND ENVIRONMENT VARIABLES
# ============================================================

frontend_environment_variables = {
  API_BASE = "/api"
}


# ============================================================
# BACKEND ENVIRONMENT VARIABLES
# ============================================================

backend_environment_variables = {

  # Authentication
  JWT_EXPIRE_MINUTES        = "60"
  LOGIN_RATE_LIMIT          = "5"
  LOGIN_RATE_WINDOW_SECONDS = "60"

  # Admin
  ADMIN_EMAIL = "admin@example.com"

  # SMTP Configuration
  SMTP_HOST     = "smtp.gmail.com"
  SMTP_PORT     = "587"
  SMTP_USERNAME = "dtthanh2909@gmail.com"
  SMTP_FROM     = "dtthanh2909@gmail.com"
  SMTP_USE_TLS  = "true"

  # Azure Blob Storage
  STORAGE_BACKEND                     = "azure"
  AZURE_STORAGE_CONTAINER             = "products"
  AZURE_STORAGE_AUTO_CREATE_CONTAINER = "false"
  AZURE_BLOB_PROXY_URL                = "/api/files/images"
}



# PostgreSQL
postgres_database_name                = "appdb"
postgres_admin_username               = "pgadminuser"
postgres_version                      = "16"
postgres_sku_name                     = "GP_Standard_D2s_v3"
postgres_storage_mb                   = 32768
postgres_backup_retention_days        = 14
postgres_geo_redundant_backup_enabled = false

# PostgreSQL High Availability
postgres_high_availability_mode = "SameZone"

# Keep Allow while applying from your workstation because Terraform creates and reads
# the database-url Key Vault secret through the data plane.
key_vault_network_default_action = "Allow"
key_vault_allowed_ip_cidrs       = []

# Optional: Service Bus Premium + private endpoint can be expensive.
deploy_service_bus         = false
service_bus_namespace_name = "myapp-prod-sb-thanhdt03"
service_bus_queue_name     = "jobs"

# Application Gateway: pools, probes, routes, rewrites, scaling, and WAF.
# See docs/application-gateway.md for additional applications and custom backends.
app_gateway = {
  min_capacity = 1
  max_capacity = 3
  waf_mode     = "Prevention"

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


# Application Gateway High Availability
app_gateway_autoscale_min_capacity = 2
app_gateway_autoscale_max_capacity = 10
