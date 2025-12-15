output "cluster_id" {
  description = "ID do cluster AKS"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Nome do cluster AKS"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "FQDN do cluster AKS"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config" {
  description = "Kubeconfig do AKS"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "host" {
  description = "Kubernetes host"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}
