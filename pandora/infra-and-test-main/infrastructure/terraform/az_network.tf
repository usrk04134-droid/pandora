resource "azurerm_virtual_network" "this" {
  for_each            = (terraform.workspace == local.default_env ? { (terraform.workspace) = "" } : {})
  address_space       = [var.vnet_config.address_space]
  location            = azurerm_resource_group.this[local.default_env].location
  name                = "vnet-${local.common_name}"
  resource_group_name = azurerm_resource_group.this[local.default_env].name
  tags                = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "this" {
  for_each             = terraform.workspace == local.default_env ? var.subnet_config : {}
  address_prefixes     = [each.value]
  name                 = "snet-${var.department.name}-${var.project.name}-${each.key}-${local.pretty-region}"
  resource_group_name  = azurerm_resource_group.this[local.default_env].name
  virtual_network_name = azurerm_virtual_network.this[local.default_env].name
}

resource "azurerm_virtual_network" "vnet_2" {
  for_each            = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                = "vnet-${var.project.name}-${terraform.workspace}-2"
  location            = azurerm_resource_group.this[local.dev_env].location
  resource_group_name = azurerm_resource_group.this[local.dev_env].name
  address_space       = ["10.42.0.0/16"]
  tags                = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "aks_subnet_2" {
  for_each             = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                 = "snet-aks-${var.project.name}-${terraform.workspace}-2"
  resource_group_name  = azurerm_resource_group.this[local.dev_env].name
  virtual_network_name = azurerm_virtual_network.vnet_2[local.dev_env].name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_public_ip" "nat_eip_2" {
  for_each            = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                = "pip-nat-${var.project.name}-${terraform.workspace}-2"
  location            = azurerm_resource_group.this[local.dev_env].location
  resource_group_name = azurerm_resource_group.this[local.dev_env].name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "aks_nat_2" {
  for_each                = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                    = "ngw-${var.project.name}-${terraform.workspace}-2"
  location                = azurerm_resource_group.this[local.dev_env].location
  resource_group_name     = azurerm_resource_group.this[local.dev_env].name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_subnet_nat_gateway_association" "aks_subnet_nat_2" {
  for_each       = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  subnet_id      = azurerm_subnet.aks_subnet_2[local.dev_env].id
  nat_gateway_id = azurerm_nat_gateway.aks_nat_2[local.dev_env].id
}

resource "azurerm_nat_gateway_public_ip_association" "aks_nat_pip_assoc_2" {
  for_each             = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  nat_gateway_id       = azurerm_nat_gateway.aks_nat_2[local.dev_env].id
  public_ip_address_id = azurerm_public_ip.nat_eip_2[local.dev_env].id
}
