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
  alias = "gameboard"

  features {}

  subscription_id = var.gameboard_subscription_id
  tenant_id       = var.gameboard_tenant_id
}

# Data source: Get current context
data "azurerm_client_config" "gameboard" {
  provider = azurerm.gameboard
}

# Data source: Get existing Log Analytics Workspace
data "azurerm_log_analytics_workspace" "gameboard" {
  provider            = azurerm.gameboard
  name                = var.gameboard_workspace_name
  resource_group_name = var.gameboard_resource_group
}

# Create Service Principal for cross-tenant access
resource "azuread_service_principal" "gameboard_sp" {
  provider = azurerm.gameboard

  client_id = azuread_application.gameboard_app.client_id
  use_existing = true
}

resource "azuread_application" "gameboard_app" {
  provider = azurerm.gameboard

  display_name = "GameBoard-Log-Reader-SP"
}

# Get the object ID of the Service Principal
resource "azuread_service_principal_password" "sp_password" {
  provider = azurerm.gameboard

  service_principal_id = azuread_service_principal.gameboard_sp.object_id
  end_date             = "2099-12-31T23:59:59Z"

  depends_on = [azuread_service_principal.gameboard_sp]
}

# Grant Log Analytics Reader role to Service Principal on the workspace
resource "azurerm_role_assignment" "gameboard_log_analytics_reader" {
  provider = azurerm.gameboard

  scope              = data.azurerm_log_analytics_workspace.gameboard.id
  role_definition_name = "Log Analytics Reader"
  principal_id       = azuread_service_principal.gameboard_sp.object_id

  depends_on = [azuread_service_principal.gameboard_sp]
}

# Also grant Monitoring Reader at subscription level for breadth
resource "azurerm_role_assignment" "gameboard_monitoring_reader" {
  provider = azurerm.gameboard

  scope               = "/subscriptions/${var.gameboard_subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id        = azuread_service_principal.gameboard_sp.object_id

  depends_on = [azuread_service_principal.gameboard_sp]
}
