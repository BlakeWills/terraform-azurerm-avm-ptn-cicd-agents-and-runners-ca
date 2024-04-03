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
resource "azurerm_resource_group" "rg" {
  location = "uksouth"
  name     = "ado-agents-rg"
}

# Not required, but useful for checking execution logs.
resource "azurerm_log_analytics_workspace" "this_workspace" {
  location            = azurerm_resource_group.this.location
  name                = "ado-agents-laws"
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

resource "azurerm_user_assigned_identity" "this_identity" {
  location            = azurerm_resource_group.this.location
  name                = "ado-agents-mi"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_virtual_network" "this_vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = "ado-agents-vnet"
  resource_group_name = azurerm_resource_group.this.name
}

module "containerregistry" {
  source              = "Azure/avm-res-containerregistry-registry/azurerm"
  name                = "ado-agents-acr"
  resource_group_name = azurerm_resource_group.this.name
  role_assignments = {
    acrpull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = azurerm_user_assigned_identity.this_identity.principal_id
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

module "avm-ptn-cicd-agents-and-runners-ca" {
  source = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"
  #source = "../.."

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.this_identity.id]
  }

  name                            = "ca-adoagent"
  azp_pool_name                   = "ca-adoagent-pool"
  azp_url                         = var.ado_organization_url
  pat_token_value                 = var.personal_access_token
  container_image_name            = "${module.containerregistry.resource.login_server}/${var.container_image_name}"
  log_analytics_workspace_id      = azurerm_log_analytics_workspace.this_workspace.id
  container_registry_login_server = module.containerregistry.resource.login_server

  virtual_network_name                = azurerm_virtual_network.this_vnet.name
  virtual_network_resource_group_name = azurerm_virtual_network.this_vnet.resource_group_name
  subnet_address_prefix               = "10.0.2.0/23"

  enable_telemetry = var.enable_telemetry # see variables.tf

  depends_on = [terraform_data.agent_container_image]
}
```

## Enable or Disable Tracing Tags

We're using [BridgeCrew Yor](https://github.com/bridgecrewio/yor) and [yorbox](https://github.com/lonegunmanb/yorbox) to help manage tags consistently across infrastructure as code (IaC) frameworks. This adds accountability for the code responsible for deploying the particular Azure resources. In this module you might see tags like:

```hcl
resource "azurerm_container_app_environment" "ado_agent_container_app" {
  location                       = data.azurerm_resource_group.parent.location
  name                           = coalesce(var.container_app_environment_name, "cae-${var.name}")
  resource_group_name            = var.resource_group_name
  infrastructure_subnet_id       = try(azurerm_subnet.ado_agents_subnet[0].id, var.subnet_id)
  internal_load_balancer_enabled = true
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  tags = (/*<box>*/ (var.tracing_tags_enabled ? { for k, v in /*</box>*/ {
    avm_git_commit           = "f2507b14218314d1fc8ce045727dcec2a1a80398"
    avm_git_file             = "main.tf"
    avm_git_last_modified_at = "2024-04-03 13:55:59"
    avm_git_org              = "BlakeWills"
    avm_git_repo             = "terraform-azurerm-avm-ptn-cicd-agents-and-runners-ca"
    avm_yor_name             = "ado_agent_container_app"
    avm_yor_trace            = "e81b70e5-cfe9-4918-9685-57bc900c0d68"
  } /*<box>*/ : replace(k, "avm_", var.tracing_tags_prefix) => v } : {}) /*</box>*/)
  zone_redundancy_enabled = true
}
```

To enable tracing tags, set the `tracing_tags_enabled` variable to true:

```hcl
module "avm-ptn-cicd-agents-and-runners-ca" {
  source = "../.."
  # source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                                = module.naming.container_app.name_unique
  azp_pool_name                       = "ca-adoagent-pool"
  azp_url                             = var.ado_organization_url
  pat_token_value                     = var.personal_access_token
  container_image_name                = "${module.containerregistry.resource.login_server}/${var.container_image_name}"
  log_analytics_workspace_id          = azurerm_log_analytics_workspace.this_workspace.id
  container_registry_login_server     = module.containerregistry.resource.login_server
  virtual_network_name                = azurerm_virtual_network.this_vnet.name
  virtual_network_resource_group_name = azurerm_virtual_network.this_vnet.resource_group_name
  subnet_address_prefix               = "10.0.2.0/23"

  depends_on       = [terraform_data.agent_container_image]
  enable_telemetry = var.enable_telemetry # see variables.tf

  tracing_tags_enabled = true
}
```

The `tracing_tags_enabled` is defaulted to `false`.

To customize the prefix for your tracing tags, set the `tracing_tags_prefix` variable value in your Terraform configuration:

```hcl
module "avm-ptn-cicd-agents-and-runners-ca" {
  source = "../.."
  # source             = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

  resource_group_name = azurerm_resource_group.this.name

  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.example_identity.id]
  }

  name                                = module.naming.container_app.name_unique
  azp_pool_name                       = "ca-adoagent-pool"
  azp_url                             = var.ado_organization_url
  pat_token_value                     = var.personal_access_token
  container_image_name                = "${module.containerregistry.resource.login_server}/${var.container_image_name}"
  log_analytics_workspace_id          = azurerm_log_analytics_workspace.this_workspace.id
  container_registry_login_server     = module.containerregistry.resource.login_server
  virtual_network_name                = azurerm_virtual_network.this_vnet.name
  virtual_network_resource_group_name = azurerm_virtual_network.this_vnet.resource_group_name
  subnet_address_prefix               = "10.0.2.0/23"

  depends_on       = [terraform_data.agent_container_image]
  enable_telemetry = var.enable_telemetry # see variables.tf

  tracing_tags_enabled = true
  tracing_tags_prefix  = "custom_prefix_"
}
```

The actual applied tags would be:

```text
{
  custom_prefix_git_commit           = "f2507b14218314d1fc8ce045727dcec2a1a80398"
  custom_prefix_git_file             = "main.tf"
  custom_prefix_git_last_modified_at = "2024-04-03 13:55:59"
  custom_prefix_git_org              = "BlakeWills"
  custom_prefix_git_repo             = "terraform-azurerm-avm-ptn-cicd-agents-and-runners-ca"
  custom_prefix_yor_name             = "ado_agent_container_app"
  custom_prefix_yor_trace            = "e81b70e5-cfe9-4918-9685-57bc900c0d68"
}
```
