output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "container_registry_id" {
  value = azurerm_container_registry.this.id
}

output "container_registry_name" {
  value = azurerm_container_registry.this.name
}

output "container_registry_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.workload.principal_id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "cosmosdb_account_id" {
  value = azurerm_cosmosdb_account.devices.id
}

output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.devices.endpoint
}

output "cosmosdb_database_name" {
  value = azurerm_cosmosdb_sql_database.devices.name
}

output "cosmosdb_container_name" {
  value = azurerm_cosmosdb_sql_container.devices.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}
