/*
NOTE: This resource is always created (if it doesn't exist already) when
Terraform workspace is changed.
 */
resource "azurerm_resource_group" "this" {
  for_each = (terraform.workspace != local.gitlab_env ? { (terraform.workspace) = "" } : {})
  location = local.region
  name     = "rg-${local.common_name}"
  tags     = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# The resource below is imported and not created
resource "azurerm_user_assigned_identity" "mi_automation_adaptio" {
  for_each            = (terraform.workspace == local.default_env ? { (terraform.workspace) = "" } : {})
  location            = local.region
  name                = "mi-automation-adaptio"
  resource_group_name = azurerm_resource_group.this[local.default_env].name
  lifecycle {
    prevent_destroy = true
  }
}
