resource "azurerm_route_table" "k8s-rt" {
  name                          = "k8s-rt"
  location                      = azurerm_resource_group.k8s-rg.location
  resource_group_name           = azurerm_resource_group.k8s-rg.name
  disable_bgp_route_propagation = false
}

resource "azurerm_subnet_route_table_association" "k8s-subnet-rt-assoc" {
  subnet_id      = azurerm_subnet.kubernetes.id
  route_table_id = azurerm_route_table.k8s-rt.id
}

resource "azurerm_route" "k8s-loopback-workers" {
  count                  = length(local.workers)
  name                   = "kubernetes-route-10-200-${count.index}-0-24"
  resource_group_name    = azurerm_resource_group.k8s-rg.name
  route_table_name       = azurerm_route_table.k8s-rt.name
  address_prefix         = "10.200.${count.index}.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.240.0.2${count.index}"
}

