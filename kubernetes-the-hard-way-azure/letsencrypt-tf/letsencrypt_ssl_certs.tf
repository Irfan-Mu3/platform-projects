locals {
  resource_group_name = "irfan-certbot-rg"
  location            = "uksouth"
}

resource azurerm_resource_group "certbot-rg" {
  name = local.resource_group_name
  location = local.location
}

resource azurerm_virtual_network "certbot-vnet" {
  name                = "kubernetes-the-hard-way-vnet"
  resource_group_name = azurerm_resource_group.certbot-rg.name
  address_space       = ["10.100.0.0/16"]
  location            = azurerm_resource_group.certbot-rg.location
}

resource "azurerm_subnet" "certbot" {
  name                 = "certbot"
  resource_group_name  = azurerm_resource_group.certbot-rg.name
  virtual_network_name = azurerm_virtual_network.certbot-vnet.name
  address_prefixes     = ["10.100.0.0/24"]
}

resource "azurerm_network_security_group" "certbot-nsg" {
  name                = "certbot-nsg"
  location            = azurerm_resource_group.certbot-rg.location
  resource_group_name = azurerm_resource_group.certbot-rg.name
}

resource azurerm_application_security_group "certbot_asg" {
  name                = "certbot-asg"
  resource_group_name = azurerm_resource_group.certbot-rg.name
  location            = azurerm_resource_group.certbot-rg.location
}

resource "azurerm_public_ip" "kubernetes_the_hard_way_certbot_ip" {
  name                = "kubernetes-the-hard-way-certbot-ip"
  resource_group_name = azurerm_resource_group.certbot-rg.name
  location            = azurerm_resource_group.certbot-rg.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = [1, 2, 3]
}

resource "azurerm_subnet_network_security_group_association" "certbot_nsg_association" {
  subnet_id                 = azurerm_subnet.certbot.id
  network_security_group_id = azurerm_network_security_group.certbot-nsg.id
}

resource "azurerm_network_interface" "certbot" {
  name                 = "kubernetes-nic-certbot"
  location             = azurerm_resource_group.certbot-rg.location
  resource_group_name  = azurerm_resource_group.certbot-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.certbot.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.100.0.10"
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.kubernetes_the_hard_way_certbot_ip.id
  }
}

resource "azurerm_network_interface_application_security_group_association" "certbot" {
  network_interface_id          = azurerm_network_interface.certbot.id
  application_security_group_id = azurerm_application_security_group.certbot_asg.id
}

resource "null_resource" "ssh_keygen_for_certbot" {

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ssh-keygen -m PEM -t rsa -b 2048 -f ~/.ssh/id_rsa_certbot  -q -N '' <<< n; exit 0"
  }
}

data "local_file" "ssh_pub_keys_for_certbot" {
  filename   = "/home/irfan/.ssh/id_rsa_certbot.pub"
  depends_on = [null_resource.ssh_keygen_for_certbot]
}

resource "azurerm_linux_virtual_machine" "certbot" {
  name                            = "certbot"
  location                        = azurerm_resource_group.certbot-rg.location
  resource_group_name             = azurerm_resource_group.certbot-rg.name
  size                            = "Standard_D2s_v3"
  disable_password_authentication = true
  admin_username                  = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.certbot.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = data.local_file.ssh_pub_keys_for_certbot.content
  }

}


