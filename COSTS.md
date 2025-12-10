# Cost Estimation & Optimization Guide

## Monthly Cost Estimate

### Scenario: Enterprise Environment
- **Data Volume:** 10 GB/day (300 GB/month)
- **Copy Frequency:** Daily at 2:00 AM
- **Region:** East US

```
Component                          | Monthly Cost
------------------------------------|--------------------
Azure Data Factory (Copy Activity)  | $0.50 (base) + $0.26/DIU (4 DIUs)
Azure Storage (ADLS Gen2)           | ~$6.00 (storage) + $0.50 (data in)
Managed Identity                    | FREE
Service Principal                   | FREE
Workload Identity Federation        | FREE
Data Transfer (egress)              | ~$2.00-$5.00
------------------------------------|--------------------
ESTIMATED MONTHLY COST              | $15-20/month
```

### Scenario: Mid-Size Environment
- **Data Volume:** 1 GB/day (30 GB/month)
- **Copy Frequency:** Every 6 hours (4x daily)
- **Region:** East US

```
Component                          | Monthly Cost
------------------------------------|--------------------
Azure Data Factory (4 runs/day)     | $0.50 + $0.26 (x4 frequency multiplier)
Azure Storage                       | ~$1.00 (30 GB stored)
Data Transfer                       | ~$0.50
------------------------------------|--------------------
ESTIMATED MONTHLY COST              | $5-8/month
```

### Scenario: Small/Test Environment
- **Data Volume:** 100 MB/day (3 GB/month)
- **Copy Frequency:** Once daily
- **Region:** East US

```
Component                          | Monthly Cost
------------------------------------|--------------------
Azure Data Factory                  | $0.50 (minimum)
Azure Storage                       | ~$0.15 (3 GB)
Data Transfer                       | ~$0.10
------------------------------------|--------------------
ESTIMATED MONTHLY COST              | ~$1-2/month
```

---

## Detailed Pricing Breakdown

### Azure Data Factory Pricing

**Base Cost:** $0.50/month per factory (managed integration runtime)

**Copy Activity Cost:** $0.26 per DIU-hour
- Default configuration: 4 DIUs
- Daily copy at 2:00 AM: assume ~10 minutes = 0.167 hours
- Cost per run: 4 DIUs × 0.167 hours × $0.26 = ~$0.17
- 30 runs/month: 30 × $0.17 = $5.10/month

**Calculation:**
```
Monthly Cost = Base ($0.50) + (DIUs × Hours × $0.26 × Runs)
             = $0.50 + (4 × 0.167 × $0.26 × 30)
             = $0.50 + $5.10
             = $5.60/month for Data Factory only
```

### Azure Storage (ADLS Gen2) Pricing

**Storage Cost:** $0.0184 per GB/month (Hot tier, East US)
- 300 GB stored: 300 × $0.0184 = $5.52/month

**Transaction Costs:** 
- Write operations: ~$0.05 per 10,000 writes
- Read operations: ~$0.004 per 10,000 reads
- List operations: ~$0.004 per 10,000 lists
- Typical: <$1/month for small environments

**Data Transfer:**
- Inbound (GameBoard→AdminCenter): FREE
- Outbound if accessing from internet: $0.087/GB

### Workload Identity Federation
**Cost:** FREE (no extra charges)

### Managed Identity
**Cost:** FREE (included with service)

---

## Cost Optimization Strategies

### 1. Reduce DIU Count (Save 50%+)

**Current:**
```powershell
diu = 4  # Default
# Cost: $5/month
```

**Optimized:**
```powershell
diu = 1  # Slower but cheaper
# Cost: $1.40/month
```

**When to use:**
- Test/Dev environments
- Small data volumes (<100 MB)
- Can afford longer copy times

**Trade-off:** Copy time increases 4x

**Edit:** Phase 4 → pipeline.tf → change `diu` value

---

### 2. Schedule Less Frequently (Save 50-70%)

**Current:**
```
Frequency: Daily (30 runs/month)
Cost: $5.60/month
```

**Optimized - Every 3 Days:**
```
Frequency: Every 3 days (10 runs/month)
Cost: $2.00/month (saves $3.60)
```

**Optimized - Weekly:**
```
Frequency: Weekly (4 runs/month)
Cost: $1.20/month (saves $4.40)
```

**Edit:** Phase 4 → pipeline.tf → modify `schedule` block

```hcl
# Every 3 days at 2:00 AM
schedule {
  hours   = [2]
  minutes = [0]
}
# Then adjust trigger frequency in pipeline configuration
```

---

### 3. Archive Old Logs (Save 80%+ on storage)

**Without Archive:**
- Store 300 GB/month indefinitely
- Cost: $5.52/month (growing forever)

**With Archive Policy:**
```powershell
# Move to cool tier after 30 days
# Move to archive tier after 90 days
# Delete after 1 year

# Typical cost: $0.50-$1.00/month (vs $5.52/month)
```

**Implement:**
```powershell
# Set lifecycle policy on storage container
az storage account management-policy create `
  --account-name logstorage12345678 `
  --resource-group logs-migration-rg `
  --policy @lifecycle-policy.json
```

**lifecycle-policy.json:**
```json
{
  "rules": [
    {
      "enabled": true,
      "name": "archive-old-logs",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": {"daysAfterModificationGreaterThan": 30},
            "tierToArchive": {"daysAfterModificationGreaterThan": 90},
            "delete": {"daysAfterModificationGreaterThan": 365}
          }
        },
        "filters": {"blobTypes": ["blockBlob"]}
      }
    }
  ]
}
```

---

### 4. Use Managed Identity Only (Save 100% on credentials)

**Workload Identity Federation (Current):** FREE  
**Service Principal Keys (Alternative):** $0-5/month for Key Vault

**Already implemented in this solution!**

---

### 5. Compress Logs (Save 60-70% on storage)

**Without Compression:**
- 300 GB raw logs: $5.52/month

**With Snappy Compression:**
- 100-150 GB compressed: $1.84-$2.76/month (saves $3-4/month)

**Edit:** Phase 4 → datasets.tf

```hcl
# Already using Snappy compression by default
compression = "snappy"  # Typical 60-70% compression ratio
```

---

## Cost Comparison: This Solution vs Alternatives

### Option 1: Azure Sentinel (NOT Recommended)
- **Cost:** $2.50-$10/GB ingested
- **For 300 GB:** $750-$3,000/month
- **Problem:** Cannot copy cross-tenant raw logs
- **Use Case:** Unified SOC with cross-tenant correlation

### Option 2: Manual Export Script
- **Cost:** VM for scheduler ($50-100/month) + Storage ($5/month)
- **Total:** $55-105/month
- **Problem:** Manual maintenance, no monitoring
- **Use Case:** One-time exports

### Option 3: Data Factory (This Solution)
- **Cost:** $5-20/month
- **Pros:** Fully managed, scheduled, monitored, zero credentials
- **Cons:** Azure-only, requires initial setup
- **Best For:** Regular cross-tenant log migration

### Option 4: Azure Log Analytics Agent
- **Cost:** Per-agent licensing
- **Problem:** Cannot retrieve logs across tenants
- **Use Case:** Local collection within same tenant

### Option 5: Third-Party SIEM
- **Cost:** $1,000-10,000+/month
- **Problem:** Overkill if just need raw log export
- **Use Case:** Full SOC platform needed

**Recommendation:** Option 3 (This Solution) provides best value for cross-tenant log migration

---

## Budget Alerts & Monitoring

### Set Up Azure Cost Alerts

```powershell
# Create budget with alert
az billing budget create `
  --name "GameBoard-Logs-Migration" `
  --amount 20 `
  --threshold 80 `
  --threshold-type "Forecasted" `
  --time-period "Monthly"
```

### Monitor Actual vs Estimated Costs

```powershell
# View current month costs
az cost management query `
  --timeframe "MonthToDate" `
  --type "Usage"

# Export to CSV for analysis
az cost management export create `
  --name "logs-migration-costs" `
  --definition-type "Usage" `
  --recurrence-period "Monthly"
```

### Monitor Storage Costs Specifically

```powershell
$storageName = "logstorage12345678"
$resourceGroup = "logs-migration-rg"

# Get storage usage
az storage account show-usage `
  --name $storageName

# Get detailed metrics
az monitor metrics list `
  --resource "/subscriptions/<ID>/resourceGroups/$resourceGroup/providers/Microsoft.Storage/storageAccounts/$storageName" `
  --metric "UsedCapacity"
```

---

## Cost Optimization Checklist

- [ ] Use 1-2 DIUs for test/dev (vs 4 for production)
- [ ] Schedule less frequently (e.g., weekly vs daily)
- [ ] Enable blob lifecycle policy for archival
- [ ] Confirm compression is enabled (Snappy codec)
- [ ] Set up cost alerts in Azure
- [ ] Review monthly bills for unexpected increases
- [ ] Archive logs older than 6 months to Archive tier
- [ ] Delete logs older than 1 year
- [ ] Filter KQL query to exclude unnecessary log types

---

## Right-Sizing Example

### Scenario: Start Small, Scale Up

**Month 1-3: Test Environment**
```
- 1 DIU (slow copy, saves money)
- Daily schedule
- Expected cost: $2-3/month
- Estimated copy time: 30-60 minutes
```

**Month 4-6: Transition to Production**
```
- 2 DIUs (balance speed/cost)
- Daily schedule
- Expected cost: $3-5/month
- Estimated copy time: 10-15 minutes
```

**Month 7+: Optimized Production**
```
- 4 DIUs (fast copy for compliance)
- Daily schedule
- Lifecycle policy enabled
- Expected cost: $5-8/month (stable as logs archive)
- Estimated copy time: 5-10 minutes
```

---

## Unexpected Cost Increases - Troubleshooting

**Problem:** Monthly bill suddenly jumped $100+

**Common Causes:**

1. **Data Volume Spike**
   ```powershell
   # Check storage usage
   az storage account show-usage --name $storageName
   # Solution: Implement lifecycle policy to archive old data
   ```

2. **Pipeline Running Too Often**
   ```powershell
   # Check trigger frequency
   az datafactory trigger show `
     --resource-group logs-migration-rg `
     --factory-name gameboard-logs-adf `
     --trigger-name "Daily-Log-Copy-Trigger"
   # Solution: Adjust schedule to run less frequently
   ```

3. **DIU Count Too High**
   ```powershell
   # Check Data Factory configuration
   # Solution: Reduce DIU count in pipeline settings
   ```

4. **Unnecessary Data Transfers**
   ```powershell
   # Check egress from storage (if accessing logs frequently)
   # Solution: Access logs within same region, use shared access keys
   ```

---

## Annual Cost Projection

**Assumption:** Steady state, 10 GB/day ingestion, no growth

| Year | Monthly | Annual | Notes |
|------|---------|--------|-------|
| Year 1 | $15-20 | $180-240 | Setup + operation |
| Year 2 | $8-10 | $96-120 | Archives reduce storage cost |
| Year 3 | $5-8 | $60-96 | Mature state, full archival |

**ROI Analysis:**
- One-time setup time: ~2 hours
- Hourly rate equivalent: ~$100/hour = $200 setup cost
- Breakeven: 1-2 months
- Annual savings vs manual process: $5,000-15,000

---

**Last Updated:** December 2025  
**Accuracy:** ±20% (Azure pricing changes quarterly)  
**Region:** East US (adjust pricing for other regions)
