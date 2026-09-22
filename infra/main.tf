data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false

  keepers = {
    subscription = data.azurerm_client_config.current.subscription_id
    name_prefix  = var.name_prefix
  }
}

locals {
  tags = merge(var.tags, {
    environment = var.environment
    workload    = "tactical-arc-demo"
    managed-by  = "terraform"
  })
}

module "networking" {
  source = "./modules/networking"

  location                                  = var.location
  resource_group_name                       = "az-tactical-demo-network"
  name_prefix                               = var.name_prefix
  vnet_address_space                        = var.vnet_address_space
  aks_subnet_prefix                         = var.aks_subnet_prefix
  application_gateway_prefix                = var.application_gateway_subnet_prefix
  private_endpoint_prefix                   = var.private_endpoint_subnet_prefix
  gateway_subnet_prefix                     = var.gateway_subnet_prefix
  bastion_subnet_prefix                     = var.bastion_subnet_prefix
  vpn_client_address_space                  = var.vpn_client_address_space
  tenant_id                                 = data.azurerm_client_config.current.tenant_id
  vpn_gateway_sku                           = var.vpn_gateway_sku
  application_gateway_key_vault_id          = var.application_gateway_key_vault_id
  application_gateway_certificate_secret_id = var.application_gateway_certificate_secret_id
  edge_vpn_enabled                          = var.edge_vpn_enabled
  edge_gateway_address                      = var.edge_gateway_address
  edge_address_spaces                       = var.edge_address_spaces
  edge_shared_key                           = var.edge_shared_key
  tags                                      = local.tags
}

module "cloud" {
  source = "./modules/cloud"

  location                          = var.location
  resource_group_name               = "az-tactical-demo-cloud"
  name_prefix                       = var.name_prefix
  unique_suffix                     = random_string.suffix.result
  kubernetes_version                = var.kubernetes_version
  node_count                        = var.node_count
  node_vm_size                      = var.node_vm_size
  aks_subnet_id                     = module.networking.aks_subnet_id
  application_gateway_id            = module.networking.application_gateway_id
  application_gateway_subnet_id     = module.networking.application_gateway_subnet_id
  cluster_admin_principal_id        = data.azurerm_client_config.current.object_id
  service_cidr                      = var.aks_service_cidr
  dns_service_ip                    = var.aks_dns_service_ip
  workload_identity_namespace       = var.workload_identity_namespace
  workload_identity_service_account = var.workload_identity_service_account
  tags                              = local.tags
}

module "messaging" {
  source = "./modules/messaging"

  location                    = var.location
  resource_group_name         = module.cloud.resource_group_name
  name_prefix                 = var.name_prefix
  unique_suffix               = random_string.suffix.result
  workload_identity_principal = module.cloud.workload_identity_principal_id
  edge_arc_principal_id       = var.edge_arc_principal_id
  log_analytics_workspace_id  = module.cloud.log_analytics_workspace_id
  tags                        = local.tags
}

module "private_link" {
  source = "./modules/private-link"

  location                   = var.location
  resource_group_name        = module.networking.resource_group_name
  vnet_id                    = module.networking.vnet_id
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  container_registry_id      = module.cloud.container_registry_id
  servicebus_namespace_id    = module.messaging.servicebus_namespace_id
  tags                       = local.tags
}

module "edge" {
  source = "./modules/edge"

  location            = var.location
  resource_group_name = "az-tactical-demo-edge"
  tags                = local.tags
}
