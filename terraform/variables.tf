variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "tx02"
}

variable "environment" {
  description = "Ambiente (prd, stg, dev)"
  type        = string
  default     = "prd"
}

variable "location" {
  description = "Região Azure"
  type        = string
  default     = "eastus"
}

variable "vnet_address_space" {
  description = "CIDR block para VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_aks" {
  description = "CIDR block para subnet AKS"
  type        = string
  default     = "10.1.1.0/24"
}

variable "subnet_database" {
  description = "CIDR block para subnet Database"
  type        = string
  default     = "10.1.2.0/24"
}

variable "subnet_vm" {
  description = "CIDR block para subnet VM"
  type        = string
  default     = "10.1.3.0/24"
}

variable "subnet_appgw" {
  description = "CIDR block para subnet Application Gateway"
  type        = string
  default     = "10.1.4.0/24"
}

# AKS
variable "use_aks" {
  description = "Usar AKS (true) ou VM (false)"
  type        = bool
  default     = true
}

variable "aks_node_count" {
  description = "Número de nodes no AKS"
  type        = number
  default     = 3
}

variable "aks_min_count" {
  description = "Mínimo de nodes (auto-scaling)"
  type        = number
  default     = 2
}

variable "aks_max_count" {
  description = "Máximo de nodes (auto-scaling)"
  type        = number
  default     = 10
}

variable "aks_node_size" {
  description = "Tamanho do node AKS"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.32"
}

# Database
variable "db_sku_name" {
  description = "SKU do Azure Database for PostgreSQL"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "db_storage_gb" {
  description = "Tamanho do storage do database em GB"
  type        = number
  default     = 32
}

variable "db_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "17"
}

variable "db_admin_username" {
  description = "Username admin do database"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Senha do database (via TF_VAR_db_password)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nome do database"
  type        = string
  default     = "dx02db"
}

# VM
variable "vm_size" {
  description = "Tamanho da VM"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "Username admin da VM"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Senha admin da VM (via TF_VAR_admin_password)"
  type        = string
  sensitive   = true
}

# Tags
variable "tags" {
  description = "Tags para todos os recursos"
  type        = map(string)
  default = {
    Project     = "tx02"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}
