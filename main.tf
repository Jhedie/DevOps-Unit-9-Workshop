terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.43.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "1-4928fdb4-playground-sandbox"
    storage_account_name = "jhediestorage"
    container_name       = "jhedie-storage"
    key                  = "prod.terraform.tfstate"
  }
}

resource "random_password" "db_password" {
  length           = 32
  min_lower        = 1
  min_numeric      = 1
  min_upper        = 1
  min_special      = 1
  override_special = "_%!"
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  subscription_id                 = "28e1e42a-4438-4c30-9a5f-7d7b488fd883"
}

data "azurerm_resource_group" "main" {
  name = "1-4928fdb4-playground-sandbox"
}

resource "azurerm_service_plan" "main" {
  name                = "jhedie-terraformed-asp"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
}


resource "azurerm_linux_web_app" "main" {
  name                = "jhedie-terraformed-webapp"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  app_settings = {
    CONNECTION_STRING = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${azurerm_mssql_server.main.administrator_login};Password=${random_password.db_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    DEPLOYMENT_METHOD = "Terraform"
  }
  site_config {
    application_stack {
      docker_image_name   = "corndeldevopscourse/mod12app:latest"
      docker_registry_url = "https://index.docker.io"
    }
  }
}


resource "azurerm_mssql_server" "main" {
  name                         = "jhedie-non-iac-sqlserver"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = data.azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "dbadmin"
  administrator_login_password = random_password.db_password.result
}

resource "azurerm_mssql_database" "main" {
  name        = "jhedie-non-iac-db"
  server_id   = azurerm_mssql_server.main.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb = 2
  sku_name    = "Basic"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }

  # provisioner "local-exec" {
  #   command = <<EOT
  #     #!/bin/bash
  #     # Install sqlcmd (from https://github.com/microsoft/go-sqlcmd/releases/tag/v1.8.2)
  #     curl -L https://github.com/microsoft/go-sqlcmd/releases/download/v1.8.2/sqlcmd-linux-amd64.tar.bz2 -o sqlcmd.tar.bz2
  #     tar xf sqlcmd.tar.bz2 -C .

  #     ./sqlcmd \
  #       -S ${azurerm_mssql_server.main.fully_qualified_domain_name} \
  #       -d ${azurerm_mssql_database.main.name} \
  #       -U dbadmin \
  #       -P ${random_password.db_password.result} \
  #       -i db_setup.sql
  #     EOT
  #   }
}
