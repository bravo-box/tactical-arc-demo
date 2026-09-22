resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-private-endpoints-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_group" "application_gateway" {
  name                = "nsg-appgw-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsFromInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-bastion-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostCommunicationInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionHostCommunicationOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHttpOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet" "application_gateway" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.application_gateway_prefix]
}

resource "azurerm_subnet_network_security_group_association" "application_gateway" {
  subnet_id                 = azurerm_subnet.application_gateway.id
  network_security_group_id = azurerm_network_security_group.application_gateway.id
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.private_endpoint_prefix]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "this" {
  name                   = "bas-tactical-demo"
  location               = azurerm_resource_group.this.location
  resource_group_name    = azurerm_resource_group.this.name
  sku                    = "Standard"
  copy_paste_enabled     = true
  file_copy_enabled      = false
  ip_connect_enabled     = true
  shareable_link_enabled = false
  tunneling_enabled      = true
  tags                   = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_public_ip" "vpn" {
  name                = "pip-vpn-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = "vpng-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  bgp_enabled         = false
  sku                 = var.vpn_gateway_sku
  generation          = "Generation2"
  tags                = var.tags

  ip_configuration {
    name                          = "vpn-gateway-ip-config"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space        = var.vpn_client_address_space
    vpn_client_protocols = ["OpenVPN"]
    aad_tenant           = "https://login.microsoftonline.us/${var.tenant_id}/"
    aad_audience         = "https://azurevpn-usgov.msidentityvpn.msidentity.com"
    aad_issuer           = "https://sts.windows.net/${var.tenant_id}/"
  }
}

resource "azurerm_local_network_gateway" "edge" {
  count = var.edge_vpn_enabled ? 1 : 0

  name                = "lng-edge"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  gateway_address     = var.edge_gateway_address
  address_space       = var.edge_address_spaces
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.edge_gateway_address != null && length(var.edge_address_spaces) > 0
      error_message = "edge_gateway_address and edge_address_spaces are required when edge_vpn_enabled is true."
    }
  }
}

resource "azurerm_virtual_network_gateway_connection" "edge" {
  count = var.edge_vpn_enabled ? 1 : 0

  name                       = "conn-edge-ipsec"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.edge[0].id
  shared_key                 = var.edge_shared_key
  tags                       = var.tags

  lifecycle {
    precondition {
      condition     = var.edge_shared_key != null
      error_message = "edge_shared_key is required when edge_vpn_enabled is true."
    }
  }
}

resource "azurerm_public_ip" "application_gateway" {
  name                = "pip-appgw-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "application_gateway" {
  name                = "id-appgw-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "application_gateway_key_vault" {
  scope                = var.application_gateway_key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.application_gateway.principal_id
}

resource "azurerm_application_gateway" "this" {
  name                = "agw-tactical-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  zones               = ["1", "2", "3"]
  http2_enabled       = true
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.application_gateway.id]
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 3
  }

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.application_gateway.id
  }

  frontend_port {
    name = "https"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.application_gateway.id
  }

  backend_address_pool {
    name = "default"
  }

  backend_http_settings {
    name                  = "default"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = "https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "application"
  }

  ssl_certificate {
    name                = "application"
    key_vault_secret_id = var.application_gateway_certificate_secret_id
  }

  request_routing_rule {
    name                       = "default"
    rule_type                  = "Basic"
    http_listener_name         = "https"
    backend_address_pool_name  = "default"
    backend_http_settings_name = "default"
    priority                   = 100
  }

  waf_configuration {
    enabled                  = true
    firewall_mode            = "Prevention"
    rule_set_type            = "OWASP"
    rule_set_version         = "3.2"
    file_upload_limit_mb     = 100
    max_request_body_size_kb = 128
    request_body_check       = true
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      rewrite_rule_set,
      url_path_map
    ]
  }
}
