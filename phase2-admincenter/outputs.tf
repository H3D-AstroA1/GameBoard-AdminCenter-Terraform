output "managed_identity_client_id" {
  description = "Client ID of user-assigned managed identity - needed for Phase 3"
  value       = azurerm_user_assigned_identity.data_factory_mi.client_id
  sensitive   = false
}

output "managed_identity_principal_id" {
  description = "Principal ID of user-assigned managed identity"
  value       = azurerm_user_assigned_identity.data_factory_mi.principal_id
  sensitive   = false
}

output "managed_identity_resource_id" {
  description = "Resource ID of user-assigned managed identity"
  value       = azurerm_user_assigned_identity.data_factory_mi.id
  sensitive   = false
}

output "data_factory_name" {
  description = "Name of the Data Factory instance"
  value       = azurerm_data_factory.logs_migration_adf.name
  sensitive   = false
}

output "data_factory_id" {
  description = "ID of the Data Factory instance"
  value       = azurerm_data_factory.logs_migration_adf.id
  sensitive   = false
}

output "storage_account_name" {
  description = "Name of the storage account for destination logs"
  value       = azurerm_storage_account.logs_storage.name
  sensitive   = false
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.logs_storage.id
  sensitive   = false
}

output "storage_container_name" {
  description = "Name of the storage container for GameBoard logs"
  value       = azurerm_storage_container.gameboard_logs_container.name
  sensitive   = false
}

output "resource_group_name" {
  description = "Name of the resource group created"
  value       = azurerm_resource_group.logs_migration.name
  sensitive   = false
}
