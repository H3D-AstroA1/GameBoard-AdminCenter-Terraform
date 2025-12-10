# ============================================================================
# GAMEBOARD TO ADMINCENTER TERRAFORM DEPLOYMENT SCRIPT
# PowerShell Version
# ============================================================================
# 
# This script automates the 4-phase Terraform deployment
# Usage: .\deploy.ps1
#
# Features:
# - Interactive menu for phase selection
# - Automatic validation between phases
# - Color-coded logging
# - State management
# - Error handling with rollback option
#

param(
    [ValidateSet("all", "1", "2", "3", "4", "validate")]
    [string]$Phase = "all",
    [switch]$AutoApprove = $false,
    [switch]$Destroy = $false
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir
$RootTfvars = Join-Path $ProjectRoot "terraform.tfvars"

# Phase directories
$Phase1Dir = Join-Path $ProjectRoot "phase1-gameboard"
$Phase2Dir = Join-Path $ProjectRoot "phase2-admincenter"
$Phase3Dir = Join-Path $ProjectRoot "phase3-federation"
$Phase4Dir = Join-Path $ProjectRoot "phase4-datafactory"

# Output files for capturing between phases
$Phase1OutputFile = Join-Path $ProjectRoot ".phase1-outputs.json"
$Phase2OutputFile = Join-Path $ProjectRoot ".phase2-outputs.json"
$Phase3OutputFile = Join-Path $ProjectRoot ".phase3-outputs.json"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  $Message" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
}

function Write-Section {
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Yellow
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    $hasErrors = $false
    
    # Check Terraform
    if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error "Terraform not found. Download from https://www.terraform.io/downloads"
        $hasErrors = $true
    } else {
        $tfVersion = terraform version | Select-Object -First 1
        Write-Success "Terraform: $tfVersion"
    }
    
    # Check Azure CLI
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found. Download from https://aka.ms/GetAzureCli"
        $hasErrors = $true
    } else {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Success "Azure CLI: $($azVersion.'azure-cli')"
    }
    
    # Check Terraform files
    if (!(Test-Path $RootTfvars)) {
        Write-Error "terraform.tfvars not found. Copy terraform.tfvars.example and edit it."
        Write-Info "Command: Copy-Item terraform.tfvars.example terraform.tfvars"
        $hasErrors = $true
    } else {
        Write-Success "terraform.tfvars found"
    }
    
    # Check phase directories
    @($Phase1Dir, $Phase2Dir, $Phase3Dir, $Phase4Dir) | ForEach-Object {
        if (!(Test-Path $_)) {
            Write-Error "Phase directory not found: $_"
            $hasErrors = $true
        } else {
            Write-Success "Found: $(Split-Path -Leaf $_)"
        }
    }
    
    if ($hasErrors) {
        Write-Error "Prerequisites check failed. Please fix errors above."
        exit 1
    }
    
    Write-Success "All prerequisites met!"
}

function Test-AzureLogin {
    param([string]$TenantId)
    
    Write-Info "Checking Azure login..."
    
    $currentAccount = az account show 2>$null | ConvertFrom-Json
    
    if (!$currentAccount) {
        Write-Warning "Not logged in to Azure. Starting login flow..."
        if ($TenantId) {
            az login --tenant $TenantId
        } else {
            az login
        }
    } else {
        Write-Success "Logged in as: $($currentAccount.user.name) (Tenant: $($currentAccount.tenantId))"
    }
}

# ============================================================================
# PHASE EXECUTION FUNCTIONS
# ============================================================================

function Invoke-TerraformPhase {
    param(
        [string]$PhaseName,
        [string]$PhaseDir,
        [string]$OutputFile,
        [switch]$RequiresSpecialAuth = $false,
        [string]$TenantId = "",
        [string]$SubscriptionId = ""
    )
    
    Write-Header "Phase: $PhaseName"
    
    # Verify directory exists
    if (!(Test-Path $PhaseDir)) {
        Write-Error "Phase directory not found: $PhaseDir"
        return $false
    }
    
    # Change directory
    Push-Location $PhaseDir
    
    try {
        # Copy root tfvars if not present
        if (!(Test-Path "terraform.tfvars") -and (Test-Path $RootTfvars)) {
            Write-Info "Copying terraform.tfvars to phase directory..."
            Copy-Item $RootTfvars "terraform.tfvars"
        }
        
        # Initialize Terraform
        Write-Section "Initializing Terraform"
        if ($Destroy) {
            Write-Info "Skipping init for destroy operation"
        } else {
            terraform init -upgrade
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform init failed"
                return $false
            }
            Write-Success "Terraform initialized"
        }
        
        # Plan
        Write-Section "Planning changes"
        terraform plan -out=tfplan
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform plan failed"
            return $false
        }
        Write-Success "Plan completed successfully"
        
        # Apply or Destroy
        Write-Section "Applying changes"
        
        if ($Destroy) {
            Write-Warning "This will DESTROY all resources created by this phase!"
            $confirm = Read-Host "Type 'yes' to confirm destruction"
            if ($confirm -eq "yes") {
                terraform destroy -auto-approve
            } else {
                Write-Info "Destruction cancelled"
                return $true
            }
        } else {
            if ($AutoApprove) {
                terraform apply -auto-approve tfplan
            } else {
                Write-Info "Review the plan above. Press Enter to apply or Ctrl+C to cancel..."
                Read-Host
                terraform apply tfplan
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform apply/destroy failed"
            return $false
        }
        
        # Capture outputs
        if (!$Destroy -and $OutputFile) {
            Write-Section "Capturing outputs"
            $outputs = terraform output -json | ConvertFrom-Json
            $outputs | ConvertTo-Json | Out-File $OutputFile
            Write-Success "Outputs saved to: $OutputFile"
            
            # Display outputs
            Write-Info "Phase outputs:"
            $outputs.PSObject.Properties | ForEach-Object {
                Write-Host "  $($_.Name): $($_.Value.value)" -ForegroundColor Green
            }
        }
        
        Write-Success "$PhaseName completed successfully!"
        return $true
        
    } catch {
        Write-Error "Error during $PhaseName : $_"
        return $false
    } finally {
        Pop-Location
    }
}

# ============================================================================
# PHASE-SPECIFIC FUNCTIONS
# ============================================================================

function Invoke-Phase1 {
    Write-Header "PHASE 1: GameBoard Tenant Setup"
    Write-Info "This phase creates a Service Principal in GameBoard Tenant"
    Write-Info "Required: Tenant ID and subscription ID from GameBoard tenant"
    
    # Get tenant info from tfvars
    $tfvarsContent = Get-Content $RootTfvars -Raw
    $gameboardTenant = if ($tfvarsContent -match 'gameboard_tenant_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter GameBoard Tenant ID"
    }
    
    Test-AzureLogin -TenantId $gameboardTenant
    
    # Set subscription
    $gameboardSub = if ($tfvarsContent -match 'gameboard_subscription_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter GameBoard Subscription ID"
    }
    
    az account set --subscription $gameboardSub
    
    # Execute phase
    $success = Invoke-TerraformPhase -PhaseName "GameBoard Setup" -PhaseDir $Phase1Dir -OutputFile $Phase1OutputFile
    
    if ($success) {
        Write-Success "Phase 1 Complete!"
        Write-Info "Save the outputs above - you'll need them for Phase 3"
        Write-Section "Next Steps"
        Write-Info "1. Record the service_principal_app_id"
        Write-Info "2. Record the service_principal_object_id"
        Write-Info "3. Move to Phase 2 in AdminCenter tenant"
    }
    
    return $success
}

function Invoke-Phase2 {
    Write-Header "PHASE 2: AdminCenter Tenant Setup"
    Write-Info "This phase creates Data Factory, Storage, and Managed Identity in AdminCenter"
    
    # Get tenant info from tfvars
    $tfvarsContent = Get-Content $RootTfvars -Raw
    $admincenterTenant = if ($tfvarsContent -match 'admincenter_tenant_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter AdminCenter Tenant ID"
    }
    
    Test-AzureLogin -TenantId $admincenterTenant
    
    # Set subscription
    $admincenterSub = if ($tfvarsContent -match 'admincenter_subscription_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter AdminCenter Subscription ID"
    }
    
    az account set --subscription $admincenterSub
    
    # Execute phase
    $success = Invoke-TerraformPhase -PhaseName "AdminCenter Setup" -PhaseDir $Phase2Dir -OutputFile $Phase2OutputFile
    
    if ($success) {
        Write-Success "Phase 2 Complete!"
        Write-Info "Save the outputs above - you'll need them for Phase 3 and 4"
        Write-Section "Next Steps"
        Write-Info "1. Record the managed_identity_client_id"
        Write-Info "2. Record the data_factory_name"
        Write-Info "3. Record the storage_account_name"
        Write-Info "4. Move to Phase 3 in GameBoard tenant"
    }
    
    return $success
}

function Invoke-Phase3 {
    Write-Header "PHASE 3: Workload Identity Federation"
    Write-Info "This phase creates the trust relationship between tenants"
    Write-Info "Required: Outputs from Phase 1 and Phase 2"
    
    # Validate prerequisites
    if (!(Test-Path $Phase1OutputFile)) {
        Write-Error "Phase 1 outputs not found. Run Phase 1 first."
        return $false
    }
    
    if (!(Test-Path $Phase2OutputFile)) {
        Write-Error "Phase 2 outputs not found. Run Phase 2 first."
        return $false
    }
    
    # Load outputs
    $phase1Outputs = Get-Content $Phase1OutputFile | ConvertFrom-Json
    $phase2Outputs = Get-Content $Phase2OutputFile | ConvertFrom-Json
    
    # Back to GameBoard tenant for federation
    $tfvarsContent = Get-Content $RootTfvars -Raw
    $gameboardTenant = if ($tfvarsContent -match 'gameboard_tenant_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter GameBoard Tenant ID"
    }
    
    Test-AzureLogin -TenantId $gameboardTenant
    
    # Set subscription
    $gameboardSub = if ($tfvarsContent -match 'gameboard_subscription_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter GameBoard Subscription ID"
    }
    
    az account set --subscription $gameboardSub
    
    # Execute phase
    $success = Invoke-TerraformPhase -PhaseName "Workload Identity Federation" -PhaseDir $Phase3Dir -OutputFile $Phase3OutputFile
    
    if ($success) {
        Write-Success "Phase 3 Complete!"
        Write-Section "Next Steps"
        Write-Info "1. Wait 2-3 minutes for federation to propagate"
        Write-Info "2. Move to Phase 4 in AdminCenter tenant"
    }
    
    return $success
}

function Invoke-Phase4 {
    Write-Header "PHASE 4: Data Factory Pipeline"
    Write-Info "This phase creates the actual copy pipeline"
    Write-Info "Required: All previous phases must be completed"
    
    # Back to AdminCenter tenant
    $tfvarsContent = Get-Content $RootTfvars -Raw
    $admincenterTenant = if ($tfvarsContent -match 'admincenter_tenant_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter AdminCenter Tenant ID"
    }
    
    Test-AzureLogin -TenantId $admincenterTenant
    
    # Set subscription
    $admincenterSub = if ($tfvarsContent -match 'admincenter_subscription_id\s*=\s*"([^"]+)"') {
        $Matches[1]
    } else {
        Read-Host "Enter AdminCenter Subscription ID"
    }
    
    az account set --subscription $admincenterSub
    
    # Execute phase
    $success = Invoke-TerraformPhase -PhaseName "Data Factory Pipeline" -PhaseDir $Phase4Dir -OutputFile $null
    
    if ($success) {
        Write-Success "Phase 4 Complete!"
        Write-Success "Your entire deployment is now complete!"
        Write-Section "Next Steps"
        Write-Info "1. Go to Azure Portal → Data Factory"
        Write-Info "2. Find the 'Copy-GameBoard-Logs' pipeline"
        Write-Info "3. Click 'Add trigger' → 'New' → 'Trigger now' to test"
        Write-Info "4. Check AdminCenter storage account for logs"
        Write-Info "5. Verify logs are in Parquet format with date partitioning"
    }
    
    return $success
}

# ============================================================================
# MENU AND MAIN EXECUTION
# ============================================================================

function Show-Menu {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  GameBoard to AdminCenter Migration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) Run Phase 1: GameBoard Setup" -ForegroundColor Yellow
    Write-Host "2) Run Phase 2: AdminCenter Setup" -ForegroundColor Yellow
    Write-Host "3) Run Phase 3: Federation" -ForegroundColor Yellow
    Write-Host "4) Run Phase 4: Data Factory Pipeline" -ForegroundColor Yellow
    Write-Host "5) Run All Phases (1→2→3→4)" -ForegroundColor Green
    Write-Host "6) Validate Setup (Prerequisites only)" -ForegroundColor Cyan
    Write-Host "7) Destroy All (DANGEROUS)" -ForegroundColor Red
    Write-Host "0) Exit" -ForegroundColor White
    Write-Host ""
}

function Main {
    Write-Host ""
    Write-Header "GameBoard to AdminCenter Terraform Deployment"
    
    # Check prerequisites
    Test-Prerequisites
    
    # Handle command-line phase parameter
    if ($Phase -ne "all") {
        Write-Info "Running Phase: $Phase"
        
        switch ($Phase) {
            "1" { $success = Invoke-Phase1 }
            "2" { $success = Invoke-Phase2 }
            "3" { $success = Invoke-Phase3 }
            "4" { $success = Invoke-Phase4 }
            "validate" {
                Write-Success "Prerequisites validated successfully!"
                $success = $true
            }
        }
        
        exit ($success ? 0 : 1)
    }
    
    # Interactive menu
    while ($true) {
        Show-Menu
        $choice = Read-Host "Select an option (0-7)"
        
        switch ($choice) {
            "1" { Invoke-Phase1 }
            "2" { Invoke-Phase2 }
            "3" { Invoke-Phase3 }
            "4" { Invoke-Phase4 }
            "5" {
                Write-Header "Running All Phases"
                if (Invoke-Phase1 -and Invoke-Phase2 -and Invoke-Phase3 -and Invoke-Phase4) {
                    Write-Header "All phases completed successfully!"
                } else {
                    Write-Error "One or more phases failed. Check errors above."
                }
            }
            "6" {
                Write-Success "Validation passed - all prerequisites are met!"
            }
            "7" {
                Write-Warning "This will destroy ALL resources created by this deployment!"
                $confirm = Read-Host "Type 'DESTROY' to confirm"
                if ($confirm -eq "DESTROY") {
                    # Destroy in reverse order
                    Write-Info "Destroying Phase 4..."
                    Push-Location $Phase4Dir
                    terraform destroy -auto-approve
                    Pop-Location
                    
                    Write-Info "Destroying Phase 3..."
                    Push-Location $Phase3Dir
                    terraform destroy -auto-approve
                    Pop-Location
                    
                    Write-Info "Destroying Phase 2..."
                    Push-Location $Phase2Dir
                    terraform destroy -auto-approve
                    Pop-Location
                    
                    Write-Info "Destroying Phase 1..."
                    Push-Location $Phase1Dir
                    terraform destroy -auto-approve
                    Pop-Location
                    
                    Write-Success "All resources destroyed"
                }
            }
            "0" {
                Write-Info "Exiting..."
                exit 0
            }
            default {
                Write-Error "Invalid option. Please try again."
            }
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
}

# ============================================================================
# EXECUTE
# ============================================================================

Main
