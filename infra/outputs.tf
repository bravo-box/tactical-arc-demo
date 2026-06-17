output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "acr_login_server" {
  description = "Login server URL for Azure Container Registry"
  value       = module.acr.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.acr.acr_name
}

output "vnet_id" {
  description = "Resource ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

output "get_credentials_command" {
  description = "Command to retrieve AKS credentials for kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name} --environment usgovernment"
}
