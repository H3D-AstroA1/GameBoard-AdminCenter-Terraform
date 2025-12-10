# GameBoard to AdminCenter Log Migration - Terraform Implementation

**Objective:** Automatically migrate all raw logs from GameBoard Tenant's Log Analytics Workspace to AdminCenter Tenant using Terraform and Azure Data Factory

**Architecture:**
```
GameBoard Tenant                    AdminCenter Tenant
├── Log Analytics Workspace    →    ├── Data Factory
├── Service Principal          →    ├── Managed Identity
└── Diagnostics              →    ├── Storage Account (ADLS Gen2)
                                   └── Log Analytics Workspace (optional)
```

**Total Setup Time:** 20-30 minutes  
**Cost:** ~$40-80/month  
**Zero Secrets:** Uses workload identity federation (no passwords stored)

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Phase 1: GameBoard Tenant Setup](#phase-1-gameboard-tenant-setup)
4. [Phase 2: AdminCenter Tenant Setup](#phase-2-admincenter-tenant-setup)
5. [Phase 3: Workload Identity Federation](#phase-3-workload-identity-federation)
6. [Phase 4: Deploy Everything](#phase-4-deploy-everything)
7. [Validation & Testing](#validation--testing)
8. [Cleanup](#cleanup)

---

## Prerequisites

### Tools Required
- [Terraform](https://www.terraform.io/downloads) (v1.0+)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- PowerShell or Bash shell
- Text editor (VS Code recommended)

### Azure Requirements
- Two Azure subscriptions (GameBoard and AdminCenter)
- Owner/Admin access in both tenants
- Existing Log Analytics Workspace in GameBoard Tenant

### Information Needed Before Starting
```
GAMEBOARD TENANT:
- Tenant ID: _____________________
- Subscription ID: _____________________
- Resource Group: _____________________
- Log Analytics Workspace Name: _____________________
- Log Analytics Workspace Resource ID: _____________________

ADMINCENTER TENANT:
- Tenant ID: _____________________
- Subscription ID: _____________________
- Location (e.g., eastus): _____________________
- Environment (dev/prod): _____________________
```

Get this info with:
```powershell
# GameBoard Tenant
az login --tenant <GAMEBOARD_TENANT_ID>
az account list --output table

# List Log Analytics Workspaces
az resource list --resource-type "Microsoft.OperationalInsights/workspaces" --output table
```

---

## Project Structure

```
GameBoard-AdminCenter-Terraform/
├── README.md                          # This file
├── terraform.tfvars                  # Variables (FILL THIS IN)
├── 
├── phase1-gameboard/                 # GameBoard setup
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── phase2-admincenter/               # AdminCenter setup
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
│
├── phase3-federation/                # Workload identity federation
│   ├── main.tf
│   ├── variables.tf
│   └── provider.tf
│
└── phase4-datafactory/               # Data Factory pipeline
    ├── main.tf
    ├── variables.tf
    ├── datasets.tf
    ├── pipeline.tf
    └── provider.tf
```

---

## Phase 1: GameBoard Tenant Setup

**What this does:**
- Creates service principal for cross-tenant authentication
- Grants Log Analytics Reader permissions
- Outputs credentials needed for next phase

**File:** `phase1-gameboard/main.tf`

### Step 1.1: Navigate to Phase 1

```bash
cd GameBoard-AdminCenter-Terraform/phase1-gameboard
```

### Step 1.2: Login to GameBoard Tenant

```powershell
az login --tenant <GAMEBOARD_TENANT_ID>
az account set --subscription <GAMEBOARD_SUBSCRIPTION_ID>
```

### Step 1.3: Initialize Terraform

```bash
terraform init
```

### Step 1.4: Review Plan

```bash
terraform plan
```

**Look for:**
- Service Principal creation
- Role assignment for Log Analytics Reader
- No errors in output

### Step 1.5: Apply Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm.

### Step 1.6: Capture Outputs

```bash
terraform output
```

**Save these values:**
```
SERVICE_PRINCIPAL_APP_ID = (save this)
SERVICE_PRINCIPAL_TENANT_ID = (save this)
SERVICE_PRINCIPAL_OBJECT_ID = (save this)
```

Store in `terraform.tfvars` for next phases.

---

## Phase 2: AdminCenter Tenant Setup

**What this does:**
- Creates managed identity (zero-secrets auth)
- Creates Data Factory
- Creates storage account and container
- Grants all necessary permissions
- Outputs identities for federation

**File:** `phase2-admincenter/main.tf`

### Step 2.1: Login to AdminCenter Tenant

```powershell
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
az account set --subscription <ADMINCENTER_SUBSCRIPTION_ID>
```

### Step 2.2: Navigate to Phase 2

```bash
cd ../phase2-admincenter
terraform init
```

### Step 2.3: Review and Apply

```bash
terraform plan
terraform apply
```

### Step 2.4: Capture Outputs

```bash
terraform output
```

**Save these values:**
```
MANAGED_IDENTITY_CLIENT_ID = (save this)
MANAGED_IDENTITY_PRINCIPAL_ID = (save this)
DATA_FACTORY_NAME = (save this)
STORAGE_ACCOUNT_NAME = (save this)
```

---

## Phase 3: Workload Identity Federation

**What this does:**
- Creates trust between AdminCenter MI and GameBoard SP
- Enables zero-secrets authentication
- Sets up federated credentials

**File:** `phase3-federation/main.tf`

### Step 3.1: Back to GameBoard Tenant

```powershell
az logout
az login --tenant <GAMEBOARD_TENANT_ID>
az account set --subscription <GAMEBOARD_SUBSCRIPTION_ID>
```

### Step 3.2: Initialize and Apply

```bash
cd ../phase3-federation
terraform init
terraform plan
terraform apply
```

**This step requires:**
- SERVICE_PRINCIPAL_APP_ID (from Phase 1)
- MANAGED_IDENTITY_CLIENT_ID (from Phase 2)
- ADMINCENTER_TENANT_ID

Make sure these are in your `terraform.tfvars`.

---

## Phase 4: Deploy Everything

**What this does:**
- Creates Data Factory linked services
- Creates datasets for source and destination
- Creates copy pipeline
- Creates schedule trigger (daily)

**File:** `phase4-datafactory/main.tf`

### Step 4.1: AdminCenter Tenant Again

```powershell
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
az account set --subscription <ADMINCENTER_SUBSCRIPTION_ID>
```

### Step 4.2: Deploy

```bash
cd ../phase4-datafactory
terraform init
terraform plan
terraform apply
```

### Step 4.3: Verify Pipeline Created

```bash
terraform output
```

Output should show:
- Pipeline name
- Trigger schedule
- Linked service names

---

## Validation & Testing

### Test 1: Verify All Resources Created

```powershell
# In AdminCenter Tenant
az datafactory list --output table
az storage account list --output table
az identity list --output table
```

### Test 2: Trigger Manual Pipeline Run

```powershell
# Set these variables
$dataFactoryName = "terraform-adf"
$pipelineNamemigration-pipeline"
$resourceGroup = "logs-migration-rg"

# Trigger pipeline
az datafactory run create `
  --resource-group $resourceGroup `
  --factory-name $dataFactoryName `
  --name $pipelineName

# Check status
az datafactory run show `
  --resource-group $resourceGroup `
  --factory-name $dataFactoryName `
  --run-id <RUN_ID_FROM_ABOVE>
```

### Test 3: Verify Logs Copied

```bash
# Check storage for copied logs
az storage blob list \
  --account-name $(terraform output storage_account_name -raw) \
  --container-name gameboard-logs \
  --output table
```

Expected output: Files like `logs/2025-12-10/data.parquet`

### Test 4: Check Log Analytics (if destination LA created)

```kusto
// In AdminCenter Log Analytics
union withsource=TableName *
| take 100
```

---

## Cleanup (If Needed)

To destroy all resources and avoid charges:

```bash
# Phase 4
cd phase4-datafactory
terraform destroy

# Phase 3
cd ../phase3-federation
terraform destroy

# Phase 2 (AdminCenter)
cd ../phase2-admincenter
terraform destroy

# Phase 1 (GameBoard)
cd ../phase1-gameboard
az logout
az login --tenant <GAMEBOARD_TENANT_ID>
az account set --subscription <GAMEBOARD_SUBSCRIPTION_ID>
terraform destroy
```

---

## Terraform Variables Reference

### terraform.tfvars Template

```hcl
# GameBoard Tenant (Source)
gameboard_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gameboard_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gameboard_resource_group  = "existing-rg"
gameboard_workspace_name  = "existing-logs-workspace"
gameboard_workspace_id    = "/subscriptions/.../workspaces/existing-logs-workspace"

# AdminCenter Tenant (Destination)
admincenter_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
admincenter_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
admincenter_resource_group  = "logs-migration-rg"
admincenter_location        = "eastus"
environment                 = "prod"

# Cross-tenant settings
service_principal_app_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From Phase 1
managed_identity_client_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From Phase 2
```

---

## Troubleshooting

### Error: "Subscription Not Found"

```powershell
# Verify you're logged into correct tenant
az account show
az account set --subscription <SUBSCRIPTION_ID>
```

### Error: "Insufficient Permissions"

```powershell
# Check your roles
az role assignment list --assignee-object-id <YOUR_OBJECT_ID>

# You need Owner or high-privilege role to create resources
```

### Error: "Resource Already Exists"

If you're getting conflicts, either:
1. Change resource names in `terraform.tfvars`
2. Import existing resources into Terraform state
3. Destroy and recreate

### Pipeline Not Running

1. Check Data Factory → Monitor → Pipeline runs
2. Verify linked services have successful test connections
3. Check Managed Identity has correct roles
4. Review Azure Data Factory logs

---

## Next Steps

### Make it Production-Ready
1. **Add remote state**: Use Azure Storage for Terraform state
2. **Add monitoring**: Alert on pipeline failures
3. **Add versioning**: Store in Git with CI/CD
4. **Customize schedule**: Change trigger frequency in `phase4-datafactory/main.tf`

### Customize Log Filtering
Edit the KQL query in `phase4-datafactory/pipeline.tf`:
```kusto
// Only collect Warning and Error level logs
AzureActivity
| where Level in ("Warning", "Error")
| where TimeGenerated > ago(24h)
```

### Scale to Multiple Workspaces
Create additional pipeline runs for each GameBoard workspace:
```hcl
# In phase4-datafactory/pipeline.tf
locals {
  source_workspaces = [
    "workspace1",
    "workspace2",
    "workspace3"
  ]
}

# Then loop and create pipelines for each
```

---

## File-by-File Reference

| File | Purpose | What It Creates |
|------|---------|-----------------|
| `phase1-gameboard/main.tf` | Source tenant auth | Service Principal, Role assignment |
| `phase2-admincenter/main.tf` | Destination infrastructure | Data Factory, Storage, Managed Identity |
| `phase3-federation/main.tf` | Cross-tenant trust | Federated identity credential |
| `phase4-datafactory/main.tf` | Pipeline setup | Linked services, integration runtime |
| `phase4-datafactory/datasets.tf` | Data definitions | Source and destination datasets |
| `phase4-datafactory/pipeline.tf` | Copy logic | Copy activity, transformations |

---

## Success Checklist

- [ ] Filled in `terraform.tfvars` with your values
- [ ] Ran Phase 1 in GameBoard Tenant successfully
- [ ] Captured service principal outputs
- [ ] Ran Phase 2 in AdminCenter Tenant successfully
- [ ] Captured managed identity outputs
- [ ] Ran Phase 3 federation setup
- [ ] Ran Phase 4 Data Factory deployment
- [ ] Manual pipeline test successful
- [ ] Verified logs in destination storage
- [ ] Optional: Set up monitoring/alerts

---

## Getting Help

### Common Resources
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Data Factory Docs](https://learn.microsoft.com/en-us/azure/data-factory/)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)

### Debug Mode
```bash
# Show detailed logs
export TF_LOG=DEBUG
terraform apply

# Unset after
unset TF_LOG
```

---

**Created:** December 2025  
**Version:** 1.0  
**Status:** Ready for Production
