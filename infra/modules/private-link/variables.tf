variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "vnet_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "container_registry_id" { type = string }
variable "servicebus_namespace_id" { type = string }
variable "storage_account_id" { type = string }
variable "tags" { type = map(string) }
