variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_prefix" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "aks_subnet_prefix" { type = string }
variable "application_gateway_prefix" { type = string }
variable "private_endpoint_prefix" { type = string }
variable "gateway_subnet_prefix" { type = string }
variable "bastion_subnet_prefix" { type = string }
variable "vpn_client_address_space" { type = list(string) }
variable "tenant_id" { type = string }
variable "vpn_gateway_sku" { type = string }
variable "application_gateway_key_vault_id" { type = string }
variable "application_gateway_certificate_secret_id" { type = string }
variable "edge_vpn_enabled" { type = bool }
variable "edge_gateway_address" {
  type     = string
  nullable = true
}
variable "edge_address_spaces" { type = list(string) }
variable "edge_shared_key" {
  type      = string
  nullable  = true
  sensitive = true
}
variable "tags" { type = map(string) }
