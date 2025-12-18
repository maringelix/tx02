# Azure SQL Database Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.project_name}-${var.environment}-sql"
  resource_group_name          = var.resource_group_name
  location                     = "westus2"  # Free tier only available in westus2
  version                      = "12.0"
  administrator_login          = var.db_admin_username
  administrator_login_password = var.db_password

  minimum_tls_version = "1.2"

  public_network_access_enabled = true

  tags = var.tags
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name           = var.db_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = var.db_storage_gb
  sku_name       = var.db_sku_name
  zone_redundant = false

  tags = var.tags
}

# Data source para obter a VNet
data "azurerm_virtual_network" "main" {
  name                = split("/", var.subnet_id)[8]
  resource_group_name = var.resource_group_name
}

# Private DNS Zone para SQL Database
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link entre Private DNS Zone e VNet
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "${var.project_name}-${var.environment}-sql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = data.azurerm_virtual_network.main.id
  resource_group_name   = var.resource_group_name

  tags = var.tags
}

# Private Endpoint para SQL Server
resource "azurerm_private_endpoint" "sql" {
  name                = "${var.project_name}-${var.environment}-sql-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.main.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql]
}

# Firewall rule para permitir serviços Azure
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
