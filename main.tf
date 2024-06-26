resource "azurerm_resource_group" "rg" {
  count    = var.resource_group_creation_enabled ? 1 : 0
  name     = coalesce(var.resource_group_name, "rg-${var.name}")
  location = var.location

  lifecycle {
    precondition {
      condition     = var.location != null
      error_message = "location must be specified when resource_group_creation_enabled == true"
    }
  }
}

data "azurerm_resource_group" "rg" {
  count = var.resource_group_creation_enabled ? 0 : 1
  name  = var.resource_group_name
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock.kind != "None" ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_container_app_environment.ado_agent_container_app.id
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_container_app_environment.ado_agent_container_app.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# resources
resource "azurerm_virtual_network" "ado_agents_vnet" {
  count = var.virtual_network_creation_enabled ? 1 : 0

  address_space       = [var.virtual_network_address_space]
  location            = try(azurerm_resource_group.rg[0].location, data.azurerm_resource_group.rg[0].location)
  name                = coalesce(var.virtual_network_name, "vnet-${var.name}")
  resource_group_name = try(azurerm_resource_group.rg[0].name, data.azurerm_resource_group.rg[0].name)
}

data "azurerm_virtual_network" "ado_agents_vnet" {
  count = var.virtual_network_creation_enabled ? 0 : 1

  name                = var.virtual_network_name
  resource_group_name = var.virtual_network_resource_group_name
}

resource "azurerm_subnet" "ado_agents_subnet" {
  count = var.subnet_creation_enabled ? 1 : 0

  address_prefixes     = [var.subnet_address_prefix]
  name                 = coalesce(var.subnet_name, "snet-${var.name}")
  resource_group_name  = try(azurerm_virtual_network.ado_agents_vnet[0].resource_group_name, var.virtual_network_resource_group_name)
  virtual_network_name = try(azurerm_virtual_network.ado_agents_vnet[0].name, var.virtual_network_name)
}

resource "azurerm_container_app_environment" "ado_agent_container_app" {
  location                       = try(azurerm_resource_group.rg[0].location, data.azurerm_resource_group.rg[0].location)
  name                           = coalesce(var.container_app_environment_name, "cae-${var.name}")
  resource_group_name            = try(azurerm_resource_group.rg[0].name, data.azurerm_resource_group.rg[0].name)
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

resource "azapi_resource" "runner_job" {
  type = "Microsoft.App/jobs@2023-05-01"
  body = jsonencode({
    properties = {
      environmentId = azurerm_container_app_environment.ado_agent_container_app.id
      configuration = {
        replicaRetryLimit = var.runner_replica_retry_limit
        replicaTimeout    = var.runner_replica_timeout
        registries        = var.azure_container_registries
        eventTriggerConfig = {
          parallelism            = 1
          replicaCompletionCount = 1
          scale = {
            minExecutions   = var.min_execution_count
            maxExecutions   = var.max_execution_count
            pollingInterval = var.polling_interval_seconds
            rules = [{
              name = "azure-pipelines"
              type = "azure-pipelines"
              metadata = {
                poolName                   = var.azp_pool_name
                targetPipelinesQueueLength = tostring(var.target_pipeline_queue_length)
              }
              auth = [
                {
                  secretRef        = "personal-access-token",
                  triggerParameter = "personalAccessToken"
                },
                {
                  secretRef        = "organization-url",
                  triggerParameter = "organizationURL"
                }
              ]
            }]
          }
        }
        secrets = [
          {
            name        = "personal-access-token"
            value       = var.pat_token_value
            identity    = var.pat_token_value != null ? null : local.key_vault_user_assigned_identity
            keyVaultUrl = var.pat_token_value != null ? null : var.pat_token_secret_url
          },
          {
            name  = "organization-url"
            value = var.azp_url
          }
        ]
        triggerType = "Event"
      }
      template = {
        containers = [{
          name  = var.runner_container_name
          image = var.container_image_name
          resources = {
            cpu    = var.runner_agent_cpu
            memory = var.runner_agent_memory
          }
          env = [
            {
              name      = "AZP_TOKEN"
              secretRef = "personal-access-token"
            },
            {
              name      = "AZP_URL"
              secretRef = "organization-url"
            },
            {
              name  = "AZP_POOL"
              value = var.azp_pool_name
            }
          ]
        }]
      }
    }
  })
  location  = try(azurerm_resource_group.rg[0].location, data.azurerm_resource_group.rg[0].location)
  name      = coalesce(var.container_app_job_runner_name, "ca-runner-${var.name}")
  parent_id = try(azurerm_resource_group.rg[0].id, data.azurerm_resource_group.rg[0].id)
  tags      = null

  dynamic "identity" {
    for_each = local.managed_identities.system_assigned_user_assigned
    content {
      type         = identity.value.type
      identity_ids = identity.value.user_assigned_resource_ids
    }
  }

  lifecycle {
    replace_triggered_by = [azurerm_container_app_environment.ado_agent_container_app]

    precondition {
      condition     = var.pat_token_secret_url == null || local.key_vault_user_assigned_identity != null
      error_message = "Unable to determine identity for authenticating to Azure Key Vault. Either specify `key_vault_user_assigned_identity` or configure a single identity."
    }
  }
}

resource "azapi_resource" "placeholder_job" {
  type = "Microsoft.App/jobs@2023-05-01"
  body = jsonencode({
    properties = {
      environmentId = azurerm_container_app_environment.ado_agent_container_app.id
      configuration = {
        replicaRetryLimit = var.placeholder_replica_retry_limit
        replicaTimeout    = var.placeholder_replica_timeout
        registries        = var.azure_container_registries
        manualTriggerConfig = {
          parallelism            = 1
          replicaCompletionCount = 1
        }
        secrets = [
          {
            name        = "personal-access-token"
            value       = var.pat_token_value
            identity    = var.pat_token_value != null ? null : local.key_vault_user_assigned_identity
            keyVaultUrl = var.pat_token_value != null ? null : var.pat_token_secret_url
          },
          {
            name  = "organization-url"
            value = var.azp_url
          }
        ]
        triggerType = "Manual"
      }
      template = {
        containers = [{
          name  = var.placeholder_container_name
          image = var.container_image_name
          resources = {
            cpu    = 1.0
            memory = "2Gi"
          }
          env = [
            {
              name      = "AZP_TOKEN"
              secretRef = "personal-access-token"
            },
            {
              name      = "AZP_URL"
              secretRef = "organization-url"
            },
            {
              name  = "AZP_POOL"
              value = var.azp_pool_name
            },
            {
              name  = "AZP_PLACEHOLDER"
              value = "1"
            },
            {
              name  = "AZP_AGENT_NAME"
              value = var.placeholder_agent_name
            }
          ]
        }]
      }
    }
  })
  location  = try(azurerm_resource_group.rg[0].location, data.azurerm_resource_group.rg[0].location)
  name      = coalesce(var.container_app_job_placeholder_name, "ca-placeholder-${var.name}")
  parent_id = try(azurerm_resource_group.rg[0].id, data.azurerm_resource_group.rg[0].id)
  tags      = null

  dynamic "identity" {
    for_each = local.managed_identities.system_assigned_user_assigned
    content {
      type         = identity.value.type
      identity_ids = identity.value.user_assigned_resource_ids
    }
  }

  lifecycle {
    replace_triggered_by = [azurerm_container_app_environment.ado_agent_container_app]

    precondition {
      condition     = var.pat_token_secret_url == null || local.key_vault_user_assigned_identity != null
      error_message = "Unable to determine identity for authenticating to Azure Key Vault. Either specify `key_vault_user_assigned_identity` or configure a single identity."
    }
  }
}
