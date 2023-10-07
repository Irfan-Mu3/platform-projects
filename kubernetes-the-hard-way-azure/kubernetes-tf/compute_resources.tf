locals {
  resource_group_name = "irfan-rg"
  location            = "uksouth"
  controllers         = ["0"]
  workers             = ["0"]
}

resource "azurerm_resource_group" "k8s-rg" {
  name     = local.resource_group_name
  location = local.location
  tags = {
    Name = "kubernetes-the-hard-way"
  }
}


resource "azurerm_virtual_network" "kubernetes_the_hard_way_vnet" {
  name                = "kubernetes-the-hard-way-vnet"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  address_space       = ["10.240.0.0/16"]

  location = local.location
}

resource "azurerm_subnet" "kubernetes" {
  name                 = "kubernetes"
  resource_group_name  = azurerm_resource_group.k8s-rg.name
  virtual_network_name = azurerm_virtual_network.kubernetes_the_hard_way_vnet.name
  address_prefixes     = ["10.240.0.0/24"]
}

resource "azurerm_application_security_group" "kubernetes-asg" {
  name                = "kubernetes-asg"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  location            = local.location
}



resource "azurerm_subnet_network_security_group_association" "kubernetes_nsg_association" {
  subnet_id                 = azurerm_subnet.kubernetes.id
  network_security_group_id = azurerm_network_security_group.kubernetes_nsg.id
}

resource "azurerm_network_security_rule" "AllowsICMP" {
  name                                       = "AllowsICMP"
  priority                                   = 100
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Icmp"
  source_port_range                          = "*"
  destination_port_range                     = "*"
  source_address_prefix                      = "*"
  resource_group_name                        = azurerm_resource_group.k8s-rg.name
  network_security_group_name                = azurerm_network_security_group.kubernetes_nsg.name
  destination_application_security_group_ids = [azurerm_application_security_group.kubernetes-asg.id]
  description                                = "Allow Internet to use ICMP with vms attached to the kubernetes-asg"
}

resource "azurerm_network_security_rule" "AllowsTCP6443" {
  name                                       = "AllowsTCP6443"
  priority                                   = 101
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "6443"
  source_address_prefix                      = "*"
  resource_group_name                        = azurerm_resource_group.k8s-rg.name
  network_security_group_name                = azurerm_network_security_group.kubernetes_nsg.name
  destination_application_security_group_ids = [azurerm_application_security_group.kubernetes-asg.id]
  description                                = "Allow Internet to use TCP 6443 (for kube-apiserver)"
}

resource "azurerm_network_security_rule" "AllowsSSH" {
  name                                       = "AllowsSSH"
  priority                                   = 102
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "22"
  source_address_prefix                      = "*"
  resource_group_name                        = azurerm_resource_group.k8s-rg.name
  network_security_group_name                = azurerm_network_security_group.kubernetes_nsg.name
  destination_application_security_group_ids = [azurerm_application_security_group.kubernetes-asg.id]
  description                                = "Allow Internet to use SSH"
}

resource "azurerm_network_security_rule" "AllowsAppGWPorts" {
  name                        = "AllowsAppGWPorts"
  priority                    = 103
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "*"
  resource_group_name         = azurerm_resource_group.k8s-rg.name
  network_security_group_name = azurerm_network_security_group.kubernetes_nsg.name
  destination_address_prefix  = "*"
  description                 = "Ports needed for AppGw V2"
}

resource "azurerm_public_ip" "kubernetes_the_hard_way_ip" {
  name                = "kubernetes-the-hard-way-ip"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  location            = azurerm_resource_group.k8s-rg.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = [1, 2, 3]
}

resource "null_resource" "ssh_keygen_for_controllers" {
  count = length(local.controllers)

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ssh-keygen -m PEM -t rsa -b 2048 -f ~/.ssh/id_rsa_controller-${count.index}  -q -N '' <<< n; exit 0"
  }
}

resource "null_resource" "ssh_keygen_for_workers" {
  count = length(local.workers)

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "ssh-keygen -m PEM -t rsa -b 2048 -f ~/.ssh/id_rsa_worker-${count.index}  -q -N '' <<< n; exit 0"
  }
}

data "local_file" "ssh_pub_keys_for_controllers" {
  count      = length(local.controllers)
  filename   = "/home/irfan/.ssh/id_rsa_controller-${count.index}.pub"
  depends_on = [null_resource.ssh_keygen_for_controllers]
}

data "local_file" "ssh_pub_keys_for_workers" {
  count      = length(local.workers)
  filename   = "/home/irfan/.ssh/id_rsa_worker-${count.index}.pub"
  depends_on = [null_resource.ssh_keygen_for_workers]
}

resource "azurerm_network_interface" "controllers" {
  count                = length(local.controllers)
  name                 = "kubernetes-nic-controller-${count.index}"
  location             = local.location
  resource_group_name  = local.resource_group_name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.kubernetes.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.1${count.index}"
    primary                       = true
  }
}

resource "azurerm_network_interface" "workers" {
  count = length(local.workers)

  name                 = "kubernetes-nic-worker-${count.index}"
  location             = local.location
  resource_group_name  = local.resource_group_name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.kubernetes.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.240.0.2${count.index}"
    primary                       = true
  }
}

resource "azurerm_network_interface_application_security_group_association" "controllers" {
  count                         = length(local.controllers)
  network_interface_id          = azurerm_network_interface.controllers[count.index].id
  application_security_group_id = azurerm_application_security_group.kubernetes-asg.id
}

resource "azurerm_network_interface_application_security_group_association" "workers" {
  count                         = length(local.workers)
  network_interface_id          = azurerm_network_interface.workers[count.index].id
  application_security_group_id = azurerm_application_security_group.kubernetes-asg.id
}

resource "azurerm_linux_virtual_machine" "controllers" {
  count                           = length(local.controllers)
  name                            = "controller-${local.controllers[count.index]}"
  location                        = local.location
  resource_group_name             = local.resource_group_name
  size                            = "Standard_D2s_v3"
  disable_password_authentication = true
  admin_username                  = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.controllers[count.index].id
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
    public_key = data.local_file.ssh_pub_keys_for_controllers[count.index].content
  }

}


resource "azurerm_linux_virtual_machine" "workers" {
  count = length(local.workers)

  name                            = "worker-${count.index}"
  location                        = local.location
  resource_group_name             = local.resource_group_name
  size                            = "Standard_D2s_v3"
  disable_password_authentication = true
  admin_username                  = "azureuser"
  user_data = base64encode(jsonencode({
    pod_cidr = "10.200.${local.workers[count.index]}.0/24"
  }))

  network_interface_ids = [
    azurerm_network_interface.workers[count.index].id
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
    public_key = data.local_file.ssh_pub_keys_for_workers[count.index].content
  }

}


resource "azurerm_lb" "kubernetes_lb" {
  name                = "kubernetes-lb"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  location            = local.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "kubernetes-lb-frontend"
    public_ip_address_id = azurerm_public_ip.kubernetes_the_hard_way_ip.id
  }

}

resource "azurerm_lb_backend_address_pool" "lb_controller_backendpool" {
  loadbalancer_id = azurerm_lb.kubernetes_lb.id
  name            = "kubernetes-lb-backendpool"
}

resource "azurerm_lb_probe" "kubernetes_hp" {
  name            = "kubernetes-hp"
  loadbalancer_id = azurerm_lb.kubernetes_lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_rule" "allows_http" {
  name                           = "AllowsHttp"
  loadbalancer_id                = azurerm_lb.kubernetes_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "kubernetes-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_controller_backendpool.id]
  probe_id                       = azurerm_lb_probe.kubernetes_hp.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 15
  enable_tcp_reset               = true
}

resource "azurerm_network_security_group" "kubernetes_nsg" {
  name                = "kubernetes-nsg"
  location            = local.location
  resource_group_name = azurerm_resource_group.k8s-rg.name
}

resource "azurerm_network_security_rule" "allows_http" {
  name                        = "allowsHttp"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.k8s-rg.name
  network_security_group_name = azurerm_network_security_group.kubernetes_nsg.name
}

resource "azurerm_network_security_rule" "allows_https" {
  name                        = "allowsHttps"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.k8s-rg.name
  network_security_group_name = azurerm_network_security_group.kubernetes_nsg.name
}



resource "azurerm_lb_rule" "allows_kube_https" {
  name                           = "AllowsKubeHttps"
  loadbalancer_id                = azurerm_lb.kubernetes_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "kubernetes-lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_controller_backendpool.id]
  probe_id                       = azurerm_lb_probe.kubernetes_hp.id
  disable_outbound_snat          = true
  idle_timeout_in_minutes        = 15
  enable_tcp_reset               = true
}

resource "azurerm_network_interface_backend_address_pool_association" "backendpool_association_for_controllers" {
  count = length(local.controllers)

  network_interface_id    = azurerm_network_interface.controllers[count.index].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_controller_backendpool.id
}

resource "azurerm_lb_backend_address_pool" "lb_workerpool" {
  name            = "kubernetes-lb-workerpool"
  loadbalancer_id = azurerm_lb.kubernetes_lb.id
}

resource "azurerm_network_interface_backend_address_pool_association" "backendpool_association_for_workers" {
  count = length(local.workers)

  network_interface_id    = azurerm_network_interface.workers[count.index].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_workerpool.id
}

resource "azurerm_public_ip" "kubernetes_natgw_ip" {
  name                = "kubernetes-natgw-ip"
  location            = azurerm_resource_group.k8s-rg.location
  resource_group_name = azurerm_resource_group.k8s-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  # nat gateway only allows one zone
}

//noinspection MissingProperty
resource "azurerm_lb_nat_rule" "kubernetes_inboundnat_direct_ssh" {
  name                           = "kubernetes-inboundnat-direct-ssh"
  resource_group_name            = azurerm_resource_group.k8s-rg.name
  loadbalancer_id                = azurerm_lb.kubernetes_lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 500
  frontend_port_end              = 607
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.kubernetes_lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_controller_backendpool.id
}

//noinspection MissingProperty
resource "azurerm_lb_nat_rule" "kubernetes_inboundnat_direct_ssh_workers" {
  name                           = "kubernetes-inboundnat-direct-ssh-workers"
  resource_group_name            = azurerm_resource_group.k8s-rg.name
  loadbalancer_id                = azurerm_lb.kubernetes_lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 609
  frontend_port_end              = 700
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.kubernetes_lb.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_workerpool.id
}

resource "azurerm_nat_gateway" "kubernetes_natgw" {
  name                    = "kubernetes-natgw"
  location                = azurerm_resource_group.k8s-rg.location
  resource_group_name     = azurerm_resource_group.k8s-rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "kubernetes_natgw_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.kubernetes_natgw.id
  public_ip_address_id = azurerm_public_ip.kubernetes_natgw_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "kubernetes_natgw_subnet_assoc" {
  subnet_id      = azurerm_subnet.kubernetes.id
  nat_gateway_id = azurerm_nat_gateway.kubernetes_natgw.id
}
