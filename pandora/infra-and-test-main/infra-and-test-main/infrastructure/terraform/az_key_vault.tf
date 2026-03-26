resource "random_string" "vault_suffix" {
  for_each  = (terraform.workspace != local.gitlab_env ? { (terraform.workspace) = "" } : {})
  length    = 3
  lower     = true
  min_lower = 3
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  for_each            = (terraform.workspace != local.gitlab_env ? { (terraform.workspace) = "" } : {})
  location            = azurerm_resource_group.this[terraform.workspace].location
  name                = "kv-${var.project.name}-${terraform.workspace}-${random_string.vault_suffix[terraform.workspace].result}"
  resource_group_name = azurerm_resource_group.this[terraform.workspace].name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags

  dynamic "access_policy" {
    for_each = local.godzilla_member_map
    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = access_policy.value
      secret_permissions = [
        "Backup",
        "Delete",
        "Get",
        "List",
        "Purge",
        "Recover",
        "Restore",
        "Set"
      ]
      key_permissions = [
        "Backup",
        "Create",
        "Decrypt",
        "Encrypt",
        "Get",
        "GetRotationPolicy",
        "List",
        "Recover",
        "Restore",
        "SetRotationPolicy",
        "Update"
      ]
    }
  }

  dynamic "access_policy" {
    for_each = (terraform.workspace == local.dev_env) ? local.titanus_member_map : {}
    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = access_policy.value
      secret_permissions = [
        "Get",
        "List",
        "Set"
      ]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "default_st_primary_access_key" {
  for_each     = (terraform.workspace == local.default_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.default_env].id
  name         = "default-storage-account-key"
  value        = azurerm_storage_account.default[local.default_env].primary_access_key
  tags         = local.common_tags
}

data "azurerm_key_vault_secret" "nix_cache_signing_key" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.dev_env].id
  name         = "nix-cache-esab-se-0"
}

data "azurerm_key_vault_secret" "nix_cache_public_key" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.dev_env].id
  name         = "nix-cache-esab-se-0-pub"
}

data "azurerm_key_vault_secret" "gitlab_service_account_username" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.dev_env].id
  name         = "gitlab-bot-username"
}

data "azurerm_key_vault_secret" "gitlab_service_account_pat" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.dev_env].id
  name         = "gitlab-bot-pat"
}

data "azurerm_key_vault_secret" "plc_apax_token" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.dev_env].id
  name         = "plc-apax-ci-token"
}

resource "azurerm_key_vault_secret" "hil_gbg_01_runner_token" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.test_env].id
  name         = "hil-gbg-01-runner-token"
  value        = gitlab_user_runner.hil_gbg_01[local.test_env].token
}

resource "azurerm_key_vault_secret" "hil_gbg_02_runner_token" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.test_env].id
  name         = "hil-gbg-02-runner-token"
  value        = gitlab_user_runner.hil_gbg_02[local.test_env].token
}

resource "azurerm_key_vault_secret" "hil_chn_01_runner_token" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[local.test_env].id
  name         = "hil-chn-01-runner-token"
  value        = gitlab_user_runner.hil_chn_01[local.test_env].token
}

resource "azurerm_key_vault_key" "sops_master_key_test" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  name         = "sops-master-key"
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  key_type     = "RSA"
  key_size     = "4096"
  key_opts     = ["encrypt", "decrypt"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P1Y"
    notify_before_expiry = "P45D"
  }
}

data "azurerm_key_vault_secret" "hil_gbg_01_age_public_key" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "hil-gbg-01-age-public-key"
}

data "azurerm_key_vault_secret" "hil_gbg_01_age_secret_key" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "hil-gbg-01-age-secret-key"
}

data "azurerm_key_vault_secret" "hil_gbg_02_age_public_key" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "hil-gbg-02-age-public-key"
}

data "azurerm_key_vault_secret" "hil_gbg_02_age_secret_key" {
  for_each     = (terraform.workspace == local.test_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "hil-gbg-02-age-secret-key"
}

resource "azurerm_key_vault_secret" "developer_container_sas_key" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "developer-storage-sas"
  value = format(
    "%s%s",
    "https://${azurerm_storage_account.gitlab_runner[local.dev_env].name}.blob.core.windows.net/${azurerm_storage_container.developer_container[local.dev_env].name}",
    data.azurerm_storage_account_blob_container_sas.developer_container_sas[terraform.workspace].sas
  )
}

data "azurerm_key_vault_secret" "testzilla_testrail_api_key" {
  for_each     = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  key_vault_id = azurerm_key_vault.this[terraform.workspace].id
  name         = "testzilla-testrail-api-key"
}
