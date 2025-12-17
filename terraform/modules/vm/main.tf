# Public IP para VM
resource "azurerm_public_ip" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = var.tags
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "${var.project_name}-${var.environment}-vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
  
  tags = var.tags
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  disable_password_authentication = false
  
  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    admin_username = var.admin_username
    db_host        = var.db_host
    db_name        = var.db_name
    db_username    = var.db_username
    db_password    = var.db_password
  }))
  
  tags = var.tags
}
