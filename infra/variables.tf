variable "azure_environment" {
  description = "Azure cloud environment for the AzureRM provider. Azure Government is the default for this demo."
  type        = string
  default     = "usgovernment"

  validation {
    condition     = contains(["public", "usgovernment", "china"], var.azure_environment)
    error_message = "azure_environment must be one of: public, usgovernment, china."
  }
}

variable "subscription_id" {
  description = "Azure Government subscription ID to deploy into. Defaults to the Azure CLI's active subscription when null."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix used for all resource names."
  type        = string
  default     = "tacticalarc"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "name_prefix must be 3-12 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure Government region for the resources."
  type        = string
  default     = "usgovvirginia"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Null selects the region default."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Number of nodes in the AKS default node pool."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "node_vm_size" {
  description = "VM size for the AKS default node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project = "tactical-arc-demo"
  }
}
