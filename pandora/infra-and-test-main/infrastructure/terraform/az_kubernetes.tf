resource "azurerm_kubernetes_cluster" "dev_2" {
  for_each            = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  location            = azurerm_resource_group.this[local.dev_env].location
  name                = "k8-${local.common_name}-2"
  resource_group_name = azurerm_resource_group.this[local.dev_env].name
  dns_prefix          = "k8-${var.project.name}-${terraform.workspace}-${local.pretty-region}-2"
  kubernetes_version  = "1.32"
  tags                = local.common_tags

  node_resource_group = "mc-k8-${local.common_name}-2"

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_logs_2[local.dev_env].id
  }

  default_node_pool {
    name                 = "systempool"
    vm_size              = "Standard_D2s_v3"
    node_count           = 1
    min_count            = 1
    max_count            = 2
    auto_scaling_enabled = true
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = "1.32"
    vnet_subnet_id       = azurerm_subnet.aks_subnet_2[local.dev_env].id
    tags                 = local.common_tags
    node_labels = {
      role        = "system"
      environment = "gitlab"
    }

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    outbound_type  = "userAssignedNATGateway"

    load_balancer_sku = "standard"
  }

  storage_profile {
    blob_driver_enabled         = true
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [default_node_pool[0].node_count]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "dev_pool_1_2" {
  for_each              = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dev_2[local.dev_env].id
  name                  = "workerpool1"
  mode                  = "User"
  os_type               = "Linux"
  os_sku                = "AzureLinux"
  vm_size               = "Standard_D16_v5"
  vnet_subnet_id        = azurerm_subnet.aks_subnet_2[local.dev_env].id
  node_count            = 1
  min_count             = 1
  max_count             = 10
  auto_scaling_enabled  = true
  orchestrator_version  = "1.32"
  tags                  = local.common_tags
  node_labels = {
    role        = "worker"
    environment = "gitlab"
    size        = "big"
  }
  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "dev_pool_2_2" {
  for_each              = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dev_2[local.dev_env].id
  name                  = "workerpool2"
  mode                  = "User"
  os_type               = "Linux"
  os_sku                = "AzureLinux"
  vm_size               = "Standard_D8s_v3"
  vnet_subnet_id        = azurerm_subnet.aks_subnet_2[local.dev_env].id
  node_count            = 1
  min_count             = 1
  max_count             = 10
  auto_scaling_enabled  = true
  orchestrator_version  = "1.32"
  tags                  = local.common_tags
  node_labels = {
    role        = "worker"
    environment = "gitlab"
    size        = "small"
  }
  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "runner_pool_2" {
  for_each                    = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.dev_2[local.dev_env].id
  name                        = "runnerpool"
  mode                        = "User"
  os_type                     = "Linux"
  os_sku                      = "AzureLinux"
  vm_size                     = "Standard_D8s_v3"
  vnet_subnet_id              = azurerm_subnet.aks_subnet_2[local.dev_env].id
  temporary_name_for_rotation = "temprunner"
  node_count                  = 1
  auto_scaling_enabled        = false
  orchestrator_version        = "1.32"
  tags                        = local.common_tags
  node_labels = {
    role        = "manager"
    environment = "gitlab"
  }
  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }
}

resource "azurerm_log_analytics_workspace" "aks_logs_2" {
  for_each            = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                = "law-${var.project.name}-${terraform.workspace}-2"
  location            = azurerm_resource_group.this[local.dev_env].location
  resource_group_name = azurerm_resource_group.this[local.dev_env].name
  sku                 = "PerGB2018"
  retention_in_days   = 60

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks_diag_2" {
  for_each                       = (terraform.workspace == local.dev_env ? { (terraform.workspace) = "" } : {})
  name                           = "aks-diag-2"
  target_resource_id             = azurerm_kubernetes_cluster.dev_2[local.dev_env].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.aks_logs_2[local.dev_env].id
  log_analytics_destination_type = "Dedicated"

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "cloud-controller-manager" }
  enabled_log { category = "guard" }
  enabled_log { category = "csi-azuredisk-controller" }
  enabled_log { category = "csi-azurefile-controller" }

  enabled_metric { category = "AllMetrics" }
}
