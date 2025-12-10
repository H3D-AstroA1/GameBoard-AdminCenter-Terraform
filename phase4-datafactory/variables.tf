variable "admincenter_tenant_id" {
  description = "Tenant ID for AdminCenter"
  type        = string
}

variable "admincenter_subscription_id" {
  description = "Subscription ID for AdminCenter"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name created in Phase 2"
  type        = string
  default     = "logs-migration-rg"
}

variable "data_factory_name" {
  description = "Name of Data Factory created in Phase 2"
  type        = string
  default     = "gameboard-logs-adf"
}

variable "storage_account_name" {
  description = "Name of storage account created in Phase 2"
  type        = string
}

variable "gameboard_tenant_id" {
  description = "Tenant ID for GameBoard"
  type        = string
}

variable "gameboard_subscription_id" {
  description = "Subscription ID for GameBoard"
  type        = string
}

variable "gameboard_service_principal_app_id" {
  description = "App ID of service principal created in Phase 1"
  type        = string
}

variable "gameboard_workspace_name" {
  description = "Name of GameBoard Log Analytics workspace"
  type        = string
}

variable "gameboard_workspace_id" {
  description = "Full resource ID of GameBoard Log Analytics workspace"
  type        = string
}

variable "kusto_query" {
  description = "KQL query to filter logs (optional, defaults to all logs from last 24 hours)"
  type        = string
  default     = null
}

variable "key_vault_url" {
  description = "URL of Key Vault for storing secrets (optional)"
  type        = string
  default     = null
}
