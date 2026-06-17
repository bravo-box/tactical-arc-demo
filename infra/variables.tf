variable "location" {
  description = "Azure Government region to deploy resources into"
  type        = string
  default     = "usgovarizona"
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Short project name used to prefix resource names"
  type        = string
  default     = "tactical-arc"
}

variable "resource_group_name" {
  description = "Name of the resource group for all solution resources"
  type        = string
  default     = ""
}

variable "aks_node_count" {
  description = "Initial number of nodes in the AKS system node pool"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry (must be Premium for private link)"
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Premium"], var.acr_sku)
    error_message = "acr_sku must be Premium to support private link"
  }
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "storage_subnet_prefix" {
  description = "Address prefix for the storage private endpoint subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "registry_subnet_prefix" {
  description = "Address prefix for the container registry private endpoint subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "tactical-arc-demo"
    managed_by  = "terraform"
    cloud       = "azure-government"
  }
}
