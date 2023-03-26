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

locals {
  resource_group_name="terraform_res_grp"
  location="South Central US"
  storage_account_name="seyonterraformstg"
  container_name="raw"
  virtual_network = {
    name="terraform-network"
    address_space = "172.16.0.0/16"
    subnet=[{
      name="subnet1"
      address_prefix="172.16.1.0/24"
    },{
      name="subnet2"
      address_prefix="172.16.2.0/24"
    }]
  }
  nic = "terra_nic"
}


resource "azurerm_resource_group" "resourcegroup" {
  name     = local.resource_group_name
  location = local.location
}


resource "azurerm_storage_account" "terraform_storage" {
  name                     = local.storage_account_name
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
    azurerm_resource_group.resourcegroup
  ]
}


resource "azurerm_storage_container" "container" {
  name                  = local.container_name
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


resource "azurerm_virtual_network" "terravnet" {
  name                = local.virtual_network.name
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  address_space       = [local.virtual_network.address_space]

  
  dynamic "subnet" {
    for_each = local.virtual_network.subnet
    content {
      name = subnet.value["name"]
      address_prefix = subnet.value["address_prefix"]
    }

  }  

/*   subnet {
    address_prefix = local.virtual_network.subnet[0].address_prefix
    name = local.virtual_network.subnet[0].name
  }
  subnet {
    address_prefix = local.virtual_network.subnet[1].address_prefix
    name = local.virtual_network.subnet[1].name
  } */
   

  tags = {
    environment = "Production"
  }
  depends_on = [
    azurerm_resource_group.resourcegroup
  ]
}


resource "azurerm_network_interface" "terra_nic" {
  name                = local.nic
  location            = local.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_virtual_network.terravnet.subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_virtual_network.terravnet
  ]
}