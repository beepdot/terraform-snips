variable "rg_properties" {
  type = map
  default = {
        name       = "keshavprasad"
        location   = "South India"
  }
}

variable "vnet_properties" {
  type = object ({
    vnet_name       = string
    location        = string
    vm_subnet_name  = string
    vm_subnet_cidr  = list(string)
  })

  default = {
        vnet_name       = "vnet"
        location        = "South India"
        vm_subnet_name  = "vm_subnet"
        vm_subnet_cidr  = ["10.0.0.0/24"]
  }
}

variable "vmss_properties" {
    type = map
    default = {
        name            = "ubuntu-vmss"
        username        = "ubuntu"
        sku             = "Standard_DS1_v2"
        instances       = 1
        admin_username  = "ubuntu"
        nic_name        = "nic01"
        nic_primary     = true
        ip_name         = "ip01"
        ip_primary      = true
        upgrade_mode    = "Automatic"
    }
}

variable "vm_image" {
    type = map
    default = {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-focal"
        sku       = "20_04-lts-gen2"
        version   = "latest"
  }
}

variable "vm_os_disk" {
    type = map
    default = {
        storage_account_type = "Standard_LRS"
        caching              = "ReadWrite"
    }
}