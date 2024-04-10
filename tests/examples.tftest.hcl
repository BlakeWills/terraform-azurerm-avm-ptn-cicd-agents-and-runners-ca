provider "azurerm" {
  features {}
}

run "default" {
  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/default"
  }
}

run "with_azure_container_registry" {
  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/with_azure_container_registry"
  }
}

run "with_key_vault" {
  variables {
    personal_access_token = "my-really-secure-token"
    ado_organization_url  = "https://dev.azure.com/my-org"
  }

  module {
    source = "./examples/with_key_vault"
  }
}