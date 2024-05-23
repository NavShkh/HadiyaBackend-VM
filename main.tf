terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.104.2"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vmrg" {
  name     = "vmrg"
  location = "Central India"
}


resource "azurerm_virtual_network" "vmvnet" {
  name                = "VM-Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name
}

resource "azurerm_subnet" "VMsubnet" {
  name                 = "VMSubnet"
  resource_group_name  = azurerm_resource_group.vmrg.name
  virtual_network_name = azurerm_virtual_network.vmvnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "VMnsg" {
  name                = "VMNsg"
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "vmip" {
  name                = "vmip"
  resource_group_name = azurerm_resource_group.vmrg.name
  location            = azurerm_resource_group.vmrg.location
  allocation_method   = "Static"
  }

resource "azurerm_network_interface" "VMnic" {
  name                = "VMNIC"
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name

  ip_configuration {
    name                          = "VMNicConfiguration"
    subnet_id                     = azurerm_subnet.VMsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vmip.id
  }

   depends_on = [
      azurerm_virtual_network.vmvnet,
      azurerm_public_ip.vmip
    ]

}

resource "azurerm_network_interface_security_group_association" "VMnic_nsg_association" {
  network_interface_id      = azurerm_network_interface.VMnic.id
  network_security_group_id = azurerm_network_security_group.VMnsg.id
}


resource "azurerm_managed_disk" "VMdata_disk" {
  name                 = "VM-DataDisk"
  location             = azurerm_resource_group.vmrg.location
  resource_group_name  = azurerm_resource_group.vmrg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}


resource "azurerm_linux_virtual_machine" "VM" {
  name                  = "VM"
  location              = azurerm_resource_group.vmrg.location
  resource_group_name   = azurerm_resource_group.vmrg.name
  network_interface_ids = [azurerm_network_interface.VMnic.id]
  size                  = "Standard_B1s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  computer_name                   = "VM"
  admin_username                  = "nav"
  admin_password                  = "Azurepass@321"
  disable_password_authentication = false
}


resource "azurerm_virtual_machine_data_disk_attachment" "VMdata_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.VMdata_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.VM.id
  lun                = 0
  caching            = "ReadWrite"
}

output "public_ip_address" {
  value = azurerm_public_ip.vmip.ip_address
}