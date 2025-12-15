output "vm_id" {
  description = "ID da VM"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Nome da VM"
  value       = azurerm_linux_virtual_machine.main.name
}

output "public_ip" {
  description = "IP público da VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "private_ip" {
  description = "IP privado da VM"
  value       = azurerm_network_interface.vm.private_ip_address
}
