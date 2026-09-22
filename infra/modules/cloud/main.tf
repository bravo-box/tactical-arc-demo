resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_container_registry" "this" {
  #checkov:skip=CKV_AZURE_164:ACR content trust is deprecated and unavailable for new registries.
  #checkov:skip=CKV_AZURE_165:The approved architecture is intentionally single-region.
  #checkov:skip=CKV_AZURE_233:Zone redundancy availability must be confirmed per Azure Government region before enablement.
  name                          = "cr${var.name_prefix}${var.unique_suffix}"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "None"
  data_endpoint_enabled         = true
  quarantine_policy_enabled     = true
  retention_policy_in_days      = 7
  tags                          = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  #checkov:skip=CKV_AZURE_117:Platform-managed encryption at rest is used; a customer-managed disk encryption set is outside the approved demo scope.
  #checkov:skip=CKV_AZURE_226:The selected Azure Government VM size may not have sufficient local cache for ephemeral OS disks.
  name                              = "aks-${var.name_prefix}"
  location                          = azurerm_resource_group.this.location
  resource_group_name               = azurerm_resource_group.this.name
  dns_prefix                        = var.name_prefix
  kubernetes_version                = var.kubernetes_version
  local_account_disabled            = true
  private_cluster_enabled           = true
  private_dns_zone_id               = "System"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled = true
  sku_tier                          = "Standard"
  azure_policy_enabled              = true
  automatic_upgrade_channel         = "patch"
  tags                              = var.tags

  default_node_pool {
    name                         = "system"
    node_count                   = var.node_count
    vm_size                      = var.node_vm_size
    vnet_subnet_id               = var.aks_subnet_id
    only_critical_addons_enabled = true
    os_disk_size_gb              = 64
    os_disk_type                 = "Managed"
    host_encryption_enabled      = true
    max_pods                     = 50
    type                         = "VirtualMachineScaleSets"
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  ingress_application_gateway {
    gateway_id = var.application_gateway_id
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${var.name_prefix}-workload"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "workload" {
  name                = "fic-${var.name_prefix}-telemetry"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${var.workload_identity_namespace}:${var.workload_identity_service_account}"
}

resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.cluster_admin_principal_id
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_gateway_contributor" {
  scope                = var.application_gateway_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "agic_subnet_network_contributor" {
  scope                = var.application_gateway_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

data "azurerm_monitor_diagnostic_categories" "acr" {
  resource_id = azurerm_container_registry.this.id
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr"
  target_resource_id         = azurerm_container_registry.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.acr.log_category_types
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
