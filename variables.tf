variable "name" {
  type        = string
  description = "Prefix used for naming the container app environment and container app jobs."

  validation {
    condition     = length(var.name) <= 20
    error_message = "Variable 'name' must be less than 20 characters due to container app job naming restrictions. '${var.name}' is ${length(var.name)} characters."
  }
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

# required AVM interfaces
# remove only if not supported by the resource
# tflint-ignore: terraform_unused_declarations
variable "customer_managed_key" {
  type = object({
    key_vault_resource_id              = optional(string)
    key_name                           = optional(string)
    key_version                        = optional(string, null)
    user_assigned_identity_resource_id = optional(string, null)
  })
  default     = {}
  description = "Customer managed keys that should be associated with the resource."
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "location" {
  type        = string
  default     = null
  description = "Azure region where the resource should be deployed.  If null, the location will be inferred from the resource group location."
}

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  default     = {}
  description = "The lock level to apply. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`."
  nullable    = false

  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = "Managed identities to be created for the resource."
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(any)
  default     = {}
  description = "The map of tags to be applied to the resource"
}

variable "azp_url" {
  type        = string
  description = "URL for the Azure DevOps project."
  nullable    = false
}

variable "azp_pool_name" {
  type        = string
  description = "Name of the pool that agents should register against in Azure DevOps."
  nullable    = false
}

variable "container_image_name" {
  type        = string
  description = "Fully qualified name of the Docker image the agents should run."
  nullable    = false
}

variable "container_registry_login_server" {
  type        = string
  description = "Login server url for the Azure Container Registry hosting the image."
  nullable    = false
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Terraform Id of the Log Analytics Workspace to connect to the Container App Environment."
  nullable    = true
  default = null
}

variable "virtual_network" {
  type = object({
    name = string
    resource_group_name = string
  })
  description = "Object defining the virtual network the container app environment subnet should be created within."
}

variable "subnet" {
  type = object({
    name = optional(string)
    address_prefixes = list(string)
    service_endpoints = optional(list(string))
  })
  description = <<DESCRIPTION
The configuration for the Container App Environment subnet.:
- `name`: Name of the subnet.
- `address_prefixes`: List of valid CIDR blocks for the subnet. A consumption plan Container App Environment requires a /23 or larger.
- `service_endpoints`: An optional list of service endpoints to add to the subnet.
DESCRIPTION
}

variable "pat_token_secret_url" {
  type        = string
  description = <<DESCRIPTION
The value of the personal access token the agents will use for authenticating to Azure DevOps.
One of 'pat_token_value' or 'pat_token_secret_url' must be specified.
DESCRIPTION
  nullable    = true
  default = null
}

variable "pat_token_value" {
  type        = string
  description = <<DESCRIPTION
The value of the personal access token the agents will use for authenticating to Azure DevOps.
One of 'pat_token_value' or 'pat_token_secret_url' must be specified.
DESCRIPTION
  nullable    = true
  default = null
}

variable "polling_interval_seconds" {
  type        = number
  default     = 30
  description = "How often should the pipeline queue be checked for new events, in seconds."
}

variable "min_execution_count" {
  type        = number
  default     = 0
  description = "The minimum number of executions (ADO jobs) to spawn per polling interval."
}

variable "max_execution_count" {
  type        = number
  default     = 100
  description = "The maximum number of executions (ADO jobs) to spawn per polling interval."
}

variable "target_pipeline_queue_length" {
  type        = number
  default     = 1
  description = "The target number of jobs in the ADO pool queue."
}

variable "container_app_job_runner_name" {
  type        = string
  description = "The name of the Container App runner job."
  default     = null
}

variable "container_app_job_placeholder_name" {
  type        = string
  description = "The name of the Container App placeholder job."
  default     = null
}

variable "container_app_environment_name" {
  type        = string
  description = "The name of the Container App Environment."
  default     = null
}

variable "key_vault_user_assigned_identity" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The user assigned identity to use to authenticate with Key Vault.
Must be specified if multiple user assigned are specified in `managed_identities`.
DESCRIPTION
}

variable "container_registry_user_assigned_identity" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The user assigned identity to use to authenticate with Azure container registry.
Must be specified if multiple user assigned are specified in `managed_identities`.
DESCRIPTION
}

variable "placeholder_replica_retry_limit" {
  type        = number
  default     = 0
  description = "The number of times to retry the placeholder Container Apps job."
}

variable "runner_replica_retry_limit" {
  type        = number
  default     = 3
  description = "The number of times to retry the runner Container Apps job."
}

variable "placeholder_replica_timeout" {
  type        = number
  default     = 300
  description = "The timeout in seconds for the placeholder Container Apps job."
}

variable "runner_replica_timeout" {
  type        = number
  default     = 1800
  description = "The timeout in seconds for the runner Container Apps job."
}

variable "placeholder_container_name" {
  type        = string
  default     = "ado-agent-linux"
  description = "The name of the container for the placeholder Container Apps job."
}

variable "runner_container_name" {
  type        = string
  default     = "ado-agent-linux"
  description = "The name of the container for the runner Container Apps job."
}

variable "placeholder_agent_name" {
  type        = string
  default     = "placeholder-agent"
  description = "The name of the agent that will appear in Azure DevOps for the placeholder agent."
}

variable "runner_agent_cpu" {
  type        = number
  default     = 1.0
  description = "Required CPU in cores, e.g. 0.5"
}

variable "runner_agent_memory" {
  type        = string
  default     = "2Gi"
  description = "Required memory, e.g. '250Mb'"
}