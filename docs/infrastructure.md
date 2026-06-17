# Infrastructure

This document describes the Azure Government infrastructure deployed by the Terraform templates in the `infra/` directory.

## Overview

All infrastructure targets **Azure Government** (`usgovernment`) and defaults to the **`usgovarizona`** region.

## Resources Deployed

### Resource Group
A single resource group containing all solution resources, named `<project_name>-<environment>-rg`.

### Virtual Network (networking module)
- **VNet**: `<project>-<env>-vnet` with a configurable address space (default: `10.0.0.0/16`)
- **AKS Subnet**: `<project>-<env>-aks-subnet` (default: `10.0.1.0/24`)

### Azure Container Registry (acr module)
- **SKU**: Standard (configurable)
- **Admin access**: Disabled (uses managed identity)
- **Name format**: `<projectname><env>acr` (alphanumeric only)

### Azure Kubernetes Service (aks module)
- **Identity**: SystemAssigned managed identity
- **RBAC**: Azure AD-integrated with Azure RBAC enabled
- **Network plugin**: Azure CNI
- **Load balancer**: Standard SKU
- **Node pool**: System pool with configurable VM size and count

### Role Assignment
- AKS kubelet identity is granted **AcrPull** on the ACR, enabling image pulls without admin credentials.

## Configuration

Key variables with their defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `usgovarizona` | Azure Government region |
| `environment` | `dev` | Deployment environment |
| `project_name` | `tactical-arc` | Resource name prefix |
| `aks_node_count` | `2` | Initial AKS node count |
| `aks_node_vm_size` | `Standard_D2s_v3` | AKS node VM size |
| `aks_kubernetes_version` | `1.29` | Kubernetes version |
| `acr_sku` | `Standard` | ACR SKU |

Override defaults by creating a `terraform.tfvars` file (excluded from git):

```hcl
location        = "usgovarizona"
environment     = "prod"
project_name    = "tactical-arc"
aks_node_count  = 3
aks_node_vm_size = "Standard_D4s_v3"
```

## Remote State

The Terraform backend is configured for Azure Blob Storage in Azure Government. Before running `terraform init`, create the storage account for state:

```bash
az storage account create \
  --name tacticalarctfstate \
  --resource-group tactical-arc-tfstate-rg \
  --location usgovarizona \
  --sku Standard_LRS \
  --environment AzureUSGovernment

az storage container create \
  --name tfstate \
  --account-name tacticalarctfstate \
  --environment AzureUSGovernment
```

## Authentication

Set the following environment variables before running Terraform:

```bash
export ARM_ENVIRONMENT=usgovernment
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_CLIENT_ID="<service-principal-id>"
export ARM_CLIENT_SECRET="<service-principal-secret>"
```
