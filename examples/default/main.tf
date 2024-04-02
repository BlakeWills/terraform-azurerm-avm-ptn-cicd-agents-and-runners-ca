locals {
  tags = {
    scenario = "default"
  }
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = ">= 0.3.0"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this_vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.user_assigned_identity.name_unique
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

module "containerregistry" {
  source              = "Azure/avm-res-containerregistry-registry/azurerm"
  name                = module.naming.container_registry.name_unique
  resource_group_name = azurerm_resource_group.this.name
  role_assignments = {
    acrpull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = azurerm_user_assigned_identity.example_identity.principal_id
    }
  }
}

# This is the module call
# Do not specify location here due to the randomization above.
# Leaving location as `null` will cause the module to use the resource group location
# with a data source.
module "avm-ptn-cicd-agents-and-runners-ca" {
  source = "../.."
  # source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                 = "ca-adoagent"
  azp_pool_name        = "ca-adoagent-pool"
  azp_url              = "https://dev.azure.com/BJSSCloudLZs"
  container_image_name = "${module.containerregistry.resource.login_server}/azure-pipelines:latest"

  virtual_network = azurerm_virtual_network.this_vnet
  subnet = {
    address_prefixes = [ "10.0.2.0/23" ]
  }
  
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry    = var.enable_telemetry # see variables.tf
}