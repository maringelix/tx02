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

variable "vm_size" {
  description = "Tamanho da VM"
  type        = string
}

variable "admin_username" {
  description = "Username admin"
  type        = string
}

variable "admin_password" {
  description = "Senha admin"
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "ID da subnet para a VM"
  type        = string
}

variable "db_host" {
  description = "Hostname do database"
  type        = string
}

variable "db_name" {
  description = "Nome do database"
  type        = string
}

variable "db_username" {
  description = "Username do database"
  type        = string
}

variable "db_password" {
  description = "Senha do database"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}
