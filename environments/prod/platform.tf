module "acr" {
  source = "../../modules/container-registry"

  name                          = var.acr_name
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.this.name
  sku                           = "Premium"
  public_network_access_enabled = true
  zone_redundancy_enabled       = false
  tags                          = local.tags
}

module "storage" {
  source = "../../modules/storage-account"

  name                          = var.storage_account_name
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.this.name
  replication_type              = var.storage_replication_type
  public_network_access_enabled = false
  tags                          = local.tags
}

resource "azurerm_storage_container" "products" {
  name                  = lookup(var.backend_environment_variables, "AZURE_STORAGE_CONTAINER", "products")
  storage_account_id    = module.storage.id
  container_access_type = "private"
}

module "service_bus" {
  source = "../../modules/service-bus"
  count  = var.deploy_service_bus ? 1 : 0

  name                = var.service_bus_namespace_name
  queue_name          = var.service_bus_queue_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}
