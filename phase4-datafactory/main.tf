terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  alias = "admincenter"

  features {}

  subscription_id = var.admincenter_subscription_id
  tenant_id       = var.admincenter_tenant_id
}

# Get existing resources created in Phase 2
data "azurerm_resource_group" "logs_migration" {
  provider = azurerm.admincenter

  name = var.resource_group_name
}

data "azurerm_data_factory" "logs_adf" {
  provider = azurerm.admincenter

  name                = var.data_factory_name
  resource_group_name = data.azurerm_resource_group.logs_migration.name
}

# Create Linked Service for GameBoard Log Analytics (Source)
resource "azurerm_data_factory_linked_service_azure_log_analytics" "gameboard_source" {
  provider = azurerm.admincenter

  name            = "GameBoard-LogAnalytics-Source"
  data_factory_id = data.azurerm_data_factory.logs_adf.id

  service_principal_auth {
    service_principal_id = var.gameboard_service_principal_app_id
    service_principal_key {
      linked_service_name = azurerm_data_factory_linked_service_key_vault.keyvault.name
      secret_name         = "GameBoardSPKey"
    }
    tenant_id = var.gameboard_tenant_id
  }

  workspace_id = var.gameboard_workspace_id

  depends_on = [
    azurerm_data_factory_linked_service_key_vault.keyvault
  ]
}

# Alternative: Create linked service with managed identity instead (RECOMMENDED - no secrets)
resource "azurerm_data_factory_linked_service_azure_log_analytics" "gameboard_source_mi" {
  provider = azurerm.admincenter

  name            = "GameBoard-LA-MI"
  data_factory_id = data.azurerm_data_factory.logs_adf.id

  # Use service principal but with federated credentials (no secret)
  service_principal_auth {
    service_principal_id = var.gameboard_service_principal_app_id
    tenant_id            = var.gameboard_tenant_id
    # Note: With workload identity federation, no password/key needed
  }

  workspace_id = var.gameboard_workspace_id

  lifecycle {
    ignore_changes = [service_principal_auth[0].service_principal_key]
  }
}

# Create Linked Service for AdminCenter Storage (Sink)
resource "azurerm_data_factory_linked_service_azure_blob_storage" "admincenter_sink" {
  provider = azurerm.admincenter

  name            = "AdminCenter-BlobStorage-Sink"
  data_factory_id = data.azurerm_data_factory.logs_adf.id

  # Use managed identity for authentication (zero secrets!)
  use_managed_identity = true
  storage_account_name = var.storage_account_name

  depends_on = [data.azurerm_data_factory.logs_adf]
}

# Optional: Azure Key Vault linked service (for storing any secrets if needed)
resource "azurerm_data_factory_linked_service_key_vault" "keyvault" {
  provider = azurerm.admincenter

  name            = "AdminCenter-KeyVault"
  data_factory_id = data.azurerm_data_factory.logs_adf.id

  key_vault_url = var.key_vault_url != null ? var.key_vault_url : "https://not-configured.vault.azure.net/"

  # Optional: use managed identity
  use_managed_identity = true
}
