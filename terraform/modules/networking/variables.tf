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

variable "tags" {
  description = "Tags"
  type        = map(string)
}
