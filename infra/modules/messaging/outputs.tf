output "servicebus_namespace_id" {
  value = azurerm_servicebus_namespace.this.id
}

output "servicebus_namespace_name" {
  value = azurerm_servicebus_namespace.this.name
}

output "servicebus_fully_qualified_namespace" {
  value = "${azurerm_servicebus_namespace.this.name}.servicebus.usgovcloudapi.net"
}

output "edge_heartbeat_topic_name" {
  value = azurerm_servicebus_topic.edge_heartbeat.name
}

output "heartbeat_monitor_subscription_name" {
  value = azurerm_servicebus_subscription.heartbeat_monitor.name
}

output "take_picture_queue_name" {
  value = azurerm_servicebus_queue.take_picture.name
}

output "update_location_queue_name" {
  value = azurerm_servicebus_queue.update_location.name
}

output "image_upload_topic_name" {
  value = azurerm_servicebus_topic.image_upload.name
}

output "image_web_subscription_name" {
  value = azurerm_servicebus_subscription.image_web.name
}

output "image_storage_account_id" {
  value = azurerm_storage_account.images.id
}

output "image_storage_account_name" {
  value = azurerm_storage_account.images.name
}

output "image_storage_account_url" {
  value = azurerm_storage_account.images.primary_blob_endpoint
}
