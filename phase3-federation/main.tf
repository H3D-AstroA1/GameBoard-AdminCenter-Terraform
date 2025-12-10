terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.40"
    }
  }
}

provider "azurerm" {
  alias = "gameboard"

  features {}

  subscription_id = var.gameboard_subscription_id
  tenant_id       = var.gameboard_tenant_id
}

provider "azuread" {
  alias = "gameboard"

  tenant_id = var.gameboard_tenant_id
}

# Get the service principal created in Phase 1
resource "azuread_application" "gameboard_app_reference" {
  provider = azuread.gameboard

  display_name = "GameBoard-Log-Reader-SP"
}

# Create federated identity credential
# This allows AdminCenter's managed identity to authenticate as GameBoard's service principal
resource "azuread_application_federated_identity_credential" "cross_tenant_federation" {
  provider = azuread.gameboard

  application_object_id = azuread_application.gameboard_app_reference.object_id
  display_name          = "AdminCenter-Federation"
  
  # The issuer is AdminCenter's tenant
  issuer   = "https://login.microsoftonline.com/${var.admincenter_tenant_id}/v2.0"
  
  # The subject is AdminCenter's managed identity client ID
  subject  = var.managed_identity_client_id
  
  # Audience for Azure token exchange
  audiences = ["api://AzureADTokenExchange"]

  depends_on = [azuread_application.gameboard_app_reference]
}

# Verify the credential was created by output
locals {
  federation_created = azuread_application_federated_identity_credential.cross_tenant_federation.id != null
}
