output "acr_private_endpoint_id" {
  value = azurerm_private_endpoint.acr.id
}

output "servicebus_private_endpoint_id" {
  value = azurerm_private_endpoint.servicebus.id
}

output "blob_private_endpoint_id" {
  value = azurerm_private_endpoint.blob.id
}

output "cosmos_private_endpoint_id" {
  value = azurerm_private_endpoint.cosmos.id
}
