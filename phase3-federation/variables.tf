variable "gameboard_tenant_id" {
  description = "Tenant ID for GameBoard where service principal exists"
  type        = string
}

variable "gameboard_subscription_id" {
  description = "Subscription ID for GameBoard"
  type        = string
}

variable "admincenter_tenant_id" {
  description = "Tenant ID for AdminCenter (where MI issuer is)"
  type        = string
}

variable "managed_identity_client_id" {
  description = "Client ID of AdminCenter's managed identity"
  type        = string
}

variable "service_principal_app_id" {
  description = "App ID of GameBoard service principal - needed to create federation"
  type        = string
}
