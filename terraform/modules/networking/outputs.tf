output "vnet_id" {
  description = "ID da VNet"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Nome da VNet"
  value       = azurerm_virtual_network.main.name
}

output "subnet_aks_id" {
  description = "ID da subnet AKS"
  value       = azurerm_subnet.aks.id
}

output "subnet_database_id" {
  description = "ID da subnet Database"
  value       = azurerm_subnet.database.id
}

output "subnet_vm_id" {
  description = "ID da subnet VM"
  value       = azurerm_subnet.vm.id
}

output "subnet_appgw_id" {
  description = "ID da subnet Application Gateway"
  value       = azurerm_subnet.appgw.id
}
