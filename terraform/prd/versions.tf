# Inherit from root
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatetx02"
    container_name       = "tfstate"
    key                  = "tx02-prd.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  
  use_cli  = false
  use_msi  = false
  use_oidc = false
}