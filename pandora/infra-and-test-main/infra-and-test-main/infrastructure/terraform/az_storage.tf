resource "azurerm_storage_account" "default" {
  for_each                 = (terraform.workspace == local.default_env ? { (terraform.workspace) = "" } : {})
  account_replication_type = "RAGZRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this[local.default_env].location
  name                     = "st1${var.project.name}${local.default_env}"
  resource_group_name      = azurerm_resource_group.this[local.default_env].name
  tags                     = local.common_tags

  blob_properties {
    delete_retention_policy {
      days = 365
    }
    restore_policy {
      days = 364
    }
    versioning_enabled            = true
    change_feed_enabled           = true
    change_feed_retention_in_days = 365
    container_delete_retention_policy {
      days = 365
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "default" {
  for_each           = (terraform.workspace == local.default_env ? { (terraform.workspace) = "" } : {})
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.default[local.default_env].id
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "gitlab_runner" {
  for_each                 = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.this[local.dev_env].location
  name                     = "st1${var.project.name}${local.dev_env}"
  resource_group_name      = azurerm_resource_group.this[local.dev_env].name
  tags                     = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "gitlab_runner_cache" {
  for_each           = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name               = "gitlab-runner-cache"
  storage_account_id = azurerm_storage_account.gitlab_runner[local.dev_env].id
}

resource "azurerm_storage_container" "developer_container" {
  for_each              = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                  = "adaptio-dev"
  storage_account_id    = azurerm_storage_account.gitlab_runner[local.dev_env].id
  container_access_type = "private"
}

data "azurerm_storage_account_blob_container_sas" "developer_container_sas" {
  for_each          = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  connection_string = azurerm_storage_account.gitlab_runner[local.dev_env].primary_connection_string
  container_name    = azurerm_storage_container.developer_container[local.dev_env].name
  expiry            = "2027-03-05"
  start             = "2025-03-05"

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}
