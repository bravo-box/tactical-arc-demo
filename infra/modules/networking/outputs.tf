output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "storage_subnet_id" {
  description = "Resource ID of the storage private endpoint subnet"
  value       = azurerm_subnet.storage.id
}

output "registry_subnet_id" {
  description = "Resource ID of the registry private endpoint subnet"
  value       = azurerm_subnet.registry.id
}
