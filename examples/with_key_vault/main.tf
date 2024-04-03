locals {
  tags = {
    scenario = "with_key_vault"
  }
}

data "azurerm_client_config" "this" {}

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

# Not required, but useful for checking execution logs.
resource "azurerm_log_analytics_workspace" "this_workspace" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
  tags                = local.tags
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

module "keyvault" {
  source              = "Azure/avm-res-keyvault-vault/azurerm"
  name                = module.naming.key_vault.name_unique
  enable_telemetry    = var.enable_telemetry
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.this.tenant_id

  network_acls = null

  secrets = {
    pat-token = {
      name = "pat-token"
    }
  }

  secrets_value = {
    pat-token = var.personal_access_token
  }

  role_assignments = {
    # Required for container app environments to be able to read PAT token from KeyVault.
    secrets_reader = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_user_assigned_identity.example_identity.principal_id
    },

    # Required to set PAT token.
    current_user = {
      role_definition_id_or_name = "Key Vault Administrator"
      principal_id               = data.azurerm_client_config.this.object_id
    }
  }
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

# Build the sample container within our new ACR
resource "terraform_data" "agent_container_image" {
  triggers_replace = module.containerregistry.resource_id

  provisioner "local-exec" {
    command = <<COMMAND
az acr build --registry ${module.containerregistry.resource.name} --image "${var.container_image_name}" --file "Dockerfile.azure-pipelines" "https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial.git"
COMMAND
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

  name                            = "ca-adoagent"
  azp_pool_name                   = "ca-adoagent-pool"
  azp_url                         = var.ado_organization_url
  pat_token_secret_url            = module.keyvault.resource_secrets["pat-token"].id
  container_image_name            = "${module.containerregistry.resource.login_server}/${var.container_image_name}"
  log_analytics_workspace_id      = azurerm_log_analytics_workspace.this_workspace.id
  container_registry_login_server = module.containerregistry.resource.login_server

  virtual_network_name                = azurerm_virtual_network.this_vnet.name
  virtual_network_resource_group_name = azurerm_virtual_network.this_vnet.resource_group_name
  subnet_address_prefix               = "10.0.2.0/23"

  enable_telemetry = var.enable_telemetry # see variables.tf

  depends_on = [terraform_data.agent_container_image]
}