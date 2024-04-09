provider "azurerm" {
  features {}
}

run "examples_default" {
  command = plan

  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/default"
  }
}

run "examples_with_azure_container_registry" {
  command = plan

  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/with_azure_container_registry"
  }
}

run "examples_with_key_vault" {
  command = plan

  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/with_key_vault"
  }
}