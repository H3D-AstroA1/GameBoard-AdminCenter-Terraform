variable "gameboard_tenant_id" {
  description = "Tenant ID for GameBoard (source)"
  type        = string
}

variable "gameboard_subscription_id" {
  description = "Subscription ID for GameBoard tenant"
  type        = string
}

variable "gameboard_resource_group" {
  description = "Resource group containing Log Analytics workspace in GameBoard"
  type        = string
}

variable "gameboard_workspace_name" {
  description = "Name of Log Analytics workspace in GameBoard"
  type        = string
}

variable "gameboard_workspace_id" {
  description = "Full resource ID of Log Analytics workspace in GameBoard"
  type        = string
  default     = ""
}
