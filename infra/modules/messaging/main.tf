resource "azurerm_servicebus_namespace" "this" {
  #checkov:skip=CKV_AZURE_199:Double encryption with customer-managed keys is outside the approved demo scope.
  #checkov:skip=CKV_AZURE_201:Microsoft-managed keys satisfy the approved demo scope; no customer-managed key was requested.
  name                          = "sbns-${var.name_prefix}-${var.unique_suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  capacity                      = 1
  premium_messaging_partitions  = 1
  minimum_tls_version           = "1.2"
  local_auth_enabled            = false
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_servicebus_queue" "telemetry" {
  name                                    = "telemetry"
  namespace_id                            = azurerm_servicebus_namespace.this.id
  lock_duration                           = "PT1M"
  max_delivery_count                      = 10
  dead_lettering_on_message_expiration    = true
  duplicate_detection_history_time_window = "PT10M"
  requires_duplicate_detection            = true
  default_message_ttl                     = "P7D"
}

resource "azurerm_servicebus_topic" "edge_heartbeat" {
  name                                    = "edge-heartbeat"
  namespace_id                            = azurerm_servicebus_namespace.this.id
  default_message_ttl                     = "P1D"
  duplicate_detection_history_time_window = "PT10M"
  requires_duplicate_detection            = true
}

resource "azurerm_servicebus_subscription" "heartbeat_monitor" {
  name               = "heartbeat-monitor"
  topic_id           = azurerm_servicebus_topic.edge_heartbeat.id
  lock_duration      = "PT1M"
  max_delivery_count = 10
}

resource "azurerm_role_assignment" "workload_sender" {
  scope                = azurerm_servicebus_queue.telemetry.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = var.workload_identity_principal
}

resource "azurerm_role_assignment" "workload_receiver" {
  scope                = azurerm_servicebus_queue.telemetry.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.workload_identity_principal
}

resource "azurerm_role_assignment" "edge_sender" {
  count = var.edge_arc_principal_id == null ? 0 : 1

  scope                = azurerm_servicebus_topic.edge_heartbeat.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = var.edge_arc_principal_id
}

data "azurerm_monitor_diagnostic_categories" "servicebus" {
  resource_id = azurerm_servicebus_namespace.this.id
}

resource "azurerm_monitor_diagnostic_setting" "servicebus" {
  name                       = "diag-servicebus"
  target_resource_id         = azurerm_servicebus_namespace.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.servicebus.log_category_types
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
