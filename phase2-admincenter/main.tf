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

# Get current context for AdminCenter
data "azurerm_client_config" "admincenter" {
  provider = azurerm.admincenter
}

# Create resource group
resource "azurerm_resource_group" "logs_migration" {
  provider = azurerm.admincenter

  name     = var.admincenter_resource_group
  location = var.admincenter_location

  tags = {
    Environment = var.environment
    Purpose     = "GameBoard-Logs-Migration"
    ManagedBy   = "Terraform"
  }
}

# Create User-Assigned Managed Identity
resource "azurerm_user_assigned_identity" "data_factory_mi" {
  provider = azurerm.admincenter

  resource_group_name = azurerm_resource_group.logs_migration.name
  location            = azurerm_resource_group.logs_migration.location
  name                = "gameboard-adf-mi"

  tags = {
    Environment = var.environment
    Purpose     = "Data Factory Authentication"
  }
}

# Create Storage Account for logs
resource "azurerm_storage_account" "logs_storage" {
  provider = azurerm.admincenter

  name                     = "logstorage${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.logs_migration.name
  location                 = azurerm_resource_group.logs_migration.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  min_tls_version = "TLS1_2"

  tags = {
    Environment = var.environment
    Purpose     = "Log Storage"
  }
}

# Random suffix for globally unique storage account name
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create storage container for GameBoard logs
resource "azurerm_storage_container" "gameboard_logs_container" {
  provider = azurerm.admincenter

  name                  = "gameboard-logs"
  storage_account_name  = azurerm_storage_account.logs_storage.name
  container_access_type = "private"

  depends_on = [azurerm_storage_account.logs_storage]
}

# Grant Managed Identity access to storage (Storage Blob Data Contributor)
resource "azurerm_role_assignment" "mi_storage_contributor" {
  provider = azurerm.admincenter

  scope              = azurerm_storage_account.logs_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id       = azurerm_user_assigned_identity.data_factory_mi.principal_id

  depends_on = [azurerm_user_assigned_identity.data_factory_mi]
}

# Create Data Factory
resource "azurerm_data_factory" "logs_migration_adf" {
  provider = azurerm.admincenter

  name                = "gameboard-logs-adf"
  location            = azurerm_resource_group.logs_migration.location
  resource_group_name = azurerm_resource_group.logs_migration.name

  # Managed Identity will be associated via separate resource
  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.data_factory_mi.id]
  }

  tags = {
    Environment = var.environment
    Purpose     = "Log Migration"
  }

  depends_on = [azurerm_user_assigned_identity.data_factory_mi]
}

# Get system-assigned identity of Data Factory
resource "azurerm_role_assignment" "adf_system_identity_storage" {
  provider = azurerm.admincenter

  scope              = azurerm_storage_account.logs_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id       = azurerm_data_factory.logs_migration_adf.identity[0].principal_id

  # This ensures the system-assigned identity of ADF also has storage access
  depends_on = [azurerm_data_factory.logs_migration_adf]
}

# Create Data Factory Managed Integration Runtime (optional, for better performance)
resource "azurerm_data_factory_integration_runtime_managed" "default_ir" {
  provider = azurerm.admincenter

  name                = "default-ir"
  data_factory_id     = azurerm_data_factory.logs_migration_adf.id
  location            = azurerm_resource_group.logs_migration.location

  node_size = "General"

  depends_on = [azurerm_data_factory.logs_migration_adf]
}
