output "db_id" {
  description = "ID do database server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "db_host" {
  description = "Hostname do database"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "db_name" {
  description = "Nome do database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "db_port" {
  description = "Porta do database"
  value       = 5432
}

output "db_connection_string" {
  description = "Connection string (sem senha)"
  value       = "postgresql://${var.db_admin_username}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.db_name}"
  sensitive   = true
}
