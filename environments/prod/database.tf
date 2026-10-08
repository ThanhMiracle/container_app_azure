module "postgres_private_dns" {
  source = "../../modules/private-dns-zone"

  zone_name           = "${local.prefix}.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.this.name
  virtual_network_id  = module.vnet.id
  vnet_link_name      = "${local.prefix}-postgres-dns-link"
  tags                = local.tags
}

module "postgresql" {
  source = "../../modules/postgresql"

  name                = var.postgres_server_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location

  delegated_subnet_id          = module.postgres_subnet.id
  private_dns_zone_id          = module.postgres_private_dns.id
  administrator_login          = var.postgres_admin_username
  administrator_password       = var.postgres_administrator_password
  database_name                = var.postgres_database_name
  postgres_version             = var.postgres_version
  sku_name                     = var.postgres_sku_name
  storage_mb                   = var.postgres_storage_mb
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = var.postgres_geo_redundant_backup_enabled
  high_availability_mode       = null
  tags                         = local.tags

  depends_on = [module.postgres_private_dns]
}
