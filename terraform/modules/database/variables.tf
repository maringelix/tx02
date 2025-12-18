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

variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
}

variable "db_sku_name" {
  description = "SKU do Azure Database"
  type        = string
}

variable "db_storage_gb" {
  description = "Tamanho do storage em GB"
  type        = number
}

variable "db_version" {
  description = "Versão do SQL Server (sempre 12.0)"
  type        = string
  default     = "12.0"
}

variable "db_admin_username" {
  description = "Username admin"
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

variable "subnet_id" {
  description = "ID da subnet para o database"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}
