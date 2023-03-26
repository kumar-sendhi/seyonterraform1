terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }
  backend "azurerm" {
    resource_group_name = "databricksRG"
    storage_account_name = "formula1seyondl"
    container_name = "terraformstate"
    key = "terraform.tfstate"
    
  }
}

provider "azurerm" {
  subscription_id = var.subscription
  tenant_id = var.tenant
  client_id = var.client_id
  client_secret = var.client_secret
  features {}
}
