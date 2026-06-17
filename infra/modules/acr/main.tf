locals {
  # ACR name must be alphanumeric, 5-50 chars
  acr_name = replace("${var.project_name}${var.environment}acr", "-", "")
}

resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
