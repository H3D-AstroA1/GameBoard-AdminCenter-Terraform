# Complete Terraform Implementation - Getting Started

## 🎯 What You're About to Deploy

A **zero-secrets, automated log migration system** that:
- ✅ Copies logs from **GameBoard Tenant** (source) to **AdminCenter Tenant** (destination)
- ✅ Uses your existing **Log Analytics Workspace** (no new workspace needed)
- ✅ Runs **daily automatically** (fully unattended)
- ✅ **No passwords stored anywhere** (workload identity federation)
- ✅ **Fully automated** with Terraform (infrastructure as code)
- ✅ **Costs $5-20/month** (vs $750+ for alternatives)

---

## 📋 Prerequisites (5 minutes)

You'll need:
1. ✅ Azure account with admin access to **both tenants**
2. ✅ Azure CLI installed (`az --version`)
3. ✅ Terraform installed (`terraform --version`)
4. ✅ PowerShell or Bash (Windows/Mac/Linux compatible)
5. ✅ **Your GameBoard Log Analytics Workspace name/ID**

**Quick install check:**
```powershell
terraform version
az version
```

---

## 🚀 Quick Start (15 minutes)

### Step 1: Prepare Variables (2 min)

```powershell
# Copy template
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit with your values
notepad terraform.tfvars
```

**Values you need:**
- GameBoard Tenant ID → `az account list`
- AdminCenter Tenant ID → `az account list`
- Log Analytics Workspace name → Azure Portal
- Workspace Resource ID → `az resource list --resource-type "Microsoft.OperationalInsights/workspaces"`

### Step 2: Run Deployment (10 min)

**Option A: Automated Script (Easiest)**
```powershell
.\deploy.ps1
# Select "5" for "Run All Phases"
# Follow the interactive prompts
```

**Option B: Manual Phase-by-Phase**
```powershell
# Phase 1 (GameBoard Tenant)
cd phase1-gameboard
terraform init
terraform apply

# Phase 2 (AdminCenter Tenant)
cd ../phase2-admincenter
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
terraform init
terraform apply

# Phase 3 (Federation)
cd ../phase3-federation
az logout
az login --tenant <GAMEBOARD_TENANT_ID>
terraform init
terraform apply

# Phase 4 (Pipeline)
cd ../phase4-datafactory
az logout
az login --tenant <ADMINCENTER_TENANT_ID>
terraform init
terraform apply
```

### Step 3: Verify (3 min)

```powershell
# Go to Azure Portal → Data Factory
# Find "Copy-GameBoard-Logs" pipeline
# Click "Add trigger" → "Trigger now"
# Check AdminCenter storage for logs after 5-10 minutes

# Or use CLI:
az datafactory pipeline-run query-by-pipeline `
  --resource-group logs-migration-rg `
  --factory-name gameboard-logs-adf `
  --name Copy-GameBoard-Logs
```

---

## 📁 File Guide

| File | Purpose | Read Time |
|------|---------|-----------|
| **QUICKSTART.md** | 15-minute setup guide | 3 min |
| **README.md** | Full documentation | 10 min |
| **REFERENCE.md** | Advanced settings & troubleshooting | 15 min |
| **COSTS.md** | Cost analysis & optimization | 5 min |
| **phase1-gameboard/** | Service Principal creation | Auto |
| **phase2-admincenter/** | Data Factory & Storage | Auto |
| **phase3-federation/** | Zero-secrets authentication | Auto |
| **phase4-datafactory/** | Copy pipeline & scheduler | Auto |

---

## 🔐 Security Architecture

### How It Works (Zero Passwords)

```
1. GameBoard Tenant
   └─ Service Principal "gameboard-logs-app"
      └ Has permission to read Log Analytics

2. AdminCenter Tenant
   └─ Managed Identity "gameboard-logs-mi"
      └ Has permission to write to Storage

3. Trust Relationship (Workload Identity Federation)
   └─ MI can authenticate as SP
   └─ No passwords, no keys, no secrets
   └─ JWT tokens only (auto-renewed)

Result:
   Data Factory in AdminCenter
   → authenticates as MI
   → MI trusts GameBoard's SP
   → SP can read GameBoard's logs
   → Copy happens automatically
```

**Why This is Better:**
- ✅ No secrets to rotate
- ✅ No credentials in code/files
- ✅ Audit trail shows which account did what
- ✅ Can revoke access instantly
- ✅ Complies with zero-trust security

---

## 📊 What Gets Created

### In GameBoard Tenant:
- 1x Service Principal (app registration)
- 1x Federated identity credential (trust token)
- Role: Log Analytics Reader on workspace
- Role: Monitoring Reader on subscription

### In AdminCenter Tenant:
- 1x Resource Group (logs-migration-rg)
- 1x Managed Identity
- 1x Data Factory (v3.80+)
- 1x Storage Account (ADLS Gen2)
- 1x Storage Container (gameboard-logs)
- 1x Daily pipeline trigger (2:00 AM UTC)
- 1x Copy activity (configurable parallelism)

**Total Monthly Cost:** $5-20 (highly tunable)

---

## ⚙️ Customization Examples

### Change Copy Time
Edit `phase4-datafactory/pipeline.tf`:
```hcl
schedule {
  hours   = [14]  # 2 PM instead of 2 AM
  minutes = [0]
}
```

### Filter Logs (Only Errors)
Edit `phase4-datafactory/pipeline.tf`:
```hcl
query = "AzureActivity | where Level == 'Error'"
```

### Reduce Costs (Smaller DIUs)
Edit `phase4-datafactory/pipeline.tf`:
```hcl
diu = 1  # Instead of 4 (save 75%, slower copy)
```

### Copy Every 6 Hours Instead of Daily
Edit `phase4-datafactory/pipeline.tf`:
```hcl
schedule {
  hours   = [0, 6, 12, 18]
  minutes = [0]
}
```

---

## 🆘 Common Issues

| Issue | Solution |
|-------|----------|
| "terraform: command not found" | Download from terraform.io and add to PATH |
| "Subscription not found" | Run `az account list` and verify subscription ID |
| "Permission denied" | Need Contributor role in both tenants |
| "terraform.tfvars not found" | Run `Copy-Item terraform.tfvars.example terraform.tfvars` |
| "Federation fails" | Wait 2-3 minutes for Azure AD sync, then retry Phase 4 |

**More help:** See REFERENCE.md troubleshooting section (25+ solutions)

---

## 📈 Expected Results

### After Phase 4 Completes:

**Day 1 (2:00 AM):**
- Pipeline triggers
- Reads last 24 hours of logs from GameBoard
- Copies to AdminCenter storage
- Writes to: `logs/2025-12-10/data.parquet`
- Logs automatically compressed with Snappy codec

**Day 2 (2:00 AM):**
- Previous day's logs copied
- New folder created with current date
- Storage now has 2 days of logs

**Day 30:**
- 30 days of logs accumulated
- Estimated size: 10-300 GB (depends on volume)
- Can set lifecycle policy to archive old logs

### Azure Portal View:

```
Data Factory
└─ Copy-GameBoard-Logs (Pipeline)
   ├─ Copy activity (source: GameBoard, sink: AdminCenter Storage)
   ├─ Schedule: Daily at 2:00 AM UTC
   ├─ Last run: Success (5 min, 1.2 GB)
   └─ Next run: Tomorrow 2:00 AM

Storage Account (logstorage12345678)
└─ gameboard-logs (Container)
   └─ logs/
      ├─ 2025-12-09/data.parquet (1.5 GB)
      ├─ 2025-12-10/data.parquet (1.2 GB)
      ├─ 2025-12-11/data.parquet (1.8 GB)
      └─ ... (one folder per day)
```

---

## ✅ Validation Checklist

After deployment, verify:

- [ ] Data Factory exists in AdminCenter: `az datafactory show -g logs-migration-rg -n gameboard-logs-adf`
- [ ] Storage account exists: `az storage account show -g logs-migration-rg -n logstorage*`
- [ ] Service Principal exists in GameBoard: `az ad app list --filter "displayName eq 'gameboard-logs-app'"`
- [ ] Pipeline ran successfully: Check Data Factory → Monitor → Pipeline runs
- [ ] Logs copied to storage: `az storage blob list --account-name logstorage* --container-name gameboard-logs`
- [ ] Logs are in Parquet format: List blobs and verify `.parquet` extension

---

## 🔄 Maintenance

### Daily (Automatic)
- Pipeline runs at 2:00 AM UTC
- Copies last 24 hours of logs
- Stores in date-partitioned folders
- Sends success/failure notifications (optional)

### Weekly
- Review pipeline runs in Azure Portal
- Check storage usage: `az storage account show-usage -n logstorage*`
- Verify cost in Azure billing

### Monthly
- Archive logs older than 90 days (optional lifecycle policy)
- Review costs in Azure Cost Management
- Update variables if needed

### Yearly
- Delete archived logs older than 1 year (optional)
- Review and optimize DIU count based on actual copy times

---

## 💰 Costs

| Scenario | Monthly Cost | Annual Cost |
|----------|-------------|------------|
| Small (100 MB/day) | $2-3 | $24-36 |
| Medium (1 GB/day) | $5-8 | $60-96 |
| Large (10 GB/day) | $15-20 | $180-240 |

**See COSTS.md for detailed breakdown and optimization strategies**

---

## 🚫 Cleanup (If Needed)

To delete everything and avoid charges:

```powershell
# Destroy in reverse order
cd phase4-datafactory && terraform destroy -auto-approve && cd ..
cd phase3-federation && terraform destroy -auto-approve && cd ..
cd phase2-admincenter && terraform destroy -auto-approve && cd ..
cd phase1-gameboard && terraform destroy -auto-approve && cd ..

# Remove local state files
rm terraform.tfstate*
rm .phase*-outputs.json
```

---

## 📚 Documentation Map

```
START HERE
    ↓
1. This file (you're reading it now)
    ↓
2. Follow QUICKSTART.md (15 minutes)
    ↓
3. Run deploy.ps1 or manual phases
    ↓
4. If issues → REFERENCE.md (troubleshooting)
    ↓
5. For cost details → COSTS.md
    ↓
6. Full details → README.md
```

---

## 🎓 Learning Path

**Beginner (Just Want It Working):**
1. Copy terraform.tfvars.example → terraform.tfvars
2. Fill in 6 values from your Azure account
3. Run `.\deploy.ps1`
4. Done in 15 minutes

**Intermediate (Want to Understand):**
1. Read QUICKSTART.md
2. Review each phase's `main.tf`
3. Understand variables and outputs
4. Customize schedule/parallelism

**Advanced (Want to Modify):**
1. Read full README.md
2. Review phase4-datafactory pipeline.tf (copy activity logic)
3. Modify KQL query for log filtering
4. Add monitoring/alerting

---

## 🔗 Quick Reference

**Most Important Commands:**

```powershell
# Start interactive deployment
.\deploy.ps1

# Deploy specific phase
cd phase1-gameboard && terraform apply && cd ..

# Check what exists
az resource list -g logs-migration-rg --output table

# Monitor pipeline
az datafactory pipeline-run query-by-pipeline `
  -g logs-migration-rg `
  -f gameboard-logs-adf `
  --name Copy-GameBoard-Logs

# Clean up everything
# (See cleanup section above)
```

---

## 📞 Support

1. **Stuck on setup?** → QUICKSTART.md
2. **Getting errors?** → REFERENCE.md (section: Common Issues)
3. **Want to customize?** → README.md (section: Advanced)
4. **Worried about costs?** → COSTS.md
5. **Not working as expected?** → Test with `az cli` commands directly

---

## 🎉 You're Ready!

You have everything needed to:
- ✅ Migrate logs securely across tenants
- ✅ Automate the process completely
- ✅ Scale to production workloads
- ✅ Spend $200/year instead of $10,000

**Next step:** Open QUICKSTART.md and follow it

---

**Version:** 1.0  
**Last Updated:** December 2025  
**Status:** Production Ready  
**Support Level:** Community
