provider "azurerm" {
   features {}
}

resource "tls_private_key" "key_pair" {
   algorithm = "RSA"
   rsa_bits  = 4096
}

resource "azurerm_resource_group" "rg" {
  name     = var.rg_properties.name
  location = var.rg_properties.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_properties.vnet_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = var.vnet_properties.vm_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.vnet_properties.vm_subnet_cidr
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = var.vmss_properties.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.vmss_properties.sku
  instances           = var.vmss_properties.instances
  admin_username      = var.vmss_properties.admin_username
  upgrade_mode        = var.vmss_properties.upgrade_mode

  admin_ssh_key {
    username   = var.vmss_properties.username
    public_key = tls_private_key.key_pair.public_key_openssh
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  os_disk {
    storage_account_type = var.vm_os_disk.storage_account_type
    caching              = var.vm_os_disk.caching
  }

  network_interface {
    name    = var.vmss_properties.nic_name
    primary = var.vmss_properties.nic_primary

    ip_configuration {
      name      = var.vmss_properties.ip_name
      primary   = var.vmss_properties.ip_primary
      subnet_id = azurerm_subnet.vm_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool_address.id]

    }
  }
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale_on_cpu"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

resource "azurerm_public_ip" "basic_ip" {
  name                = "basic_ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_lb" "basic_lb" {
  name                = "basic_lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "lb_front_end_ip"
    public_ip_address_id = azurerm_public_ip.basic_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool_address" {
  loadbalancer_id = azurerm_lb.basic_lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "lb_probe_8080" {
  loadbalancer_id = azurerm_lb.basic_lb.id
  name            = "probe_8080"
  port            = 8080
}

resource "azurerm_lb_probe" "lb_probe_22" {
  loadbalancer_id = azurerm_lb.basic_lb.id
  name            = "probe_22"
  port            = 22
}

resource "azurerm_lb_rule" "lb_rule_80" {
  loadbalancer_id                = azurerm_lb.basic_lb.id
  name                           = "lb_rule_80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  frontend_ip_configuration_name = azurerm_lb.basic_lb.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.lb_probe_8080.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool_address.id]
}

resource "azurerm_lb_rule" "lb_rule_22" {
  loadbalancer_id                = azurerm_lb.basic_lb.id
  name                           = "lb_rule_22"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.basic_lb.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.lb_probe_22.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool_address.id]
}

data "azurerm_subscription" "primary" {
}

resource "azurerm_role_definition" "reboot" {
  name        = "rebooter"
  scope       = data.azurerm_subscription.primary.id
  description = "A rebooter role"

  permissions {
    actions     = [
        "Microsoft.Compute/virtualMachines/restart/action",
        "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/restart/action",
        "Microsoft.Compute/virtualMachineScaleSets/read",
        "Microsoft.Compute/virtualMachines/read",
			  "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Resources/subscriptions/resourcegroups/resources/read",
        "Microsoft.Compute/virtualMachineScaleSets/instanceView/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.primary.id,
  ]
}

resource "azuread_user" "user" {
  user_principal_name = "user@domain.com"
  display_name        = "User Domain"
  mail_nickname       = "user"
  password            = "SecretP@sswd99!"
}


resource "azurerm_role_assignment" "assign" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "rebooter"
  principal_id         = azuread_user.user.id
}