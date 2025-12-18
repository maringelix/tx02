output "db_id" {
  description = "ID do database server"
  value       = azurerm_mssql_server.main.id
}

output "db_host" {
  description = "Hostname do database"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "db_name" {
  description = "Nome do database"
  value       = azurerm_mssql_database.main.name
}

output "db_port" {
  description = "Porta do database"
  value       = 1433
}

output "db_connection_string" {
  description = "Connection string (SQL Server)"
  value       = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};User ID=${var.db_admin_username};Password=${var.db_password};Encrypt=True;"
  sensitive   = true
}

