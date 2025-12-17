# Azure Database for PostgreSQL - Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "${var.project_name}-${var.environment}-db"
  resource_group_name = var.resource_group_name
  location            = var.location

  version             = var.db_version
  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  administrator_login    = var.db_admin_username
  administrator_password = var.db_password

  zone = "1"

  storage_mb = var.db_storage_gb * 1024

  sku_name = var.db_sku_name

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# Data source para obter informações da subnet
data "azurerm_subnet" "database" {
  name                 = split("/", var.subnet_id)[10]
  virtual_network_name = split("/", var.subnet_id)[8]
  resource_group_name  = var.resource_group_name
}

# Data source para obter a VNet
data "azurerm_virtual_network" "main" {
  name                = split("/", var.subnet_id)[8]
  resource_group_name = var.resource_group_name
}

# Private DNS Zone para PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.project_name}-${var.environment}-pdz.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link entre Private DNS Zone e VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.project_name}-${var.environment}-pdz-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  resource_group_name   = var.resource_group_name

  tags = var.tags
}

# Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Firewall rule para permitir conexões do Azure
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Configurações do servidor
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "100"
}

resource "azurerm_postgresql_flexible_server_configuration" "shared_buffers" {
  name      = "shared_buffers"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "32768"
}
