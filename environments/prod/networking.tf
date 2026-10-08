module "vnet" {
  source = "../../modules/virtual-network"

  name                = "${local.prefix}-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = local.tags
}

module "app_gateway_subnet" {
  source = "../../modules/subnet"

  name                 = "${local.prefix}-appgw-snet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.app_gateway_subnet_prefixes
}

module "container_apps_subnet" {
  source = "../../modules/subnet"

  name                 = "${local.prefix}-aca-snet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.container_apps_subnet_prefixes

  delegation = {
    name         = "container-apps"
    service_name = "Microsoft.App/environments"
    actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

module "postgres_subnet" {
  source = "../../modules/subnet"

  name                 = "${local.prefix}-postgres-snet"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.postgres_subnet_prefixes

  delegation = {
    name         = "postgres-flexible-server"
    service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
    actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

module "private_endpoint_subnet" {
  source = "../../modules/subnet"

  name                              = "${local.prefix}-pe-snet"
  resource_group_name               = data.azurerm_resource_group.this.name
  virtual_network_name              = module.vnet.name
  address_prefixes                  = var.private_endpoint_subnet_prefixes
  private_endpoint_network_policies = "Disabled"
}

module "app_gateway_nsg" {
  source = "../../modules/network-security-group"

  name                = "${local.prefix}-appgw-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = module.app_gateway_subnet.id
  tags                = local.tags

  rules = {
    allow-front-door-http = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "AzureFrontDoor.Backend"
      destination_address_prefix = "*"
    }

    allow-gateway-manager = {
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "65200-65535"
      source_address_prefix      = "GatewayManager"
      destination_address_prefix = "*"
    }

    allow-azure-load-balancer = {
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "AzureLoadBalancer"
      destination_address_prefix = "*"
    }
  }
}
