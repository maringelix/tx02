variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

variable "location" {
  description = "Região Azure"
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block para VNet"
  type        = list(string)
}

variable "subnet_aks" {
  description = "CIDR block para subnet AKS"
  type        = string
}

variable "subnet_database" {
  description = "CIDR block para subnet Database"
  type        = string
}

variable "subnet_vm" {
  description = "CIDR block para subnet VM"
  type        = string
}

variable "subnet_appgw" {
  description = "CIDR block para subnet Application Gateway"
  type        = string
}

variable "use_aks" {
  description = "Usar AKS (true) ou VM (false)"
  type        = bool
}

variable "aks_node_count" {
  description = "Número de nodes no AKS"
  type        = number
}

variable "aks_min_count" {
  description = "Mínimo de nodes (auto-scaling)"
  type        = number
}

variable "aks_max_count" {
  description = "Máximo de nodes (auto-scaling)"
  type        = number
}

variable "aks_node_size" {
  description = "Tamanho do node AKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
}

variable "db_sku_name" {
  description = "SKU do Azure Database"
  type        = string
}

variable "db_storage_gb" {
  description = "Tamanho do storage do database em GB"
  type        = number
}

variable "db_version" {
  description = "Versão do PostgreSQL"
  type        = string
}

variable "db_admin_username" {
  description = "Username admin do database"
  type        = string
}

variable "db_password" {
  description = "Senha do database"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nome do database"
  type        = string
}

variable "vm_size" {
  description = "Tamanho da VM"
  type        = string
}

variable "vm_admin_username" {
  description = "Username admin da VM"
  type        = string
}

variable "vm_admin_password" {
  description = "Senha admin da VM"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags para todos os recursos"
  type        = map(string)
}

# Azure authentication
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Azure Client ID (Service Principal)"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Azure Client Secret (Service Principal)"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}
