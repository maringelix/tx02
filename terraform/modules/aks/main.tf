# Azure Kubernetes Service
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_size
    vnet_subnet_id = var.subnet_id

    enable_auto_scaling = true
    min_count           = var.min_count
    max_count           = var.max_count

    os_disk_size_gb = 30

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
  }

  azure_policy_enabled             = true
  http_application_routing_enabled = false

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  tags = var.tags
}

# Log Analytics Workspace para AKS
resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Role assignment removed - requires User Access Administrator permission on SP
# AKS managed identity will get necessary network permissions automatically
# resource "azurerm_role_assignment" "aks_network" {
#   principal_id                     = azurerm_kubernetes_cluster.main.identity[0].principal_id
#   role_definition_name             = "Network Contributor"
#   scope                            = var.subnet_id
#   skip_service_principal_aad_check = true
# }
