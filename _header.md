# terraform-azurerm-avm-ptn-cicd-agents-and-runners-ca

This module is designed to deploy a self-hosted Azure DevOps agent using Azure Container Apps.

## Features

- Container App Environment
  - Consumer workload profile.
  - PAT token authentication to Azure DevOps organization (Plain-text value or KeyVault secret URL)
- Runner Job.
  - Configurable auto-scaling based on Azure DevOps pipeline jobs.
  - Configurable CPU and memory.
- Placeholder Job.

## Example

```hcl
resource "azurerm_resource_group" "this" {
  location = "uksouth"
  name     = "ado-agents-aca-rg"
}

resource "azurerm_virtual_network" "this_vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = "ado-agents-vnet"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_user_assigned_identity" "example_identity" {
  location            = azurerm_resource_group.this.location
  name                = "ado-agents-mi"
  resource_group_name = azurerm_resource_group.this.name
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

module "avm-ptn-cicd-agents-and-runners-ca" {
  source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                 = "ca-adoagent"
  azp_pool_name        = "ca-adoagent-pool"
  azp_url              = "https://dev.azure.com/my-organization"
  container_image_name = "${module.containerregistry.resource.login_server}/azure-pipelines:latest"

  virtual_network = azurerm_virtual_network.this_vnet
  subnet = {
    address_prefixes = [ "10.0.2.0/23" ]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry    = var.enable_telemetry # see variables.tf
}
```

## Enable or Disable Tracing Tags

We're using [BridgeCrew Yor](https://github.com/bridgecrewio/yor) and [yorbox](https://github.com/lonegunmanb/yorbox) to help manage tags consistently across infrastructure as code (IaC) frameworks. This adds accountability for the code responsible for deploying the particular Azure resources. In this module you might see tags like:

```hcl
resource "azurerm_container_app_environment" "ado_agent_container_app" {
  name                           = coalesce(var.container_app_environment_name, "cae-${var.name}")
  location                       = var.location
  resource_group_name            = var.resource_group_name
  zone_redundancy_enabled        = true
  infrastructure_subnet_id       = var.subnet_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  internal_load_balancer_enabled = true

  tags = merge(var.default_tags, var.route_table_tags, (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "0978238465c76c23be1b5998c1451519b4d135c9"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2023-07-01 10:37:24"
    avm_git_org              = "Azure"
    avm_git_repo             = "terraform-azurerm-avm-ptn-vnetgateway"
    avm_yor_name             = "vgw"
    avm_yor_trace            = "89805148-c9e6-4736-96bc-0f4095dfb135"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/))
}
```

To enable tracing tags, set the `tracing_tags_enabled` variable to true:

```hcl
module "avm-ptn-cicd-agents-and-runners-ca" {
  source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                 = "ca-adoagent"
  azp_pool_name        = "ca-adoagent-pool"
  azp_url              = "https://dev.azure.com/my-organization"
  container_image_name = "${module.containerregistry.resource.login_server}/azure-pipelines:latest"

  virtual_network = azurerm_virtual_network.this_vnet
  subnet = {
    address_prefixes = [ "10.0.2.0/23" ]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry    = var.enable_telemetry # see variables.tf

  tracing_tags_enabled = true
}
```

The `tracing_tags_enabled` is defaulted to `false`.

To customize the prefix for your tracing tags, set the `tracing_tags_prefix` variable value in your Terraform configuration:

```hcl
module "avm-ptn-cicd-agents-and-runners-ca" {
  source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                 = "ca-adoagent"
  azp_pool_name        = "ca-adoagent-pool"
  azp_url              = "https://dev.azure.com/my-organization"
  container_image_name = "${module.containerregistry.resource.login_server}/azure-pipelines:latest"

  virtual_network = azurerm_virtual_network.this_vnet
  subnet = {
    address_prefixes = [ "10.0.2.0/23" ]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry    = var.enable_telemetry # see variables.tf

  tracing_tags_enabled = true
  tracing_tags_prefix  = "custom_prefix_"
}
```

# TODO: Where do we get these from?
The actual applied tags would be:

```text
{
  custom_prefix_git_commit           = "0978238465c76c23be1b5998c1451519b4d135c9"
  custom_prefix_git_file             = "main.tf"
  custom_prefix_git_last_modified_at = "2023-07-01 10:37:24"
  custom_prefix_git_org              = "Azure"
  custom_prefix_git_repo             = "terraform-azurerm-avm-ptn-vnetgateway"
  custom_prefix_yor_name             = "vgw"
  custom_prefix_yor_trace            = "89805148-c9e6-4736-96bc-0f4095dfb135"
}
```
