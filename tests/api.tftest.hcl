provider "azurerm" {
  features {}
}

run "default_configuration" {
  command = plan

  variables {
    name                          = "test"
    location                      = "uksouth"
    azp_pool_name                 = "ca-adoagent-pool"
    azp_url                       = "https://dev.azure.com/my-org"
    pat_token_value               = "my-really-secure-token"
    container_image_name          = "microsoftavm/azure-devops-agent"
    subnet_address_prefix         = "10.0.2.0/23"
    virtual_network_address_space = "10.0.0.0/16"
  }

  # Resource group is created by default
  assert {
    condition     = azurerm_resource_group.rg[0].name == "rg-test"
    error_message = "Expected resource group to be created"
  }

  # Virtual network is created by default
  assert {
    condition     = azurerm_virtual_network.ado_agents_vnet[0].name == "vnet-test"
    error_message = "Expected virtual network to be created"
  }

  # Subnet is created by default
  assert {
    condition     = azurerm_subnet.ado_agents_subnet[0].name == "snet-test"
    error_message = "Expected subnet to be created"
  }
}

# Identity tests