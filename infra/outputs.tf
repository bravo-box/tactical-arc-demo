output "resource_group_name" {
  description = "Name of the resource group holding the demo resources."
  value       = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  description = "Name of the cloud AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "container_registry_name" {
  description = "Globally unique name of the container registry."
  value       = azurerm_container_registry.this.name
}

output "container_registry_login_server" {
  description = "Login server for the container registry used by both clusters."
  value       = azurerm_container_registry.this.login_server
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace used for cluster and edge telemetry."
  value       = azurerm_log_analytics_workspace.this.id
}
