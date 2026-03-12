# Outputs for storage account details
output "default_storage_account_name" {
  description = "Output the name of the storage account for backend authentication"
  sensitive   = true
  value       = try(azurerm_storage_account.default[local.default_env].name, "")
}

output "default_storage_account_key" {
  description = "The primary access key to be used for backend authentication"
  sensitive   = true
  value       = try(azurerm_storage_account.default[local.default_env].primary_access_key, "")
}

output "vnet_name" {
  sensitive = true
  value     = try(azurerm_virtual_network.this[local.default_env].name, "")
}

output "vnet_id" {
  sensitive = true
  value     = try(azurerm_virtual_network.this[local.default_env].id, "")
}

output "subnet_id_default" {
  sensitive = true
  value     = try(azurerm_subnet.this[local.default_env].id, "")
}

output "subnet_id_dev" {
  sensitive = true
  value     = try(azurerm_subnet.this[local.dev_env].id, "")
}

output "subnet_id_test" {
  sensitive = true
  value     = try(azurerm_subnet.this[local.test_env].id, "")
}

output "subnet_id_prod" {
  sensitive = true
  value     = try(azurerm_subnet.this[local.prod_env].id, "")
}

output "dev_cluster_2_kube_config" {
  sensitive = true
  value     = try(azurerm_kubernetes_cluster.dev_2[local.dev_env].kube_config.0, "")
}

output "gl_runner_st_name" {
  description = "Output the name of the storage account for backend authentication"
  sensitive   = true
  value       = try(azurerm_storage_account.gitlab_runner[local.dev_env].name, "")
}

output "gl_runner_st_key" {
  description = "The primary access key to be used for backend authentication"
  sensitive   = true
  value       = try(azurerm_storage_account.gitlab_runner[local.dev_env].primary_access_key, "")
}

output "gl_runner_cache_container_name" {
  description = "The primary access key to be used for backend authentication"
  sensitive   = true
  value       = try(azurerm_storage_container.gitlab_runner_cache[local.dev_env].name, "")
}
