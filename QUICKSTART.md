# ============================================================================
# GAMEBOARD TO ADMINCENTER - QUICK START GUIDE
# ============================================================================
# 
# This guide gets you running in 15 minutes with Terraform
#

## STEP 1: Prepare Your Environment (5 minutes)

1. **Install Terraform**
   Download from: https://www.terraform.io/downloads
   Add to PATH

2. **Install Azure CLI**
   Download from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

3. **Verify Installation**
   ```powershell
   terraform --version
   az --version
   ```

4. **Clone/Download Terraform Files**
   All files are in: GameBoard-AdminCenter-Terraform/
   ```
   GameBoard-AdminCenter-Terraform/
   ├── phase1-gameboard/
   ├── phase2-admincenter/
   ├── phase3-federation/
   ├── phase4-datafactory/
   ├── terraform.tfvars.example
   ├── deploy.sh
   └── deploy.ps1
   ```

## STEP 2: Get Your Tenant Information (5 minutes)

**In GameBoard Tenant:**
```powershell
az login --tenant <GAMEBOARD_TENANT_ID>

# Find Log Analytics Workspace
az resource list --resource-type "Microsoft.OperationalInsights/workspaces" --output table

# Copy these values:
# - Tenant ID
# - Subscription ID
# - Resource Group (where workspace is)
# - Workspace Name
# - Workspace Resource ID (from output above)
```

**In AdminCenter Tenant:**
```powershell
az login --tenant <ADMINCENTER_TENANT_ID>

# Copy these values:
# - Tenant ID
# - Subscription ID
```

## STEP 3: Create terraform.tfvars (2 minutes)

```powershell
# Copy the example file
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and fill in YOUR values:
# - gameboard_tenant_id
# - gameboard_subscription_id
# - gameboard_resource_group
# - gameboard_workspace_name
# - gameboard_workspace_id
# - admincenter_tenant_id
# - admincenter_subscription_id
```

## STEP 4: Deploy Phase 1 (3 minutes)

**GameBoard Tenant Setup - Creates Service Principal**

```powershell
# Navigate to Phase 1
cd phase1-gameboard

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply

# SAVE THESE OUTPUTS:
terraform output service_principal_app_id
terraform output service_principal_object_id

# Return to root
cd ..
```

**Expected Output:**
```
service_principal_app_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
service_principal_object_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## STEP 5: Deploy Phase 2 (3 minutes)

**AdminCenter Tenant Setup - Creates Data Factory & Storage**

```powershell
# Navigate to Phase 2
cd phase2-admincenter

# Initialize Terraform (login to AdminCenter first)
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
az account set --subscription <ADMINCENTER_SUBSCRIPTION_ID>

terraform init

# Preview changes
terraform plan

# Deploy
terraform apply

# SAVE THESE OUTPUTS:
terraform output managed_identity_client_id
terraform output data_factory_name
terraform output storage_account_name

# Return to root
cd ..
```

**Expected Output:**
```
managed_identity_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
data_factory_name = "gameboard-logs-adf"
storage_account_name = "logstorage12345678"
```

## STEP 6: Deploy Phase 3 (2 minutes)

**Workload Identity Federation - Zero-Secrets Auth Setup**

```powershell
# Go to Phase 3
cd phase3-federation

# Login to GameBoard for federation
az logout
az login --tenant <GAMEBOARD_TENANT_ID>
az account set --subscription <GAMEBOARD_SUBSCRIPTION_ID>

terraform init

# Plan (replace with YOUR values from Phases 1 & 2)
terraform plan `
  -var="gameboard_subscription_id=<FROM_GAMEBOARD>" `
  -var="gameboard_tenant_id=<FROM_GAMEBOARD>" `
  -var="admincenter_tenant_id=<FROM_ADMINCENTER>" `
  -var="managed_identity_client_id=<FROM_PHASE_2>" `
  -var="service_principal_app_id=<FROM_PHASE_1>"

# Deploy
terraform apply

# Return to root
cd ..
```

**Expected Output:**
```
federation_status = "Successfully created"
issuer_url = "https://login.microsoftonline.com/<ADMINCENTER_ID>/v2.0"
```

## STEP 7: Deploy Phase 4 (2 minutes)

**Data Factory Pipeline - The Actual Copy Job**

```powershell
# Go to Phase 4
cd phase4-datafactory

# Login to AdminCenter
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
az account set --subscription <ADMINCENTER_SUBSCRIPTION_ID>

terraform init

# Plan with your values
terraform plan `
  -var="admincenter_tenant_id=<FROM_ADMINCENTER>" `
  -var="admincenter_subscription_id=<FROM_ADMINCENTER>" `
  -var="data_factory_name=gameboard-logs-adf" `
  -var="storage_account_name=<FROM_PHASE_2>" `
  -var="gameboard_tenant_id=<FROM_GAMEBOARD>" `
  -var="gameboard_subscription_id=<FROM_GAMEBOARD>" `
  -var="gameboard_service_principal_app_id=<FROM_PHASE_1>" `
  -var="gameboard_workspace_name=<YOUR_WORKSPACE>" `
  -var="gameboard_workspace_id=<YOUR_WORKSPACE_ID>"

# Deploy
terraform apply

# Return to root
cd ..
```

**Expected Output:**
```
trigger_name = "Daily-Log-Copy-Trigger"
trigger_frequency = "1 Day"
trigger_schedule = "Daily at 2:00 AM"
```

## STEP 8: Verify Everything Works (2 minutes)

**Test the Pipeline Manually:**

```powershell
# Go to Azure Portal
# Navigate to: Data Factory → Copy-GameBoard-Logs → Debug

# Or use Azure CLI
$resourceGroup = "logs-migration-rg"
$dataFactory = "gameboard-logs-adf"
$pipeline = "Copy-GameBoard-Logs"

az datafactory run create `
  --resource-group $resourceGroup `
  --factory-name $dataFactory `
  --name $pipeline

# Check if logs are now in AdminCenter storage
az storage blob list `
  --account-name logstorage12345678 `
  --container-name gameboard-logs `
  --output table
```

**Expected Output:** Files like `logs/2025-12-10/data.parquet`

---

## Customization Examples

### Change the Copy Schedule
Edit `phase4-datafactory/pipeline.tf`:
```hcl
schedule {
  hours   = [2]      # Change from 2 AM
  minutes = [0]
}
```

### Filter Logs Before Copying
Edit `phase4-datafactory/pipeline.tf`:
```hcl
query = "AzureActivity | where Level == 'Error' | where TimeGenerated > ago(24h)"
```

### Change Storage Location
Edit Phase 2 or Phase 4:
```hcl
admincenter_location = "westus2"  # Change region
```

---

## Troubleshooting

**Issue: "Subscription not found"**
```powershell
# Verify you logged in correctly
az account show
az account list --output table
```

**Issue: "Permission denied"**
```powershell
# Check your role
az role assignment list --assignee-object-id <YOUR_OID>

# You need Owner or high-level role
```

**Issue: Terraform state error**
```powershell
# Delete local state and retry
rm -r .terraform
terraform init
terraform plan
```

**Issue: "Service principal doesn't have permission"**
- Wait 2-3 minutes for permissions to propagate
- Or manually grant roles in Phase 1 verification step

---

## File Descriptions

| File | Purpose |
|------|---------|
| `phase1-gameboard/main.tf` | Creates service principal for cross-tenant access |
| `phase2-admincenter/main.tf` | Creates Data Factory, storage, managed identity |
| `phase3-federation/main.tf` | Sets up zero-secrets authentication |
| `phase4-datafactory/main.tf` | Creates linked services and authentication |
| `phase4-datafactory/datasets.tf` | Defines source/destination data structures |
| `phase4-datafactory/pipeline.tf` | Creates the copy pipeline and schedule |
| `terraform.tfvars.example` | Template for your variables |
| `deploy.sh` | Bash automation script |
| `deploy.ps1` | PowerShell automation script |

---

## One-Command Deployment (Advanced)

If you want full automation, use the deploy script:

**PowerShell:**
```powershell
.\deploy.ps1
```

**Bash:**
```bash
bash deploy.sh
```

The script will walk you through all 4 phases.

---

## Cleanup (If Needed)

To delete everything and avoid charges:

```powershell
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
terraform destroy
```

---

**Time Estimate:** 15-20 minutes end-to-end  
**Next Review:** After first run to verify logs are copying correctly

---

Need help? Check the main README.md or Terraform logs:
```powershell
$env:TF_LOG="DEBUG"
terraform plan
```
