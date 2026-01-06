# Azure Container Registry Module

resource "azurerm_container_registry" "main" {
  name                = replace("${var.project_name}${var.environment}acr", "-", "") # ACR name can't have hyphens
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Public network access (Free tier doesn't support private link)
  public_network_access_enabled = true

  tags = var.tags
}
