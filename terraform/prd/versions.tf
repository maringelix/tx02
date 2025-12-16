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
    subscription_id      = "a9705497-3374-423a-96d1-1661267148ea"
    tenant_id            = "398f799c-e9db-4bfc-bc6e-b60fcd7bd1f3"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  
  use_cli  = false
  use_msi  = false
  use_oidc = false
}