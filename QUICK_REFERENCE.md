# Quick Reference Card

## 📋 Files at a Glance

```
GameBoard-AdminCenter-Terraform/
├── 📄 GETTING_STARTED.md        ← START HERE (5 min overview)
├── 📄 QUICKSTART.md              ← 15-min deployment guide
├── 📄 README.md                  ← Full 4-phase documentation
├── 📄 REFERENCE.md               ← Troubleshooting & advanced
├── 📄 COSTS.md                   ← Cost analysis
├── 📄 terraform.tfvars.example   ← Config template (copy & edit)
├── 🔧 deploy.ps1                 ← PowerShell automation
├── 🔧 deploy.sh                  ← Bash automation
│
└── 📁 Terraform Phases (auto-deployed)
    ├── phase1-gameboard/        (Service Principal setup)
    ├── phase2-admincenter/      (Data Factory + Storage)
    ├── phase3-federation/       (Zero-secrets auth)
    └── phase4-datafactory/      (Copy pipeline)
```

---

## 🚀 Fastest Path to Success

```
┌─────────────────────────────────────────┐
│ 1. Copy terraform.tfvars.example        │  (30 sec)
│    → terraform.tfvars                   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ 2. Edit terraform.tfvars with:          │  (2 min)
│    - GameBoard Tenant ID                │
│    - AdminCenter Tenant ID              │
│    - Subscription IDs                   │
│    - Workspace name/ID                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ 3. Run: .\deploy.ps1                    │  (10 min)
│    Select: Option 5 "Run All Phases"    │
│    Follow the prompts                   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ 4. Verify in Azure Portal:              │  (2 min)
│    Data Factory → Pipeline runs         │
│    Storage account → blob files         │
└─────────────────────────────────────────┘
                    ↓
            ✅ DONE!
```

---

## 🎯 What Each Phase Does

```
PHASE 1: GameBoard Tenant
┌────────────────────────────────┐
│ Creates:                        │
│ • Service Principal (SP)        │
│ • Role: Log Analytics Reader    │
│                                │
│ Exports:                        │
│ • SP App ID                     │
│ • SP Object ID                  │
│                                │
│ Time: 3-5 minutes               │
└────────────────────────────────┘

         ↓

PHASE 2: AdminCenter Tenant
┌────────────────────────────────┐
│ Creates:                        │
│ • Resource Group                │
│ • Data Factory                  │
│ • Storage Account               │
│ • Managed Identity (MI)         │
│                                │
│ Exports:                        │
│ • MI Client ID                  │
│ • Data Factory name             │
│ • Storage name                  │
│                                │
│ Time: 5-7 minutes               │
└────────────────────────────────┘

         ↓

PHASE 3: GameBoard Tenant (Federation)
┌────────────────────────────────┐
│ Creates:                        │
│ • Federated Identity Credential │
│ • Binds MI → SP (trust)         │
│                                │
│ No exports needed               │
│                                │
│ Time: 2-3 minutes               │
└────────────────────────────────┘

         ↓

PHASE 4: AdminCenter Tenant (Pipeline)
┌────────────────────────────────┐
│ Creates:                        │
│ • Linked Services (0 secrets!)  │
│ • Datasets (source & sink)      │
│ • Copy Pipeline                 │
│ • Daily Trigger (2 AM UTC)      │
│                                │
│ Starts: Automated log copying   │
│                                │
│ Time: 3-5 minutes               │
└────────────────────────────────┘

         ↓

    RESULT: Automatic Daily Log Copy
    GameBoard → AdminCenter
    (Fully unattended)
```

---

## 🔧 Common Commands

### Login & Setup
```powershell
# Check prerequisites
terraform version && az version

# Copy config template
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit config
notepad terraform.tfvars
```

### Deploy
```powershell
# Automated (easiest)
.\deploy.ps1

# Manual - Phase by phase
cd phase1-gameboard && terraform init && terraform apply
cd ../phase2-admincenter && terraform init && terraform apply
cd ../phase3-federation && terraform init && terraform apply
cd ../phase4-datafactory && terraform init && terraform apply
```

### Monitor
```powershell
# List all created resources
az resource list -g logs-migration-rg --output table

# Monitor pipeline
az datafactory pipeline-run query-by-pipeline `
  -g logs-migration-rg `
  -f gameboard-logs-adf `
  --name Copy-GameBoard-Logs

# Check storage
az storage blob list `
  --account-name logstorage12345678 `
  --container-name gameboard-logs
```

### Troubleshoot
```powershell
# Check current Azure login
az account show

# Switch tenant
az login --tenant <TENANT_ID>

# View Terraform state
terraform state show

# View Terraform output
terraform output
```

### Cleanup
```powershell
# Destroy Phase 4 (pipeline)
cd phase4-datafactory && terraform destroy -auto-approve

# Destroy Phase 3 (federation)
cd ../phase3-federation && terraform destroy -auto-approve

# Destroy Phase 2 (infrastructure)
cd ../phase2-admincenter && terraform destroy -auto-approve

# Destroy Phase 1 (service principal)
cd ../phase1-gameboard && terraform destroy -auto-approve
```

---

## ⚡ Key Values to Capture

After each phase, save these outputs (needed for next phases):

**After Phase 1:**
```
service_principal_app_id = "xxx-xxx-xxx"
service_principal_object_id = "xxx-xxx-xxx"
```

**After Phase 2:**
```
managed_identity_client_id = "xxx-xxx-xxx"
data_factory_name = "gameboard-logs-adf"
storage_account_name = "logstorage12345678"
```

**After Phase 3:**
```
federation_status = "Created"
issuer_url = "https://login.microsoftonline.com/{ID}/v2.0"
```

---

## 📊 Resource Overview

| Service | Component | Quantity | Cost/Month |
|---------|-----------|----------|-----------|
| **GameBoard** | Service Principal | 1 | Free |
| **GameBoard** | Federated Credential | 1 | Free |
| **AdminCenter** | Data Factory | 1 | $0.50 + $0.26/DIU |
| **AdminCenter** | Storage Account | 1 | ~$5.52 (300GB) |
| **AdminCenter** | Managed Identity | 1 | Free |
| **AdminCenter** | Resource Group | 1 | Free |
| | **TOTAL MONTHLY** | | **$5-20** |

---

## 🔐 Authentication Flow

```
User: azure login --tenant ADMINCENTER
    ↓
AdminCenter Data Factory starts (2 AM daily)
    ↓
ADF uses: Managed Identity (MI)
    ↓
MI obtains token using: Workload Identity Federation
    ↓
Token issued for: Service Principal (GameBoard)
    ↓
SP has permission: Read Log Analytics Workspace
    ↓
Connection to: GameBoard Log Analytics (read logs)
    ↓
Connection to: AdminCenter Storage (write logs)
    ↓
Result: Logs copied safely (NO PASSWORDS INVOLVED)
```

**Security: ✅ ZERO secrets stored**

---

## ❓ Which File Do I Need?

| I want to... | Read this file |
|---|---|
| Get started ASAP | **GETTING_STARTED.md** (5 min) |
| Deploy in 15 minutes | **QUICKSTART.md** |
| Understand everything | **README.md** |
| Fix an error | **REFERENCE.md** |
| Understand costs | **COSTS.md** |
| Deploy automatically | **deploy.ps1** or **deploy.sh** |
| See all Terraform code | **phase*-*/main.tf** files |
| Create my terraform.tfvars | **terraform.tfvars.example** |

---

## ⏱️ Time Estimates

| Task | Time |
|------|------|
| Install prerequisites | 5 min |
| Copy & edit terraform.tfvars | 2 min |
| Run Phase 1 | 3-5 min |
| Run Phase 2 | 5-7 min |
| Run Phase 3 | 2-3 min |
| Run Phase 4 | 3-5 min |
| Verify success | 2 min |
| **TOTAL** | **22-30 min** |

---

## 🚨 Common Mistakes

❌ **Wrong:** Create new Log Analytics workspace (already have one)  
✅ **Right:** Use existing workspace, just add Terraform permissions

❌ **Wrong:** Store service principal password anywhere  
✅ **Right:** Use workload identity federation (zero passwords)

❌ **Wrong:** Run all phases in same tenant  
✅ **Right:** Phase 1&3 in GameBoard, Phase 2&4 in AdminCenter

❌ **Wrong:** Use complex KQL queries without testing  
✅ **Right:** Start with default "union *" then customize

❌ **Wrong:** Set high DIU count to make it fast  
✅ **Right:** Start with 1 DIU, increase only if needed

---

## 📞 Getting Help

1. **Command not found?** → Check Prerequisites section
2. **Login issues?** → Run `az login --help`
3. **Terraform error?** → Check REFERENCE.md
4. **Cost questions?** → Check COSTS.md
5. **Advanced setup?** → Read full README.md

---

## ✅ Success Indicators

After deployment, you should see:

- ✅ Resources in Azure Portal (logs-migration-rg)
- ✅ Data Factory pipeline "Copy-GameBoard-Logs"
- ✅ Storage account with "gameboard-logs" container
- ✅ Files in format: `logs/YYYY-MM-DD/data.parquet`
- ✅ Daily automatic pipeline runs at 2:00 AM UTC
- ✅ No errors in Terraform output
- ✅ Cost of $5-20/month (not $750+)

---

## 🎓 Next Steps

1. **Read GETTING_STARTED.md** (5 min)
2. **Follow QUICKSTART.md** (15 min deployment)
3. **Verify** logs appear in storage (same day)
4. **Customize** if needed (REFERENCE.md)

**You're ready! Start with GETTING_STARTED.md →**

---

**Quick Stats:**
- 📝 Documentation: 5 files
- 🔧 Automation: 2 scripts (PowerShell + Bash)
- 🏗️ Infrastructure: 4 Terraform phases
- ⏱️ Setup time: 20-30 minutes
- 💰 Monthly cost: $5-20
- 🔒 Security: Zero passwords
- ✅ Status: Production ready

