variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_prefix" { type = string }
variable "unique_suffix" { type = string }
variable "workload_identity_principal" { type = string }
variable "edge_arc_principal_id" {
  type     = string
  nullable = true
}
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) }
