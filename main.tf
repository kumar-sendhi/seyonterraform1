
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
  public_ip = "terra_publicip"
  nsg = {
    name = "terra_nsg"
    security_rule=[
      {
        name = "AllowRDP"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "*"
        destination_address_prefix = "*"
      }
    ]
  }
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
    public_ip_address_id = azurerm_public_ip.terra_publicip.id
  }

  depends_on = [
    azurerm_virtual_network.terravnet,
    azurerm_public_ip.terra_publicip
  ]
}


resource "azurerm_public_ip" "terra_publicip" {
  name                = local.public_ip
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = local.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
  depends_on = [
    azurerm_resource_group.resourcegroup,
    azurerm_virtual_network.terravnet
  ]
}

resource "azurerm_network_security_group" "terra_nsg" {
  name                = local.nsg.name
  location            = local.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  dynamic "security_rule" {
    for_each = local.nsg.security_rule
    content {
      name = security_rule.value["name"]
      priority = security_rule.value["priority"]
      direction = security_rule.value["direction"]
      access = security_rule.value["access"]
      protocol = security_rule.value["protocol"]
      source_port_range = security_rule.value["source_port_range"]
      destination_port_range = security_rule.value["destination_port_range"]
      source_address_prefix = security_rule.value["source_address_prefix"]
      destination_address_prefix = security_rule.value["destination_address_prefix"]
    }
    
  }

  tags = {
    environment = "Production"
  }

  depends_on = [
    azurerm_resource_group.resourcegroup
  ]
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_virtual_network.terravnet.subnet.*.id[0]
  network_security_group_id = azurerm_network_security_group.terra_nsg.id
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_association" {
  network_interface_id = azurerm_network_interface.terra_nic.id
  network_security_group_id = azurerm_network_security_group.terra_nsg.id
}


resource "azurerm_windows_virtual_machine" "terraform_vm" {
  name                = "terra-vm"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = local.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "Abcd1234$"
  network_interface_ids = [
    azurerm_network_interface.terra_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}


resource "azurerm_managed_disk" "appdisk" {
  name                 = "appdisk"
  location             = local.location
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "16"

  tags = {
    environment = "Production"
  }
}


resource "azurerm_virtual_machine_data_disk_attachment" "appdiskattachment" {
  managed_disk_id    = azurerm_managed_disk.appdisk.id
  virtual_machine_id = azurerm_windows_virtual_machine.terraform_vm.id
  lun                = "10"
  caching            = "ReadWrite"
  depends_on = [
    azurerm_windows_virtual_machine.terraform_vm
  ]
}



output "subnet1-id" {
  value = azurerm_virtual_network.terravnet.subnet.*.id[0]
}