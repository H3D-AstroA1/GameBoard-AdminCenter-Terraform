# Terraform Implementation Reference & Troubleshooting

## Table of Contents
1. [Variable Reference](#variable-reference)
2. [Common Issues & Solutions](#common-issues--solutions)
3. [Verification Steps](#verification-steps)
4. [File Structure Reference](#file-structure-reference)
5. [Advanced Customization](#advanced-customization)

---

## Variable Reference

### terraform.tfvars Required Variables

```hcl
# ============================================================================
# GAMEBOARD TENANT (Source)
# ============================================================================

# Tenant ID where your Log Analytics Workspace exists
gameboard_tenant_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Subscription ID containing the workspace
gameboard_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Resource group containing Log Analytics Workspace
gameboard_resource_group = "my-logs-rg"

# Name of your Log Analytics Workspace
# Example: "my-workspace" or "prod-logs"
gameboard_workspace_name = "my-workspace"

# Resource ID of your workspace (format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.OperationalInsights/workspaces/{name})
# Find via: az resource list --resource-type "Microsoft.OperationalInsights/workspaces"
gameboard_workspace_id = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-logs-rg/providers/Microsoft.OperationalInsights/workspaces/my-workspace"

# ============================================================================
# ADMINCENTER TENANT (Destination)
# ============================================================================

# Tenant ID where Data Factory will be created
admincenter_tenant_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Subscription ID for AdminCenter resources
admincenter_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# ============================================================================
# OPTIONAL VARIABLES
# ============================================================================

# Location for all resources (default: eastus)
admincenter_location = "eastus"

# Environment name for resource naming (default: prod)
environment = "prod"

# KQL query to filter logs (default: all logs from last 24 hours)
# Examples:
#   - "AzureActivity | where Level == 'Error'"
#   - "SecurityAlert | where Severity == 'High'"
#   - "AzureDiagnostics | where ResourceType == 'VAULTS'"
kusto_query = "union withsource=TableName *"

# Storage container name (default: gameboard-logs)
storage_container_name = "gameboard-logs"
```

### How to Find Your Values

**Find Tenant IDs:**
```powershell
az account list --output table
# Look for "tenantId" column
```

**Find Subscription IDs:**
```powershell
az account list --output table
# Look for "id" column (in subscription format)
```

**Find Workspace Details:**
```powershell
# List all workspaces
az resource list --resource-type "Microsoft.OperationalInsights/workspaces"

# Get specific workspace
az monitor log-analytics workspace list --output table
```

**Get Full Workspace Resource ID:**
```powershell
$workspaceName = "my-workspace"
$resourceGroup = "my-logs-rg"

az resource list `
  --resource-group $resourceGroup `
  --name $workspaceName `
  --resource-type "Microsoft.OperationalInsights/workspaces" `
  --query "[0].id" `
  --output tsv
```

---

## Common Issues & Solutions

### Issue 1: "terraform: command not found"

**Problem:** Terraform is not installed or not in PATH

**Solutions:**
1. **Windows:**
   ```powershell
   # Download from https://www.terraform.io/downloads
   # Extract to C:\terraform
   # Add to PATH in Environment Variables
   # Restart PowerShell
   ```

2. **Verify Installation:**
   ```powershell
   terraform version
   $env:PATH -split ';' | Where-Object { $_ -like '*terraform*' }
   ```

---

### Issue 2: "Subscription not found" or "Invalid subscription"

**Problem:** Azure CLI is using wrong subscription

**Solutions:**
```powershell
# Check current subscription
az account show

# Set correct subscription
az account set --subscription "YOUR-SUBSCRIPTION-ID"

# List all available subscriptions
az account list --output table
```

**During Terraform:**
```powershell
# If terraform.tfvars has wrong subscription, edit it:
$env:EDITOR = "notepad"
terraform console  # Then type: var.gameboard_subscription_id
```

---

### Issue 3: "Permission denied" or "Insufficient privileges"

**Problem:** Your Azure user doesn't have required roles

**Solutions:**
```powershell
# Check your current roles
$myObjectId = az ad signed-in-user show --query objectId -o tsv
az role assignment list --assignee-object-id $myObjectId --scope /subscriptions/YOUR-SUB-ID

# You need one of these roles:
# - Owner
# - Contributor
# - Custom role with: 
#   - Microsoft.Authorization/roleAssignments/write
#   - Microsoft.OperationalInsights/workspaces/read
#   - Microsoft.DataFactory/factories/write
```

**Ask your Azure Admin to grant:**
```powershell
# For GameBoard tenant
az role assignment create `
  --role "Contributor" `
  --assignee-object-id $myObjectId `
  --scope /subscriptions/GAMEBOARD-SUB-ID

# For AdminCenter tenant
az role assignment create `
  --role "Contributor" `
  --assignee-object-id $myObjectId `
  --scope /subscriptions/ADMINCENTER-SUB-ID
```

---

### Issue 4: "terraform.tfvars: No such file or directory"

**Problem:** Variables file not found

**Solutions:**
```powershell
# Copy example to actual file
Copy-Item terraform.tfvars.example terraform.tfvars

# Verify it exists
Test-Path terraform.tfvars

# Edit with your values
notepad terraform.tfvars
```

---

### Issue 5: "Resource already exists" or "Conflict with existing resource"

**Problem:** Resources from previous failed run still exist

**Solutions:**
```powershell
# Option 1: Let Terraform import the existing resources
terraform import azurerm_data_factory.gameboard-logs /subscriptions/.../providers/Microsoft.DataFactory/factories/...

# Option 2: Destroy and recreate
terraform destroy -auto-approve
terraform apply

# Option 3: Manually delete in Azure Portal, then retry terraform apply
```

---

### Issue 6: "Service Principal doesn't have permission to access workspace"

**Problem:** Service Principal was created but doesn't have roles yet

**Solutions:**
```powershell
# Wait 2-3 minutes for Azure AD propagation
Start-Sleep -Seconds 180

# Or manually grant the role:
$spObjectId = terraform output service_principal_object_id
$workspaceId = terraform output log_analytics_workspace_id

az role assignment create `
  --role "Log Analytics Reader" `
  --assignee-object-id $spObjectId `
  --scope $workspaceId
```

---

### Issue 7: "Federation issuer URL is invalid"

**Problem:** Workload identity federation can't validate the issuer

**Solutions:**
```powershell
# Verify issuer URL format
$tenantId = "your-admincenter-tenant-id"
$issuerUrl = "https://login.microsoftonline.com/$tenantId/v2.0"
Write-Host $issuerUrl

# Verify MI client ID matches exactly
# In Phase 3 tfvars, check: managed_identity_client_id

# If changing, destroy Phase 3 and reapply
cd phase3-federation
terraform destroy -auto-approve
terraform apply
```

---

### Issue 8: "Data Factory pipeline fails to run"

**Problem:** Copy activity shows error

**Solutions:**
```powershell
# Check Data Factory logs
az datafactory pipeline-run show `
  --resource-group "logs-migration-rg" `
  --factory-name "gameboard-logs-adf" `
  --run-id YOUR-RUN-ID

# Common causes:
# 1. Service Principal doesn't have workspace access
#    → Check Phase 1 role assignment
# 2. Federation isn't set up correctly
#    → Check Phase 3 outputs
# 3. Storage account permissions wrong
#    → Verify Phase 2 role assignments
# 4. Network connectivity issue
#    → Check if workspace is behind firewall

# Restart pipeline
az datafactory pipeline create-run `
  --resource-group "logs-migration-rg" `
  --factory-name "gameboard-logs-adf" `
  --name "Copy-GameBoard-Logs"
```

---

### Issue 9: "State file is locked"

**Problem:** Another terraform process is running

**Solutions:**
```powershell
# Wait for other process to finish
# Or force unlock (use with caution):
terraform force-unlock LOCK-ID

# View locks
terraform state list

# If state is corrupted, backup and reset
Copy-Item terraform.tfstate terraform.tfstate.backup
rm terraform.tfstate
terraform init
```

---

### Issue 10: "Logs are copied but in wrong format"

**Problem:** Files aren't in expected format

**Solutions:**
```powershell
# Check what was actually copied
$storageName = terraform output storage_account_name
az storage blob list `
  --account-name $storageName `
  --container-name gameboard-logs `
  --output table

# Verify file format
az storage blob download `
  --account-name $storageName `
  --container-name gameboard-logs `
  --name "logs/2025-12-10/data.parquet" `
  --file "test.parquet"

# Change format in Phase 4 pipeline.tf:
# Line with "format": "Parquet" → change to "Json" or "Csv"
```

---

## Verification Steps

### After Phase 1 (GameBoard Setup)

```powershell
# Verify Service Principal exists
az ad app list --filter "displayName eq 'gameboard-logs-app'"

# Verify role assignment
$spObjectId = terraform output service_principal_object_id
az role assignment list --assignee-object-id $spObjectId
```

### After Phase 2 (AdminCenter Setup)

```powershell
# Verify Data Factory
az datafactory show `
  --resource-group logs-migration-rg `
  --name gameboard-logs-adf

# Verify Storage Account
az storage account show `
  --resource-group logs-migration-rg `
  --name $storageName

# Verify Managed Identity
az identity show `
  --resource-group logs-migration-rg `
  --name gameboard-logs-mi
```

### After Phase 3 (Federation)

```powershell
# Verify Federation
az ad app federated-credential list `
  --id $spAppId

# Test token generation
$miClientId = terraform output managed_identity_client_id
az account get-access-token `
  --client-id $miClientId \
  --federated-token-file $federatedToken
```

### After Phase 4 (Pipeline)

```powershell
# Verify Pipeline
az datafactory pipeline show `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf `
  --name Copy-GameBoard-Logs

# Trigger test run
az datafactory pipeline create-run `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf \
  --name Copy-GameBoard-Logs

# Monitor run
az datafactory pipeline-run show `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf `
  --run-id YOUR-RUN-ID
```

---

## File Structure Reference

```
GameBoard-AdminCenter-Terraform/
├── README.md                           # Main documentation
├── QUICKSTART.md                       # 15-minute quick start (THIS FILE)
├── terraform.tfvars.example            # Variable template
├── deploy.sh                           # Bash automation script
├── deploy.ps1                          # PowerShell automation script
│
├── phase1-gameboard/                   # Service Principal setup
│   ├── main.tf                         # Creates Service Principal
│   ├── variables.tf                    # Input variables (tenant, subscription, etc)
│   └── outputs.tf                      # Exports: SP app ID, object ID, workspace ID
│
├── phase2-admincenter/                 # Infrastructure setup
│   ├── main.tf                         # Creates: Data Factory, Storage, Managed Identity
│   ├── variables.tf                    # Input variables
│   └── outputs.tf                      # Exports: MI client ID, ADF name, storage name
│
├── phase3-federation/                  # Workload identity federation
│   ├── main.tf                         # Creates federated credential
│   ├── variables.tf                    # Input: Tenant IDs, MI client ID, SP app ID
│   └── outputs.tf                      # Exports: Federation status, issuer URL
│
└── phase4-datafactory/                 # Copy pipeline
    ├── main.tf                         # Linked services (Log Analytics, Storage)
    ├── datasets.tf                     # Source (KQL) and sink (Parquet) datasets
    ├── pipeline.tf                     # Copy activity and daily trigger
    └── variables.tf                    # Configuration: queries, schedules, parallelism
```

### What Each Phase Creates

**Phase 1 (GameBoard):**
- Azure AD Application "gameboard-logs-app"
- Service Principal for cross-tenant authentication
- Role assignments: Log Analytics Reader, Monitoring Reader

**Phase 2 (AdminCenter):**
- Resource Group: logs-migration-rg
- User-Assigned Managed Identity: gameboard-logs-mi
- Storage Account: logstorage<random> (globally unique)
- Storage Container: gameboard-logs
- Data Factory: gameboard-logs-adf
- System-Assigned Managed Identity on Data Factory

**Phase 3 (GameBoard - Federation):**
- Federated Identity Credential on Service Principal
- Binds AdminCenter Managed Identity → GameBoard Service Principal
- Enables zero-secrets authentication

**Phase 4 (AdminCenter - Pipeline):**
- Linked Service: GameBoard Log Analytics (federated auth)
- Linked Service: AdminCenter Blob Storage (managed identity)
- Dataset: Source (Azure Log Analytics)
- Dataset: Sink (Parquet files in Blob Storage)
- Pipeline: Copy-GameBoard-Logs (copy activity + schedule)
- Trigger: Daily at 2:00 AM UTC

---

## Advanced Customization

### Change Log Copy Schedule

Edit `phase4-datafactory/pipeline.tf`:

```hcl
# Default: Daily at 2:00 AM
schedule {
  hours   = [2]
  minutes = [0]
}

# Every 6 hours:
schedule {
  hours   = [0, 6, 12, 18]
  minutes = [0]
}

# Every day at 3:30 PM:
schedule {
  hours   = [15]
  minutes = [30]
}
```

### Filter Logs Before Copying

Edit `phase4-datafactory/pipeline.tf` - find `query` parameter:

```hcl
# Only errors from last 7 days:
query = "AzureActivity | where Level == 'Error' | where TimeGenerated > ago(7d)"

# Only security alerts:
query = "SecurityAlert | where Severity == 'High' or Severity == 'Critical'"

# Specific resource types:
query = "AzureDiagnostics | where ResourceType in ('VAULTS', 'LOADBALANCERS') | where TimeGenerated > ago(1d)"
```

### Change Copy Parallelism

Edit `phase4-datafactory/pipeline.tf`:

```hcl
# Default: 4 DIUs (Data Integration Units)
diu = 4

# For larger datasets:
diu = 8  # or 16, 32, 64

# More DIUs = faster copy but higher cost
```

### Store Logs in Different Region

Edit `phase2-admincenter/main.tf`:

```hcl
location = "westus2"  # Instead of "eastus"
```

### Add Encryption to Storage

Edit `phase2-admincenter/main.tf`:

```hcl
storage_encryption {
  key_vault_uri = "https://keyvault.vault.azure.net/"
  key_name      = "storage-key"
  key_version   = "xxx"
}
```

### Compress Parquet Files

Edit `phase4-datafactory/datasets.tf`:

```hcl
compression = "snappy"  # Default
# Options: "gzip", "deflate", "none"
```

---

## Maintenance & Monitoring

### Monitor Pipeline Execution

```powershell
# Get last 10 runs
az datafactory pipeline-run query-by-pipeline `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf `
  --name Copy-GameBoard-Logs `
  --filters "operand" "PipelineName" "equals" "Copy-GameBoard-Logs" |
  ConvertFrom-Json | Select -First 10

# Get specific run details
$runId = "your-run-id"
az datafactory pipeline-run show `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf `
  --run-id $runId
```

### Check Data Transfer Costs

```powershell
# Monitor storage growth
$storageName = terraform output storage_account_name
$usage = az storage account show-usage `
  --name $storageName

# Estimate monthly cost based on:
# - Copy frequency (daily = ~30 runs/month)
# - Data volume (check container size)
# - Outbound data transfer
```

### Update Variables Without Losing State

```powershell
# Update terraform.tfvars
notepad terraform.tfvars

# See what will change
terraform plan

# Apply only if safe
terraform apply
```

---

## Rollback Procedures

### Rollback Phase (Keep Previous Phases)

```powershell
cd phase4-datafactory
terraform destroy -auto-approve
cd ..

# This deletes Data Factory, pipelines, datasets, but keeps:
# - Storage account
# - Managed Identity
# - Service Principal
# - Federation
```

### Complete Rollback (Delete Everything)

```powershell
# In reverse order of creation
cd phase4-datafactory && terraform destroy -auto-approve && cd ..
cd phase3-federation && terraform destroy -auto-approve && cd ..
cd phase2-admincenter && terraform destroy -auto-approve && cd ..
cd phase1-gameboard && terraform destroy -auto-approve && cd ..

# Clean up files
rm terraform.tfstate*
rm .phase*-outputs.json
```

---

## Support & Resources

**Official Documentation:**
- [Azure Data Factory](https://learn.microsoft.com/en-us/azure/data-factory/)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)

**Helpful Commands:**
```powershell
# View all resources created
az resource list --resource-group logs-migration-rg --output table

# Check resource group location
az group show --name logs-migration-rg

# Monitor Data Factory costs
az monitor metrics list --resource /subscriptions/.../resourceGroups/logs-migration-rg/providers/Microsoft.DataFactory/factories/gameboard-logs-adf
```

---

**Version:** 1.0 (Updated: December 2025)  
**Status:** Production-Ready  
**Support:** Check README.md Troubleshooting section
