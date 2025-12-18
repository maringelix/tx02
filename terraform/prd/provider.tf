terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatetx02"
    container_name       = "tfstate"
    key                  = "tx02-prd.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Use Service Principal authentication via environment variables
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
  skip_provider_registration = true
  use_cli                    = true  # Temporarily using CLI for ACR creation
  use_msi                    = false
  use_oidc                   = false
}

provider "azuread" {}

provider "helm" {
  kubernetes {
    host                   = var.use_aks && length(module.aks) > 0 ? module.aks[0].kube_config.0.host : null
    client_certificate     = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.client_certificate) : null
    client_key             = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.client_key) : null
    cluster_ca_certificate = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.cluster_ca_certificate) : null
  }
}

provider "kubernetes" {
  host                   = var.use_aks && length(module.aks) > 0 ? module.aks[0].kube_config.0.host : null
  client_certificate     = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.client_certificate) : null
  client_key             = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.client_key) : null
  cluster_ca_certificate = var.use_aks && length(module.aks) > 0 ? base64decode(module.aks[0].kube_config.0.cluster_ca_certificate) : null
}
