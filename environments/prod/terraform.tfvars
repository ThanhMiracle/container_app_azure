# Existing subscription / Resource Group
subscription_id     = "223b3cc4-6941-480a-81ec-4825adcd8b0e"
resource_group_name = "ThanhDT03-Lab"
location            = "japanwest"

project_name = "myapp"
environment  = "prod"

# Networking
vnet_address_space               = ["10.20.0.0/16"]
app_gateway_subnet_prefixes      = ["10.20.1.0/24"]
container_apps_subnet_prefixes   = ["10.20.8.0/21"]
postgres_subnet_prefixes         = ["10.20.4.0/24"]
private_endpoint_subnet_prefixes = ["10.20.5.0/24"]

# Globally unique names. Change any value if Azure reports a name collision.
acr_name                     = "myappprodacrthanhdt03"
storage_account_name         = "thanhdzvl2001"
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

# PostgreSQL
postgres_database_name                = "appdb"
postgres_admin_username               = "pgadminuser"
postgres_version                      = "16"
postgres_sku_name                     = "GP_Standard_D2s_v3"
postgres_storage_mb                   = 32768
postgres_backup_retention_days        = 14
postgres_geo_redundant_backup_enabled = false

# Keep Allow while applying from your workstation because Terraform creates and reads
# the database-url Key Vault secret through the data plane.
key_vault_network_default_action = "Allow"
key_vault_allowed_ip_cidrs       = []

# Optional: Service Bus Premium + private endpoint can be expensive.
deploy_service_bus         = false
service_bus_namespace_name = "myapp-prod-sb-thanhdt03"
service_bus_queue_name     = "jobs"


backend_container_port  = 8000
frontend_container_port = 8080