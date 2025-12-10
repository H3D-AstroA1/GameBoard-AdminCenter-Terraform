# 🎯 START HERE - GameBoard to AdminCenter Log Migration

Welcome! This Terraform project automates copying all your raw logs from **GameBoard Tenant** to **AdminCenter Tenant** with **zero passwords**, **fully automated**, at just **$5-20/month**.

---

## ⏱️ How Much Time Do You Have?

### ⚡ I have 15 minutes
→ Open [QUICKSTART.md](QUICKSTART.md) and deploy now

### ⏰ I have 30 minutes  
→ Read [GETTING_STARTED.md](GETTING_STARTED.md), then follow QUICKSTART.md

### 📚 I have 1-2 hours
→ Start with [INDEX.md](INDEX.md) for the full reading guide

---

## 📋 What This Does

```
GameBoard Tenant                    AdminCenter Tenant
├─ Log Analytics Workspace    →     ├─ Data Factory
│  (your existing logs)             │  (automated copy)
└─ Service Principal                ├─ Storage Account
   (created by Terraform)           │  (logs stored here)
                                    └─ Daily Trigger
                                       (runs at 2 AM UTC)

Result: Your logs automatically copied every day
        In Parquet format, date-partitioned
        Zero passwords, zero secrets
        Costs: $5-20/month
```

---

## ✅ Quick Checklist

Have you got these?
- [ ] Azure account access to **both tenants**
- [ ] **PowerShell** or **Bash** (Windows/Mac/Linux works)
- [ ] **Terraform** installed (`terraform --version`)
- [ ] **Azure CLI** installed (`az --version`)
- [ ] **Your GameBoard Log Analytics Workspace name**

No? → Install them first (5 minutes, guides in [GETTING_STARTED.md](GETTING_STARTED.md))  
Yes? → Go to **Deployment** section below ↓

---

## 🚀 Deployment (15 minutes)

### Step 1: Copy Configuration
```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Edit these 6 values (from your Azure account):
```
gameboard_tenant_id = "your-gameboard-id"
gameboard_subscription_id = "your-sub-id"
gameboard_resource_group = "rg-where-logs-are"
gameboard_workspace_name = "workspace-name"
gameboard_workspace_id = "/subscriptions/.../workspaces/..."

admincenter_tenant_id = "your-admincenter-id"
admincenter_subscription_id = "your-sub-id"
```

**How to find these values?**
```powershell
# Tenant IDs and Subscription IDs
az account list --output table

# Workspace name/ID
az resource list --resource-type "Microsoft.OperationalInsights/workspaces"
```

### Step 2: Run Deployment
```powershell
# Option A: Fully automated (recommended)
.\deploy.ps1
# Select option 5: "Run All Phases"

# Option B: Manual phase-by-phase
cd phase1-gameboard && terraform init && terraform apply
cd ../phase2-admincenter && terraform init && terraform apply
cd ../phase3-federation && terraform init && terraform apply
cd ../phase4-datafactory && terraform init && terraform apply
```

### Step 3: Verify Success
```powershell
# Check in Azure Portal:
# - Data Factory exists
# - Pipeline runs daily at 2 AM
# - Logs appear in storage account

# Or check via CLI:
az datafactory pipeline-run query-by-pipeline `
  -g logs-migration-rg -f gameboard-logs-adf -n Copy-GameBoard-Logs
```

**Done!** Your logs now copy automatically every day. ✅

---

## 📁 What You Have

| File | Purpose |
|------|---------|
| **INDEX.md** | Complete documentation map |
| **GETTING_STARTED.md** | Beginner-friendly overview |
| **QUICKSTART.md** | 15-minute deployment guide |
| **README.md** | Full architecture & details |
| **REFERENCE.md** | Troubleshooting & advanced |
| **COSTS.md** | Cost analysis & optimization |
| **QUICK_REFERENCE.md** | Command cheatsheet |
| **deploy.ps1** | PowerShell automation |
| **deploy.sh** | Bash automation |
| **terraform.tfvars.example** | Configuration template |
| **phase1-4/** | Terraform modules (auto-deployed) |

---

## 🔒 Security: Zero Passwords

This solution uses **Workload Identity Federation** for authentication:

```
✅ NO passwords stored
✅ NO credentials in files
✅ NO secrets to rotate
✅ Automatic token refresh
✅ Audit trail for all access
✅ Can revoke instantly
```

More details → See [GETTING_STARTED.md](GETTING_STARTED.md) (Security section)

---

## 💰 Cost: ~$5-20/Month

| Component | Cost |
|-----------|------|
| Data Factory | $0.50 + $0.26/DIU |
| Storage (ADLS Gen2) | ~$5-10 |
| Transfer | ~$1-2 |
| Managed Identity | FREE |
| Service Principal | FREE |
| **Total** | **$5-20/month** |

Compare:
- Sentinel: $750-3,000/month ❌
- Manual scripts: $50-100/month ❌
- This solution: $5-20/month ✅

More details → See [COSTS.md](COSTS.md)

---

## ❓ Help & Troubleshooting

### "I'm stuck on setup"
→ [GETTING_STARTED.md](GETTING_STARTED.md) - Prerequisites section

### "I'm getting an error"
→ [REFERENCE.md](REFERENCE.md) - Common Issues section (25+ solutions)

### "I want to customize something"
→ [REFERENCE.md](REFERENCE.md) - Advanced Customization section

### "What will this cost me?"
→ [COSTS.md](COSTS.md) - Cost scenarios & optimization

### "I need the commands"
→ [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command cheatsheet

---

## 📖 Documentation Paths

**Choose based on your preference:**

### 👨‍💼 Manager/Executive
Just want to know: What, Why, Cost?
- [GETTING_STARTED.md](GETTING_STARTED.md) (5 min)
- [COSTS.md](COSTS.md) (10 min)

### 👨‍💻 IT Admin / DevOps
Want to understand and deploy
- [GETTING_STARTED.md](GETTING_STARTED.md) (5 min)
- [README.md](README.md) (15 min)
- [QUICKSTART.md](QUICKSTART.md) (15 min deployment)

### 🧑‍🔬 Developer / Engineer
Want full details and to customize
- All files above, plus:
- [REFERENCE.md](REFERENCE.md) (30 min)
- Review phase1-4 Terraform code (20 min)

### 🚀 "Just Deploy It"
Want to start ASAP
- [QUICKSTART.md](QUICKSTART.md) (15 min)
- Done!

---

## 🎯 Next Actions

### Recommended Path

1. **Setup (5 min)**
   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   notepad terraform.tfvars  # Fill in your 6 values
   ```

2. **Deploy (10 min)**
   ```powershell
   .\deploy.ps1
   # Select option 5, follow prompts
   ```

3. **Verify (2 min)**
   - Go to Azure Portal
   - Check Data Factory → Pipeline runs
   - Check Storage account → gameboard-logs container

4. **Done** ✅

---

## 📊 What Gets Created

### In GameBoard Tenant:
- 1 Service Principal (read logs)
- 1 Federated credential (zero passwords)
- RBAC roles (Log Analytics Reader)

### In AdminCenter Tenant:
- 1 Resource Group
- 1 Data Factory
- 1 Storage Account
- 1 Managed Identity
- 1 Copy Pipeline (daily trigger)
- 1 Storage Container (gameboard-logs)

**Total:** Simple, clean, production-ready infrastructure

---

## ✨ Key Features

| Feature | How It Works |
|---------|-------------|
| **Zero Passwords** | Workload Identity Federation handles auth |
| **Automated** | Runs daily at 2:00 AM UTC (configurable) |
| **Cheap** | $5-20/month (vs $750+ alternatives) |
| **Scalable** | Works for 100 MB to 100 GB/day |
| **Secure** | No credentials stored, full audit trail |
| **Simple** | 4 phases, 20 minutes to deploy |
| **Reliable** | Azure-managed, built-in monitoring |
| **Customizable** | Change schedule, filters, compression |

---

## 🚀 You're Ready!

### Next Step: Open [QUICKSTART.md](QUICKSTART.md)

Or, if you want to understand first:
- **5 min overview:** [GETTING_STARTED.md](GETTING_STARTED.md)
- **Full guide:** [INDEX.md](INDEX.md)

---

## 💡 Pro Tips

✅ Use `deploy.ps1` for hands-free automation  
✅ Fill in terraform.tfvars completely before starting  
✅ Save outputs between phases (or use script, it's automatic)  
✅ Wait 2-3 minutes before Phase 4 (Azure AD propagation)  
✅ Monitor first run manually before assuming it works  
✅ Set up cost alerts to catch billing surprises  

❌ Don't create a new Log Analytics workspace  
❌ Don't store service principal passwords  
❌ Don't run phases out of order (1→2→3→4)  
❌ Don't use high DIU count unless logs are huge  
❌ Don't skip the verification step  

---

## 🆘 Emergency Help

**If something's broken:**

1. Check [REFERENCE.md](REFERENCE.md) - search for your error
2. Look at Terraform logs: `$env:TF_LOG="DEBUG"`
3. Check Azure Portal for resources
4. Destroy phase and retry: `terraform destroy -auto-approve`

**If you're confused:**

1. Reread [GETTING_STARTED.md](GETTING_STARTED.md)
2. Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for commands
3. Review [README.md](README.md) for architecture

---

## 📞 Support Levels

| Issue | Time | Resource |
|-------|------|----------|
| Setup question | 5 min | [GETTING_STARTED.md](GETTING_STARTED.md) |
| Deployment error | 15 min | [REFERENCE.md](REFERENCE.md) |
| Cost optimization | 10 min | [COSTS.md](COSTS.md) |
| Architecture question | 20 min | [README.md](README.md) |
| Advanced customization | 30 min | [REFERENCE.md](REFERENCE.md) |

---

## ✅ Success Checklist

After deployment, verify:

- [ ] Terraform apply completed without errors
- [ ] Resource group "logs-migration-rg" exists
- [ ] Data Factory "gameboard-logs-adf" exists
- [ ] Storage account contains "gameboard-logs" container
- [ ] Pipeline "Copy-GameBoard-Logs" exists
- [ ] Trigger scheduled for daily at 2:00 AM
- [ ] Files appear in storage after first run
- [ ] Files are in Parquet format
- [ ] Cost is $5-20/month (not higher)

---

**Version:** 1.0  
**Status:** Production Ready  
**Support:** Community  
**License:** MIT  

---

## 🎉 You're All Set!

### Ready to deploy?
**→ Open [QUICKSTART.md](QUICKSTART.md) NOW**

### Want to learn first?
**→ Open [GETTING_STARTED.md](GETTING_STARTED.md)**

### Need the full guide?
**→ Open [INDEX.md](INDEX.md)**

---

**Happy deploying!** 🚀

*Questions? Check [INDEX.md](INDEX.md) for complete documentation map*
