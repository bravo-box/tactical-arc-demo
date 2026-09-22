moved {
  from = azurerm_resource_group.this
  to   = module.cloud.azurerm_resource_group.this
}

moved {
  from = azurerm_log_analytics_workspace.this
  to   = module.cloud.azurerm_log_analytics_workspace.this
}

moved {
  from = azurerm_container_registry.this
  to   = module.cloud.azurerm_container_registry.this
}

moved {
  from = azurerm_kubernetes_cluster.this
  to   = module.cloud.azurerm_kubernetes_cluster.this
}

moved {
  from = azurerm_role_assignment.aks_cluster_admin
  to   = module.cloud.azurerm_role_assignment.aks_cluster_admin
}

moved {
  from = azurerm_role_assignment.aks_acr_pull
  to   = module.cloud.azurerm_role_assignment.aks_acr_pull
}
