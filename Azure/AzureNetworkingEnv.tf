# Configure the Azure Provider
locals {
  subscription_id = "Your Subscription ID"
  tenant_id = "Your Tenant Id"
  resource_group_name = "RT#######_CORE"
  location = "East US"
  vm_password = "VM Password"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.57.0" 
    }
   }
}
#Configure the providers
provider "azurerm" {
  subscription_id = local.subscription_id
  tenant_id = local.tenant_id
  skip_provider_registration = "true"
  features {}
}
####################################################
# Create a resource group
# In the lab env, we don't have permissions to create Resource Group. 
# The resource groups are already pre-created for us. 
# So we skip this step. 
#resource "azurerm_resource_group" "example" {
#  name     = "production"
# location = "East US"
#}
####################################################


#######################################################
###  Create VNET, and 2 Subnets (FrontEnd and BackEnd #
#######################################################

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "Primary-VNet" {
  name                = "Primary-VNet"
  resource_group_name = local.resource_group_name
  location            = local.location
  address_space       = ["10.2.0.0/16"]
}


resource "azurerm_subnet" "FrontEnd" {
  name                 = "FrontEnd"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.Primary-VNet.name
  address_prefixes       = ["10.2.0.0/24"]
}
  
  
resource "azurerm_subnet" "BackEnd" {
  name                 = "BackEnd"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.Primary-VNet.name
  address_prefixes       = ["10.2.1.0/24"]
}


#######################################################
###  Create 2 NSGs and attach them to FrontEnd        #
###  and BackEnd subnets                              #
####################################################### 

resource "azurerm_network_security_group" "FrontEnd_NSG" {
  name                = "FrontEnd_NSG"
  location            = local.location 
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "httpRule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "10.2.0.0/24"
  }
  
  security_rule {
    name                       = "rdpRule"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "10.2.0.0/24"
  }
}

resource "azurerm_subnet_network_security_group_association" "FrontEnd_NSG_Association" {
  subnet_id                 = azurerm_subnet.FrontEnd.id
  network_security_group_id = azurerm_network_security_group.FrontEnd_NSG.id
}



resource "azurerm_network_security_group" "BackEnd_NSG" {
  name                = "BackEnd_NSG"
  location            = local.location 
  resource_group_name = local.resource_group_name
}
  
resource "azurerm_subnet_network_security_group_association" "BackEnd_NSG_Association" {
subnet_id                 = azurerm_subnet.BackEnd.id
network_security_group_id = azurerm_network_security_group.BackEnd_NSG.id
} 

###########################################################################
#   Create Windows Jump Host in the FrontEnd Subnet                      ##
###########################################################################

resource "azurerm_public_ip" "W2K16-JumpHost-PublicIp" {
  name                = "W2K16-JumpHost-PublicIp"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "W2K16-JumpHost-Nic1" {
  name                = "W2K16-JumpHost-Nic1"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "windowsconfiguration1"
    subnet_id                     = azurerm_subnet.FrontEnd.id
    private_ip_address_allocation = "Dynamic"
	public_ip_address_id = azurerm_public_ip.W2K16-JumpHost-PublicIp.id
  }
}

resource "azurerm_virtual_machine" "W2K16-JumpHost" {
  name                  = "W2K16-JumpHost"
  resource_group_name   = local.resource_group_name
  location              = local.location
  network_interface_ids = [azurerm_network_interface.W2K16-JumpHost-Nic1.id]
  os_profile_windows_config {
  }
  vm_size               = "Standard_DS2_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "W2K16-JumpHost"
    admin_username = "DemoAdmin"
    admin_password = local.vm_password
  }
  
  #tags = {
  #  environment = "staging"
  #}
}



###########################################################################
#   Create Linux VM in the BackEnd Subnet                                ##
###########################################################################

resource "azurerm_public_ip" "RHEL74-Priv-PublicIp" {
  name                = "RHEL74-Priv-PublicIp"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "RHEL74-Nic1" {
  name                = "RHEL74-Nic1"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "RHEL74configuration1"
    subnet_id                     = azurerm_subnet.BackEnd.id
    private_ip_address_allocation = "Dynamic"
	public_ip_address_id = azurerm_public_ip.RHEL74-Priv-PublicIp.id
  }
}

resource "azurerm_virtual_machine" "RHEL74-Priv" {
  name                  = "RHEL74-Priv"
  resource_group_name   = local.resource_group_name
  location              = local.location
  network_interface_ids = [azurerm_network_interface.RHEL74-Nic1.id]
  os_profile_linux_config {
    disable_password_authentication = false
  }
  vm_size               = "Standard_DS2_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
   delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.4"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "RHEL74-Priv"
    admin_username = "DemoAdmin"
    admin_password = local.vm_password
  }
  
  #tags = {
  #  environment = "staging"
  #}
  
}
