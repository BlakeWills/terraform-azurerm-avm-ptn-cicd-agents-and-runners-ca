# tflint-ignore: terraform_variable_separate, terraform_standard_module_structure
variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "personal_access_token" {
  type        = string
  sensitive   = true
  description = "The personal access token used for agent authentication to Azure DevOps."
}

variable "container_image_name" {
  type        = string
  description = "Name of the container image to build and push to the container registry"
  default     = "azure-pipelines:latest"
}

variable "ado_organization_url" {
  type        = string
  description = "Azure DevOps Organisation URL"
}