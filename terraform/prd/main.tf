# TX02 Production Infrastructure
# This configuration deploys AKS, PostgreSQL, and networking resources to Azure

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
    Location    = var.location
    ManagedBy   = "Terraform"
  })
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Networking Module
module "networking" {
  source = "../modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  location           = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  vnet_address_space = var.vnet_address_space
  subnet_aks         = var.subnet_aks
  subnet_database    = var.subnet_database
  subnet_vm          = var.subnet_vm
  subnet_appgw       = var.subnet_appgw
  
  tags = local.common_tags
}

# Database Module
module "database" {
  source = "../modules/database"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  db_sku_name         = var.db_sku_name
  db_storage_gb       = var.db_storage_gb
  db_version          = var.db_version
  db_admin_username   = var.db_admin_username
  db_password         = var.db_password
  db_name             = var.db_name
  
  subnet_id           = module.networking.subnet_database_id
  
  tags = local.common_tags
}

# AKS Module (condicional)
module "aks" {
  count  = var.use_aks ? 1 : 0
  source = "../modules/aks"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  kubernetes_version  = var.kubernetes_version
  node_count          = var.aks_node_count
  min_count           = var.aks_min_count
  max_count           = var.aks_max_count
  node_size           = var.aks_node_size
  
  subnet_id           = module.networking.subnet_aks_id
  
  tags = local.common_tags
}

# VM Module (condicional)
module "vm" {
  count  = var.use_aks ? 0 : 1
  source = "../modules/vm"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  vm_size             = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  
  subnet_id           = module.networking.subnet_vm_id
  
  db_host             = module.database.db_host
  db_name             = var.db_name
  db_username         = var.db_admin_username
  db_password         = var.db_password
  
  tags = local.common_tags
}
