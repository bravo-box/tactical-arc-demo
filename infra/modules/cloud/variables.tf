variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_prefix" { type = string }
variable "unique_suffix" { type = string }
variable "kubernetes_version" {
  type     = string
  nullable = true
}
variable "node_count" { type = number }
variable "node_vm_size" { type = string }
variable "aks_subnet_id" { type = string }
variable "application_gateway_id" { type = string }
variable "application_gateway_subnet_id" { type = string }
variable "cluster_admin_principal_id" { type = string }
variable "service_cidr" { type = string }
variable "dns_service_ip" { type = string }
variable "workload_identity_namespace" { type = string }
variable "workload_identity_service_account" { type = string }
variable "tags" { type = map(string) }
