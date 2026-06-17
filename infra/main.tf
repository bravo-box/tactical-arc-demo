locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_name}-${var.environment}-rg"
  common_tags = merge(var.tags, {
    environment = var.environment
  })
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project_name        = var.project_name
  environment         = var.environment
  vnet_address_space  = var.vnet_address_space
  aks_subnet_prefix   = var.aks_subnet_prefix
  tags                = local.common_tags
}

module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  project_name        = var.project_name
  environment         = var.environment
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  project_name           = var.project_name
  environment            = var.environment
  node_count             = var.aks_node_count
  node_vm_size           = var.aks_node_vm_size
  kubernetes_version     = var.aks_kubernetes_version
  vnet_subnet_id         = module.networking.aks_subnet_id
  acr_id                 = module.acr.acr_id
  tags                   = local.common_tags
}
