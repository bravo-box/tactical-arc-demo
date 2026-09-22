output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "application_gateway_subnet_id" {
  value = azurerm_subnet.application_gateway.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "application_gateway_id" {
  value = azurerm_application_gateway.this.id
}

output "application_gateway_public_ip" {
  value = azurerm_public_ip.application_gateway.ip_address
}

output "vpn_gateway_public_ip" {
  value = azurerm_public_ip.vpn.ip_address
}
