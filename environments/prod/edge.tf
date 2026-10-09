locals {
  app_gateway_container_app_fqdns = {
    frontend = module.frontend.fqdn
    backend  = module.backend.fqdn
  }

  app_gateway_backends = {
    for name, backend in var.app_gateway.backends : name => merge(backend, {
      fqdns = backend.container_app == null ? backend.fqdns : setunion(
        backend.fqdns,
        toset([lookup(local.app_gateway_container_app_fqdns, backend.container_app, "")])
      )
    })
  }
}

module "application_gateway" {
  source = "../../modules/application-gateway"

  name                = "${local.prefix}-appgw"
  public_ip_name      = "${local.prefix}-appgw-pip"
  public_dns_label    = var.app_gateway_public_dns_label
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  subnet_id           = module.app_gateway_subnet.id
  config              = merge(var.app_gateway, { backends = local.app_gateway_backends })
  tags                = local.tags

  depends_on = [
    module.app_gateway_nsg,
    module.container_apps_private_dns
  ]
}

module "front_door" {
  source = "../../modules/front-door"

  name                = "${local.prefix}-afd"
  endpoint_name       = var.front_door_endpoint_name
  resource_group_name = data.azurerm_resource_group.this.name
  origin_host_name    = module.application_gateway.public_fqdn
  tags                = local.tags
}
