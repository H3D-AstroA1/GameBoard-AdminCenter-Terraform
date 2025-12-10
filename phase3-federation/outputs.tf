output "federated_credential_name" {
  description = "Name of the federated identity credential created"
  value       = azuread_application_federated_identity_credential.cross_tenant_federation.display_name
  sensitive   = false
}

output "federation_status" {
  description = "Indicates if federation was successfully created"
  value       = local.federation_created ? "Successfully created" : "Failed"
  sensitive   = false
}

output "issuer_url" {
  description = "The issuer URL for the federated credential"
  value       = "https://login.microsoftonline.com/${var.admincenter_tenant_id}/v2.0"
  sensitive   = false
}

output "subject_id" {
  description = "The subject (managed identity client ID) of the federated credential"
  value       = var.managed_identity_client_id
  sensitive   = false
}
