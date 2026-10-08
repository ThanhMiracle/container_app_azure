module "acr_private_dns" {
  source = "../../modules/private-dns-zone"

  zone_name           = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-acr-dns-link"
  tags                = local.tags
}

module "acr_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "${local.prefix}-acr-pe"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  subnet_id                      = module.private_endpoint_subnet.id
  private_connection_resource_id = module.acr.id
  subresource_names              = ["registry"]
  private_dns_zone_ids           = [module.acr_private_dns.id]
  tags                           = local.tags
}

module "key_vault_private_dns" {
  source = "../../modules/private-dns-zone"

  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-kv-dns-link"
  tags                = local.tags
}

module "key_vault_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "${local.prefix}-kv-pe"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  subnet_id                      = module.private_endpoint_subnet.id
  private_connection_resource_id = module.key_vault.id
  subresource_names              = ["vault"]
  private_dns_zone_ids           = [module.key_vault_private_dns.id]
  tags                           = local.tags
}

module "blob_private_dns" {
  source = "../../modules/private-dns-zone"

  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-blob-dns-link"
  tags                = local.tags
}

module "storage_blob_private_endpoint" {
  source = "../../modules/private-endpoint"

  name                           = "${local.prefix}-blob-pe"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  subnet_id                      = module.private_endpoint_subnet.id
  private_connection_resource_id = module.storage.id
  subresource_names              = ["blob"]
  private_dns_zone_ids           = [module.blob_private_dns.id]
  tags                           = local.tags
}

module "service_bus_private_dns" {
  source = "../../modules/private-dns-zone"
  count  = var.deploy_service_bus ? 1 : 0

  zone_name           = "privatelink.servicebus.windows.net"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-sb-dns-link"
  tags                = local.tags
}

module "service_bus_private_endpoint" {
  source = "../../modules/private-endpoint"
  count  = var.deploy_service_bus ? 1 : 0

  name                           = "${local.prefix}-sb-pe"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.this.name
  subnet_id                      = module.private_endpoint_subnet.id
  private_connection_resource_id = module.service_bus[0].id
  subresource_names              = ["namespace"]
  private_dns_zone_ids           = [module.service_bus_private_dns[0].id]
  tags                           = local.tags
}
