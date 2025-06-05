# Configure the Terraform runtime requirements.
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    # Azure Resource Manager provider and version
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

# Define providers and their config params
provider "azurerm" {
  # Leave the features block empty to accept all defaults
  features {}
}

provider "cloudinit" {
  # Configuration options
}
resource "azurerm_resource_group" "main" {
  name     = "${var.labelPrefix}-A05-RG"
  location = var.region
}
resource "azurerm_public_ip" "main" {
  name                = "${var.labelPrefix}-pip"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic"
}
resource "azurerm_virtual_network" "main" {
  name                = "${var.labelPrefix}-vnet"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}
resource "azurerm_subnet" "main" {
  name                 = "${var.labelPrefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_network_security_group" "main" {
  name                = "${var.labelPrefix}-nsg"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

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

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "main" {
  name                = "${var.labelPrefix}-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}
data "cloudinit_config" "config" {
  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/init.sh")
  }
}
resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.labelPrefix}-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.region
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]
  admin_ssh_key {
    username   = var.admin_username
    public_key = file("/Users/mohitsinghpanwar/.ssh/id_rsa.pub")  # adjust path if needed
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "${var.labelPrefix}-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = data.cloudinit_config.config.rendered
}
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "public_ip" {
  value = azurerm_public_ip.main.ip_address
}
