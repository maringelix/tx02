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

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
}

variable "node_count" {
  description = "Número inicial de nodes"
  type        = number
}

variable "min_count" {
  description = "Mínimo de nodes (auto-scaling)"
  type        = number
}

variable "max_count" {
  description = "Máximo de nodes (auto-scaling)"
  type        = number
}

variable "node_size" {
  description = "Tamanho dos nodes"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet para o AKS"
  type        = string
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}
