variable "admincenter_tenant_id" {
  description = "Tenant ID for AdminCenter (destination)"
  type        = string
}

variable "admincenter_subscription_id" {
  description = "Subscription ID for AdminCenter tenant"
  type        = string
}

variable "admincenter_resource_group" {
  description = "Resource group name to create in AdminCenter"
  type        = string
  default     = "logs-migration-rg"
}

variable "admincenter_location" {
  description = "Azure region for resources in AdminCenter"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}
