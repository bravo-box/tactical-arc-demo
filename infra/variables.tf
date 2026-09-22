variable "azure_environment" {
  description = "Azure cloud environment for the AzureRM provider."
  type        = string
  default     = "usgovernment"

  validation {
    condition     = var.azure_environment == "usgovernment"
    error_message = "This solution is configured for Azure Government; azure_environment must be usgovernment."
  }
}

variable "subscription_id" {
  description = "Azure Government subscription ID. Null uses the active Azure CLI subscription."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Lowercase prefix used for globally scoped and workload resource names."
  type        = string
  default     = "tacticalarc"

  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "name_prefix must be 3-12 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment tag applied to all resources."
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure Government region for regional resources."
  type        = string
  default     = "usgovvirginia"
}

variable "vnet_address_space" {
  description = "Address space for the shared virtual network."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Address prefix for AKS nodes and Azure CNI pods."
  type        = string
  default     = "10.40.0.0/20"
}

variable "application_gateway_subnet_prefix" {
  description = "Dedicated Application Gateway subnet prefix."
  type        = string
  default     = "10.40.16.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "Dedicated private endpoint subnet prefix."
  type        = string
  default     = "10.40.17.0/24"
}

variable "gateway_subnet_prefix" {
  description = "VPN GatewaySubnet prefix; must be /27 or larger."
  type        = string
  default     = "10.40.18.0/27"
}

variable "bastion_subnet_prefix" {
  description = "AzureBastionSubnet prefix; must be /26 or larger."
  type        = string
  default     = "10.40.18.64/26"
}

variable "vpn_client_address_space" {
  description = "Nonoverlapping address pool for point-to-site VPN clients."
  type        = list(string)
  default     = ["172.20.0.0/24"]
}

variable "vpn_gateway_sku" {
  description = "Route-based VPN Gateway SKU."
  type        = string
  default     = "VpnGw1AZ"
}

variable "application_gateway_key_vault_id" {
  description = "ARM resource ID of the Key Vault containing the Application Gateway TLS certificate."
  type        = string
}

variable "application_gateway_certificate_secret_id" {
  description = "Versionless Key Vault secret ID for the Application Gateway TLS certificate."
  type        = string
}

variable "edge_vpn_enabled" {
  description = "Create the optional site-to-site IPsec connection for the edge network."
  type        = bool
  default     = false
}

variable "edge_gateway_address" {
  description = "Public IPv4 address of the edge VPN device."
  type        = string
  default     = null
  nullable    = true
}

variable "edge_address_spaces" {
  description = "Private CIDR ranges behind the edge VPN device."
  type        = list(string)
  default     = []
}

variable "edge_shared_key" {
  description = "IPsec pre-shared key for the optional edge site-to-site connection."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Null selects the region default."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Initial AKS system node count."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 2
    error_message = "node_count must be at least 2."
  }
}

variable "node_vm_size" {
  description = "VM size for the AKS system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_service_cidr" {
  description = "Kubernetes service CIDR; must not overlap the VNet or VPN client pool."
  type        = string
  default     = "10.41.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "Kubernetes DNS service IP inside aks_service_cidr."
  type        = string
  default     = "10.41.0.10"
}

variable "workload_identity_namespace" {
  description = "Kubernetes namespace for the telemetry workload identity."
  type        = string
  default     = "tactical-demo"
}

variable "workload_identity_service_account" {
  description = "Kubernetes service account federated to the telemetry managed identity."
  type        = string
  default     = "telemetry-api"
}

variable "edge_arc_principal_id" {
  description = "Optional principal ID of an Arc-enabled edge device identity granted Service Bus send access."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Additional tags merged with required environment, workload, and managed-by tags."
  type        = map(string)
  default = {
    project = "tactical-arc-demo"
  }
}
