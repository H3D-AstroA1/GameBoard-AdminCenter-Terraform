output "service_principal_app_id" {
  description = "App ID of the service principal - needed for Phase 3"
  value       = azuread_application.gameboard_app.client_id
  sensitive   = false
}

output "service_principal_object_id" {
  description = "Object ID of the service principal - needed for Phase 3"
  value       = azuread_service_principal.gameboard_sp.object_id
  sensitive   = false
}

output "service_principal_tenant_id" {
  description = "Tenant ID where service principal was created"
  value       = data.azurerm_client_config.gameboard.tenant_id
  sensitive   = false
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = data.azurerm_log_analytics_workspace.gameboard.id
  sensitive   = false
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = data.azurerm_log_analytics_workspace.gameboard.name
  sensitive   = false
}
