terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
  }

  backend "azurerm" {
    # Configure via environment variables:
    # ARM_ENVIRONMENT=usgovernment
    # ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
    # or via backend config file: terraform init -backend-config=backend.conf
    environment          = "usgovernment"
    resource_group_name  = "tactical-arc-tfstate-rg"
    storage_account_name = "tacticalarctfstate"
    container_name       = "tfstate"
    key                  = "tactical-arc.tfstate"
  }
}

provider "azurerm" {
  environment = "usgovernment"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

provider "azuread" {
  environment = "usgovernment"
}
