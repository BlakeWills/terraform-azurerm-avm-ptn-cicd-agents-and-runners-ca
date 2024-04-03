<!-- BEGIN_TF_DOCS -->
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
  source = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

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
    address_prefixes = ["10.0.2.0/23"]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry = var.enable_telemetry # see variables.tf
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
  source = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

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
    address_prefixes = ["10.0.2.0/23"]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

  enable_telemetry = var.enable_telemetry # see variables.tf

  tracing_tags_enabled = true
}
```

The `tracing_tags_enabled` is defaulted to `false`.

To customize the prefix for your tracing tags, set the `tracing_tags_prefix` variable value in your Terraform configuration:

```hcl
module "avm-ptn-cicd-agents-and-runners-ca" {
  source = "Azure/avm-ptn-cicd-agents-and-runners-ca/azurerm"

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
    address_prefixes = ["10.0.2.0/23"]
  }
  pat_token_value                 = var.personal_access_token
  container_registry_login_server = module.containerregistry.resource.login_server

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

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (>= 1.9.0, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.71)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Providers

The following providers are used by this module:

- <a name="provider_azapi"></a> [azapi](#provider\_azapi) (>= 1.9.0, < 2.0)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 3.71)

- <a name="provider_random"></a> [random](#provider\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azapi_resource.placeholder_job](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource.runner_job](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azurerm_container_app_environment.ado_agent_container_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_resource_group_template_deployment.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_template_deployment) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_subnet.ado_agents_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [random_id.telem](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) (resource)
- [azurerm_resource_group.parent](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_azp_pool_name"></a> [azp\_pool\_name](#input\_azp\_pool\_name)

Description: Name of the pool that agents should register against in Azure DevOps.

Type: `string`

### <a name="input_azp_url"></a> [azp\_url](#input\_azp\_url)

Description: URL for the Azure DevOps project.

Type: `string`

### <a name="input_container_image_name"></a> [container\_image\_name](#input\_container\_image\_name)

Description: Fully qualified name of the Docker image the agents should run.

Type: `string`

### <a name="input_container_registry_login_server"></a> [container\_registry\_login\_server](#input\_container\_registry\_login\_server)

Description: Login server url for the Azure Container Registry hosting the image.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: Prefix used for naming the container app environment and container app jobs.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The resource group where the resources will be deployed.

Type: `string`

### <a name="input_virtual_network_name"></a> [virtual\_network\_name](#input\_virtual\_network\_name)

Description: The name of the Virtual Network.

Type: `string`

### <a name="input_virtual_network_resource_group_name"></a> [virtual\_network\_resource\_group\_name](#input\_virtual\_network\_resource\_group\_name)

Description: The name of the Virtual Network's Resource Group.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_container_app_environment_name"></a> [container\_app\_environment\_name](#input\_container\_app\_environment\_name)

Description: The name of the Container App Environment.

Type: `string`

Default: `null`

### <a name="input_container_app_job_placeholder_name"></a> [container\_app\_job\_placeholder\_name](#input\_container\_app\_job\_placeholder\_name)

Description: The name of the Container App placeholder job.

Type: `string`

Default: `null`

### <a name="input_container_app_job_runner_name"></a> [container\_app\_job\_runner\_name](#input\_container\_app\_job\_runner\_name)

Description: The name of the Container App runner job.

Type: `string`

Default: `null`

### <a name="input_container_registry_user_assigned_identity"></a> [container\_registry\_user\_assigned\_identity](#input\_container\_registry\_user\_assigned\_identity)

Description: The user assigned identity to use to authenticate with Azure container registry.  
Must be specified if multiple user assigned are specified in `managed_identities`.

Type: `string`

Default: `null`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_key_vault_user_assigned_identity"></a> [key\_vault\_user\_assigned\_identity](#input\_key\_vault\_user\_assigned\_identity)

Description: The user assigned identity to use to authenticate with Key Vault.  
Must be specified if multiple user assigned are specified in `managed_identities`.

Type: `string`

Default: `null`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region where the resource should be deployed.  If null, the location will be inferred from the resource group location.

Type: `string`

Default: `null`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: The lock level to apply. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.

Type:

```hcl
object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
```

Default: `{}`

### <a name="input_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#input\_log\_analytics\_workspace\_id)

Description: Terraform Id of the Log Analytics Workspace to connect to the Container App Environment.

Type: `string`

Default: `null`

### <a name="input_managed_identities"></a> [managed\_identities](#input\_managed\_identities)

Description: Managed identities to be created for the resource.

Type:

```hcl
object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
```

Default: `{}`

### <a name="input_max_execution_count"></a> [max\_execution\_count](#input\_max\_execution\_count)

Description: The maximum number of executions (ADO jobs) to spawn per polling interval.

Type: `number`

Default: `100`

### <a name="input_min_execution_count"></a> [min\_execution\_count](#input\_min\_execution\_count)

Description: The minimum number of executions (ADO jobs) to spawn per polling interval.

Type: `number`

Default: `0`

### <a name="input_pat_token_secret_url"></a> [pat\_token\_secret\_url](#input\_pat\_token\_secret\_url)

Description: The value of the personal access token the agents will use for authenticating to Azure DevOps.  
One of 'pat\_token\_value' or 'pat\_token\_secret\_url' must be specified.

Type: `string`

Default: `null`

### <a name="input_pat_token_value"></a> [pat\_token\_value](#input\_pat\_token\_value)

Description: The value of the personal access token the agents will use for authenticating to Azure DevOps.  
One of 'pat\_token\_value' or 'pat\_token\_secret\_url' must be specified.

Type: `string`

Default: `null`

### <a name="input_placeholder_agent_name"></a> [placeholder\_agent\_name](#input\_placeholder\_agent\_name)

Description: The name of the agent that will appear in Azure DevOps for the placeholder agent.

Type: `string`

Default: `"placeholder-agent"`

### <a name="input_placeholder_container_name"></a> [placeholder\_container\_name](#input\_placeholder\_container\_name)

Description: The name of the container for the placeholder Container Apps job.

Type: `string`

Default: `"ado-agent-linux"`

### <a name="input_placeholder_replica_retry_limit"></a> [placeholder\_replica\_retry\_limit](#input\_placeholder\_replica\_retry\_limit)

Description: The number of times to retry the placeholder Container Apps job.

Type: `number`

Default: `0`

### <a name="input_placeholder_replica_timeout"></a> [placeholder\_replica\_timeout](#input\_placeholder\_replica\_timeout)

Description: The timeout in seconds for the placeholder Container Apps job.

Type: `number`

Default: `300`

### <a name="input_polling_interval_seconds"></a> [polling\_interval\_seconds](#input\_polling\_interval\_seconds)

Description: How often should the pipeline queue be checked for new events, in seconds.

Type: `number`

Default: `30`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description: A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_runner_agent_cpu"></a> [runner\_agent\_cpu](#input\_runner\_agent\_cpu)

Description: Required CPU in cores, e.g. 0.5

Type: `number`

Default: `1`

### <a name="input_runner_agent_memory"></a> [runner\_agent\_memory](#input\_runner\_agent\_memory)

Description: Required memory, e.g. '250Mb'

Type: `string`

Default: `"2Gi"`

### <a name="input_runner_container_name"></a> [runner\_container\_name](#input\_runner\_container\_name)

Description: The name of the container for the runner Container Apps job.

Type: `string`

Default: `"ado-agent-linux"`

### <a name="input_runner_replica_retry_limit"></a> [runner\_replica\_retry\_limit](#input\_runner\_replica\_retry\_limit)

Description: The number of times to retry the runner Container Apps job.

Type: `number`

Default: `3`

### <a name="input_runner_replica_timeout"></a> [runner\_replica\_timeout](#input\_runner\_replica\_timeout)

Description: The timeout in seconds for the runner Container Apps job.

Type: `number`

Default: `1800`

### <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix)

Description: The address prefix for the Container App Environment. Either subnet\_id or subnet\_name and subnet\_address\_prefix must be specified.

Type: `string`

Default: `""`

### <a name="input_subnet_creation_enabled"></a> [subnet\_creation\_enabled](#input\_subnet\_creation\_enabled)

Description: Whether or not to create a subnet for the Container App Environment.

Type: `bool`

Default: `true`

### <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id)

Description: The ID of a pre-existing gateway subnet to use for the Container App Environment. Either subnet\_id or subnet\_name and subnet\_address\_prefix must be specified.

Type: `string`

Default: `""`

### <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name)

Description: The subnet name for the Container App Environment. Either subnet\_id or subnet\_name and subnet\_address\_prefix must be specified.

Type: `string`

Default: `""`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: The map of tags to be applied to the resource

Type: `map(any)`

Default: `{}`

### <a name="input_target_pipeline_queue_length"></a> [target\_pipeline\_queue\_length](#input\_target\_pipeline\_queue\_length)

Description: The target number of jobs in the ADO pool queue.

Type: `number`

Default: `1`

### <a name="input_tracing_tags_enabled"></a> [tracing\_tags\_enabled](#input\_tracing\_tags\_enabled)

Description: Whether enable tracing tags that generated by BridgeCrew Yor.

Type: `bool`

Default: `false`

### <a name="input_tracing_tags_prefix"></a> [tracing\_tags\_prefix](#input\_tracing\_tags\_prefix)

Description: Default prefix for generated tracing tags

Type: `string`

Default: `"avm_"`

## Outputs

The following outputs are exported:

### <a name="output_resource"></a> [resource](#output\_resource)

Description: The container app environment.

### <a name="output_resource_placeholder_job"></a> [resource\_placeholder\_job](#output\_resource\_placeholder\_job)

Description: The placeholder job.

### <a name="output_resource_runner_job"></a> [resource\_runner\_job](#output\_resource\_runner\_job)

Description: The runner job.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->