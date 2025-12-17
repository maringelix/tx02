# Resource Group
output "resource_group_name" {
  description = "Nome do Resource Group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Região do Resource Group"
  value       = azurerm_resource_group.main.location
}

# Networking
output "vnet_id" {
  description = "ID da VNet"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "Nome da VNet"
  value       = module.networking.vnet_name
}

output "subnet_aks_id" {
  description = "ID da subnet AKS"
  value       = module.networking.subnet_aks_id
}

# Database
output "db_host" {
  description = "Hostname do database"
  value       = length(module.database) > 0 ? module.database[0].db_host : ""
}

output "db_name" {
  description = "Nome do database"
  value       = length(module.database) > 0 ? module.database[0].db_name : ""
}

output "db_connection_string" {
  description = "Connection string do database (sem senha)"
  value       = length(module.database) > 0 ? "postgresql://${var.db_admin_username}@${module.database[0].db_host}:5432/${var.db_name}" : ""
  sensitive   = true
}

# AKS (se ativo)
output "aks_cluster_name" {
  description = "Nome do cluster AKS"
  value       = var.use_aks ? module.aks[0].cluster_name : null
}

output "aks_cluster_id" {
  description = "ID do cluster AKS"
  value       = var.use_aks ? module.aks[0].cluster_id : null
}

output "aks_kube_config" {
  description = "Kubeconfig do AKS"
  value       = var.use_aks ? module.aks[0].kube_config : null
  sensitive   = true
}

output "aks_get_credentials_command" {
  description = "Comando para obter credenciais do AKS"
  value       = var.use_aks ? "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks[0].cluster_name}" : null
}

# VM (se ativo)
output "vm_public_ip" {
  description = "IP público da VM"
  value       = var.use_aks ? null : module.vm[0].public_ip
}

output "vm_ssh_command" {
  description = "Comando SSH para conectar na VM"
  value       = var.use_aks ? null : "ssh ${var.vm_admin_username}@${module.vm[0].public_ip}"
}

# Deployment Info
output "deployment_mode" {
  description = "Modo de deployment (aks ou vm)"
  value       = var.use_aks ? "AKS" : "VM"
}

output "next_steps" {
  description = "Próximos passos após o deploy"
  value = var.use_aks ? join("\n", [
    "✅ Infraestrutura criada com sucesso!",
    "",
    "Próximos passos:",
    "1. Conectar ao AKS:",
    "   az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks[0].cluster_name}",
    "",
    "2. Verificar nodes:",
    "   kubectl get nodes",
    "",
    "3. Fazer deploy da aplicação:",
    "   kubectl apply -f k8s/",
    "",
    "4. Acessar a aplicação:",
    "   kubectl get svc -n default"
    ]) : join("\n", [
    "✅ Infraestrutura criada com sucesso!",
    "",
    "Próximos passos:",
    "1. Conectar na VM via SSH:",
    "   ssh ${var.vm_admin_username}@${module.vm[0].public_ip}",
    "",
    "2. Verificar containers:",
    "   docker ps",
    "",
    "3. Ver logs da aplicação:",
    "   docker logs dx02",
    "",
    "4. Acessar a aplicação:",
    "   http://${module.vm[0].public_ip}"
  ])
}
