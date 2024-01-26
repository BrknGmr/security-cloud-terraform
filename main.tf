#groupe de ressource

resource "azurerm_resource_group" "rg" {
  name     = "myRG_Neav"
  location = "East US"
}

#réseau virtuel

resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.21.0.0/16"]
}

#sous-réseau 

resource "azurerm_subnet" "frontend" {
  name                 = "myAGSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.21.0.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "myBackendSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.21.1.0/24"]
}

#adresse IP azure publique

resource "azurerm_public_ip" "pip" {
  name                = "myAGPublicIPAddress"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

#stratégie WAF 

resource "azurerm_web_application_firewall_policy" "example_waf_policy" {
  name                = "ag-waf-pol"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  managed_rules {
    exclusion {
      match_variable          = "RequestHeaderNames"
      selector_match_operator = "Equals"
      selector                = "User-Agent"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
    }
  }
}

#Passerelle d'application 

resource "azurerm_application_gateway" "main" {
  name                = "myAppGateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = var.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = var.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  backend_address_pool {
    name = var.backend_address_pool_name
    ip_addresses = [
      azurerm_linux_virtual_machine.myVM1.private_ip_address,
      azurerm_linux_virtual_machine.myVM2.private_ip_address,
    ]
  }

  backend_http_settings {
    name                  = var.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = var.listener_name
    frontend_ip_configuration_name = var.frontend_ip_configuration_name
    frontend_port_name             = var.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = var.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = var.listener_name
    backend_address_pool_name  = var.backend_address_pool_name
    backend_http_settings_name = var.http_setting_name
    priority                   = 10
  }

  waf_configuration {
    enabled = true
    firewall_mode = "Prevention"
    rule_set_type = "OWASP"
    rule_set_version = "3.1"
  }
}

#Création VM 

resource "azurerm_linux_virtual_machine" "myVM1" {
  name                = "myVM1Neav"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Password123*"
  network_interface_ids = [azurerm_network_interface.myVM1_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  disable_password_authentication = false
}

resource "azurerm_network_interface" "myVM1_nic" {
  name                = "myVM1NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "myVM2" {
  name                = "myVM2Neav"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "Password123*"
  network_interface_ids = [azurerm_network_interface.myVM2_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  disable_password_authentication = false
}

resource "azurerm_network_interface" "myVM2_nic" {
  name                = "myVM2NIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}

