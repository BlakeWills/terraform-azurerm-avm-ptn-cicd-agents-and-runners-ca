variable "azp_pool_name" {
  type        = string
  description = "Name of the pool that agents should register against in Azure DevOps."
  nullable    = false
}

variable "azp_url" {
  type        = string
  description = "URL for the Azure DevOps project."
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

variable "virtual_network_name" {
  type        = string
  description = "The name of the Virtual Network."
}

variable "virtual_network_resource_group_name" {
  type        = string
  description = "The name of the Virtual Network's Resource Group."
}

variable "container_app_environment_name" {
  type        = string
  default     = null
  description = "The name of the Container App Environment."
}

variable "container_app_job_placeholder_name" {
  type        = string
  default     = null
  description = "The name of the Container App placeholder job."
}

variable "container_app_job_runner_name" {
  type        = string
  default     = null
  description = "The name of the Container App runner job."
}

variable "container_registry_user_assigned_identity" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The user assigned identity to use to authenticate with Azure container registry.
Must be specified if multiple user assigned are specified in `managed_identities`.
DESCRIPTION
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

variable "key_vault_user_assigned_identity" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The user assigned identity to use to authenticate with Key Vault.
Must be specified if multiple user assigned are specified in `managed_identities`.
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

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "Terraform Id of the Log Analytics Workspace to connect to the Container App Environment."
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

variable "max_execution_count" {
  type        = number
  default     = 100
  description = "The maximum number of executions (ADO jobs) to spawn per polling interval."
}

variable "min_execution_count" {
  type        = number
  default     = 0
  description = "The minimum number of executions (ADO jobs) to spawn per polling interval."
}

variable "pat_token_secret_url" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The value of the personal access token the agents will use for authenticating to Azure DevOps.
One of 'pat_token_value' or 'pat_token_secret_url' must be specified.
DESCRIPTION
}

variable "pat_token_value" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The value of the personal access token the agents will use for authenticating to Azure DevOps.
One of 'pat_token_value' or 'pat_token_secret_url' must be specified.
DESCRIPTION
}

variable "placeholder_agent_name" {
  type        = string
  default     = "placeholder-agent"
  description = "The name of the agent that will appear in Azure DevOps for the placeholder agent."
}

variable "placeholder_container_name" {
  type        = string
  default     = "ado-agent-linux"
  description = "The name of the container for the placeholder Container Apps job."
}

variable "placeholder_replica_retry_limit" {
  type        = number
  default     = 0
  description = "The number of times to retry the placeholder Container Apps job."
}

variable "placeholder_replica_timeout" {
  type        = number
  default     = 300
  description = "The timeout in seconds for the placeholder Container Apps job."
}

variable "polling_interval_seconds" {
  type        = number
  default     = 30
  description = "How often should the pipeline queue be checked for new events, in seconds."
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

variable "runner_container_name" {
  type        = string
  default     = "ado-agent-linux"
  description = "The name of the container for the runner Container Apps job."
}

variable "runner_replica_retry_limit" {
  type        = number
  default     = 3
  description = "The number of times to retry the runner Container Apps job."
}

variable "runner_replica_timeout" {
  type        = number
  default     = 1800
  description = "The timeout in seconds for the runner Container Apps job."
}

variable "subnet_address_prefix" {
  type        = string
  default     = ""
  description = "The address prefix for the Container App Environment. Either subnet_id or subnet_name and subnet_address_prefix must be specified."
  nullable    = false
}

variable "subnet_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether or not to create a subnet for the Container App Environment."
  nullable    = false
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "The ID of a pre-existing gateway subnet to use for the Container App Environment. Either subnet_id or subnet_name and subnet_address_prefix must be specified."
  nullable    = false
}

variable "subnet_name" {
  type        = string
  default     = ""
  description = "The subnet name for the Container App Environment. Either subnet_id or subnet_name and subnet_address_prefix must be specified."
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(any)
  default     = {}
  description = "The map of tags to be applied to the resource"
}

variable "target_pipeline_queue_length" {
  type        = number
  default     = 1
  description = "The target number of jobs in the ADO pool queue."
}
