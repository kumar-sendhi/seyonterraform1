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

  features {}
}


resource "azurerm_resource_group" "resourcegroup" {
  name     = "terraform_app_grp"
  location = "South Central US"
}


resource "azurerm_storage_account" "terraform_storage" {
  name                     = "seyonterraformstg"
  resource_group_name      = azurerm_resource_group.resourcegroup.name
  location                 = azurerm_resource_group.resourcegroup.location
  account_tier             = "Standard"
  account_kind = "StorageV2"
  account_replication_type = "LRS"
  is_hns_enabled = true

  tags = {
    environment = "staging"
  }
  depends_on = [
    azurerm_resource_group.example
  ]
}


resource "azurerm_storage_container" "container" {
  name                  = "raw"
  storage_account_name  = azurerm_storage_account.terraform_storage.name
  container_access_type = "private"
  depends_on = [
    azurerm_storage_account.terraform_storage
  ]
}


resource "azurerm_storage_blob" "blob" {
  name                   = "test.txt"
  storage_account_name   = azurerm_storage_account.terraform_storage.name
  storage_container_name = azurerm_storage_container.container.name
  type                   = "Block"
  source                 = "abcd.txt"
  depends_on = [
    azurerm_storage_container.container
  ]
}