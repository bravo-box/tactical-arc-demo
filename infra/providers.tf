terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# Authentication is performed with the Azure CLI user credentials
# (`az cloud set --name AzureUSGovernment && az login`).
provider "azurerm" {
  features {}

  environment     = var.azure_environment
  subscription_id = var.subscription_id
  use_cli         = true
}
