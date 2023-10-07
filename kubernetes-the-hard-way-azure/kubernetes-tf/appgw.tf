# AppGateway
resource "azurerm_subnet" "appgw" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.k8s-rg.name
  virtual_network_name = azurerm_virtual_network.kubernetes_the_hard_way_vnet.name
  address_prefixes     = ["10.240.3.0/24"]

  # bug: https://github.com/hashicorp/terraform-provider-azurerm/pull/12267
  depends_on = [azurerm_subnet.kubernetes]
}

resource "azurerm_subnet_network_security_group_association" "appgw_nsg_association" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.kubernetes_nsg.id

  # bug: https://github.com/hashicorp/terraform-provider-azurerm/pull/12267
  depends_on = [azurerm_subnet_network_security_group_association.kubernetes_nsg_association]
}

resource "azurerm_public_ip" "kubernetes_appgw_ip" {
  name                = "kubernetes-appgw-ip"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  location            = azurerm_resource_group.k8s-rg.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = [1, 2, 3]
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


resource "azurerm_application_gateway" "k8s_appgw" {
  name                = "kubernetes-appgw"
  resource_group_name = azurerm_resource_group.k8s-rg.name
  location            = azurerm_resource_group.k8s-rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "k8s-appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "std-https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "k8s-frontendip-config"
    public_ip_address_id = azurerm_public_ip.kubernetes_appgw_ip.id
  }

  backend_address_pool {
    name         = "k8s-appgw-backend-workerpool"
    ip_addresses = [for i, v in local.workers : "10.240.0.2${v}"]
  }

  backend_http_settings {
    name                  = "regular-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  backend_http_settings { # only for nginx pod
    name                  = "nginx-30080"
    cookie_based_affinity = "Disabled"
    port                  = 30080
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "k8s-frontendip-config"
    frontend_port_name             = "std-https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "kubeworker-sslcert"
  }

  ssl_certificate {
    name     = "kubeworker-sslcert"
    data     = filebase64("certbot-kube-certificate_fullchain.pfx")
    password = random_password.password.result # TODO a keyvault would do...
  }

  request_routing_rule { # for nginx-pod
    name                       = "k8s-workers-tls-offloading"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "k8s-appgw-backend-workerpool"
    backend_http_settings_name = "nginx-30080"
    priority                   = 1001
  }

  depends_on = [azurerm_network_security_rule.AllowsAppGWPorts]
}


data "azurerm_resource_group" "zones_rg" {
  name = "zones-rg"
}

data "azurerm_dns_zone" "irfan-dns-zone" {
  name                = "irfan-k8s.bips.bjsscloud.net"
  resource_group_name = data.azurerm_resource_group.zones_rg.name
}

resource "azurerm_dns_a_record" "kube-cname-to-appgw-ip" {
  name                = "@"
  zone_name           = data.azurerm_dns_zone.irfan-dns-zone.name
  resource_group_name = data.azurerm_resource_group.zones_rg.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.kubernetes_appgw_ip.id
}

resource "azurerm_network_security_rule" "AllowsNGinxNodePort" {
  name                                       = "AllowsNGinxNodePort"
  priority                                   = 104
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "*"
  source_port_range                          = "*"
  destination_port_range                     = "30080"
  source_address_prefix                      = "*"
  resource_group_name                        = azurerm_resource_group.k8s-rg.name
  network_security_group_name                = azurerm_network_security_group.kubernetes_nsg.name
  destination_application_security_group_ids = [azurerm_application_security_group.kubernetes-asg.id]
  description                                = "Ports needed for NGINX to work on worker node"
}







