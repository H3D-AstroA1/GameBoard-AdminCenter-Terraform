#!/bin/bash
# ============================================================================
# GAMEBOARD TO ADMINCENTER - AUTOMATED TERRAFORM DEPLOYMENT
# ============================================================================
# 
# This script automates all 4 phases of Terraform deployment
# Run with: bash deploy.sh
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# VARIABLES - CUSTOMIZE THESE
# ============================================================================

GAMEBOARD_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
GAMEBOARD_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ADMINCENTER_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ADMINCENTER_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# ============================================================================
# PHASE 1: GAMEBOARD TENANT SETUP
# ============================================================================

phase1_setup() {
    log_info "Starting Phase 1: GameBoard Tenant Setup..."
    
    # Login to GameBoard
    log_info "Logging into GameBoard Tenant..."
    az logout 2>/dev/null || true
    az login --tenant $GAMEBOARD_TENANT_ID
    az account set --subscription $GAMEBOARD_SUBSCRIPTION_ID
    
    # Initialize and apply Terraform
    log_info "Initializing Terraform for Phase 1..."
    cd "$SCRIPT_DIR/phase1-gameboard"
    terraform init
    
    log_info "Planning Phase 1 deployment..."
    terraform plan -out=phase1.plan
    
    log_info "Applying Phase 1 configuration..."
    terraform apply phase1.plan
    
    # Capture outputs
    log_info "Capturing Phase 1 outputs..."
    SERVICE_PRINCIPAL_APP_ID=$(terraform output -raw service_principal_app_id)
    SERVICE_PRINCIPAL_OBJECT_ID=$(terraform output -raw service_principal_object_id)
    SERVICE_PRINCIPAL_TENANT_ID=$(terraform output -raw service_principal_tenant_id)
    
    log_success "Phase 1 Complete!"
    echo ""
    echo "Save these values for Phase 3:"
    echo "SERVICE_PRINCIPAL_APP_ID=$SERVICE_PRINCIPAL_APP_ID"
    echo "SERVICE_PRINCIPAL_OBJECT_ID=$SERVICE_PRINCIPAL_OBJECT_ID"
    echo ""
    
    # Return to root
    cd "$SCRIPT_DIR"
}

# ============================================================================
# PHASE 2: ADMINCENTER TENANT SETUP
# ============================================================================

phase2_setup() {
    log_info "Starting Phase 2: AdminCenter Tenant Setup..."
    
    # Login to AdminCenter
    log_info "Logging into AdminCenter Tenant..."
    az logout 2>/dev/null || true
    az login --tenant $ADMINCENTER_TENANT_ID
    az account set --subscription $ADMINCENTER_SUBSCRIPTION_ID
    
    # Initialize and apply Terraform
    log_info "Initializing Terraform for Phase 2..."
    cd "$SCRIPT_DIR/phase2-admincenter"
    terraform init
    
    log_info "Planning Phase 2 deployment..."
    terraform plan -out=phase2.plan
    
    log_info "Applying Phase 2 configuration..."
    terraform apply phase2.plan
    
    # Capture outputs
    log_info "Capturing Phase 2 outputs..."
    MANAGED_IDENTITY_CLIENT_ID=$(terraform output -raw managed_identity_client_id)
    MANAGED_IDENTITY_PRINCIPAL_ID=$(terraform output -raw managed_identity_principal_id)
    DATA_FACTORY_NAME=$(terraform output -raw data_factory_name)
    STORAGE_ACCOUNT_NAME=$(terraform output -raw storage_account_name)
    
    log_success "Phase 2 Complete!"
    echo ""
    echo "Save these values for Phase 3 and Phase 4:"
    echo "MANAGED_IDENTITY_CLIENT_ID=$MANAGED_IDENTITY_CLIENT_ID"
    echo "MANAGED_IDENTITY_PRINCIPAL_ID=$MANAGED_IDENTITY_PRINCIPAL_ID"
    echo "DATA_FACTORY_NAME=$DATA_FACTORY_NAME"
    echo "STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME"
    echo ""
    
    # Return to root
    cd "$SCRIPT_DIR"
}

# ============================================================================
# PHASE 3: WORKLOAD IDENTITY FEDERATION
# ============================================================================

phase3_federation() {
    log_info "Starting Phase 3: Workload Identity Federation..."
    
    read -p "Enter SERVICE_PRINCIPAL_APP_ID (from Phase 1): " SP_APP_ID
    read -p "Enter MANAGED_IDENTITY_CLIENT_ID (from Phase 2): " MI_CLIENT_ID
    
    # Login to GameBoard
    log_info "Logging into GameBoard Tenant for federation setup..."
    az logout 2>/dev/null || true
    az login --tenant $GAMEBOARD_TENANT_ID
    az account set --subscription $GAMEBOARD_SUBSCRIPTION_ID
    
    # Initialize and apply Terraform
    log_info "Initializing Terraform for Phase 3..."
    cd "$SCRIPT_DIR/phase3-federation"
    terraform init
    
    log_info "Planning Phase 3 deployment..."
    terraform plan \
        -var="gameboard_subscription_id=$GAMEBOARD_SUBSCRIPTION_ID" \
        -var="gameboard_tenant_id=$GAMEBOARD_TENANT_ID" \
        -var="admincenter_tenant_id=$ADMINCENTER_TENANT_ID" \
        -var="managed_identity_client_id=$MI_CLIENT_ID" \
        -var="service_principal_app_id=$SP_APP_ID" \
        -out=phase3.plan
    
    log_info "Applying Phase 3 configuration..."
    terraform apply phase3.plan
    
    log_success "Phase 3 Complete! Federation created."
    echo ""
    
    # Return to root
    cd "$SCRIPT_DIR"
}

# ============================================================================
# PHASE 4: DATA FACTORY PIPELINE
# ============================================================================

phase4_datafactory() {
    log_info "Starting Phase 4: Data Factory Pipeline..."
    
    read -p "Enter SERVICE_PRINCIPAL_APP_ID (from Phase 1): " SP_APP_ID
    read -p "Enter DATA_FACTORY_NAME (from Phase 2): " DF_NAME
    read -p "Enter STORAGE_ACCOUNT_NAME (from Phase 2): " STORAGE_NAME
    read -p "Enter GAMEBOARD_WORKSPACE_ID: " WS_ID
    
    # Login to AdminCenter
    log_info "Logging into AdminCenter Tenant..."
    az logout 2>/dev/null || true
    az login --tenant $ADMINCENTER_TENANT_ID
    az account set --subscription $ADMINCENTER_SUBSCRIPTION_ID
    
    # Initialize and apply Terraform
    log_info "Initializing Terraform for Phase 4..."
    cd "$SCRIPT_DIR/phase4-datafactory"
    terraform init
    
    log_info "Planning Phase 4 deployment..."
    terraform plan \
        -var="admincenter_tenant_id=$ADMINCENTER_TENANT_ID" \
        -var="admincenter_subscription_id=$ADMINCENTER_SUBSCRIPTION_ID" \
        -var="data_factory_name=$DF_NAME" \
        -var="storage_account_name=$STORAGE_NAME" \
        -var="gameboard_tenant_id=$GAMEBOARD_TENANT_ID" \
        -var="gameboard_subscription_id=$GAMEBOARD_SUBSCRIPTION_ID" \
        -var="gameboard_service_principal_app_id=$SP_APP_ID" \
        -var="gameboard_workspace_id=$WS_ID" \
        -out=phase4.plan
    
    log_info "Applying Phase 4 configuration..."
    terraform apply phase4.plan
    
    log_success "Phase 4 Complete! Data Factory pipeline created."
    echo ""
    
    # Return to root
    cd "$SCRIPT_DIR"
}

# ============================================================================
# MAIN SCRIPT LOGIC
# ============================================================================

main() {
    log_info "GameBoard to AdminCenter Log Migration - Terraform Deployment"
    echo ""
    
    # Check for terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check for Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install Azure CLI first."
        exit 1
    fi
    
    log_info "Prerequisites check passed."
    echo ""
    
    # Ask which phases to run
    echo "Which phases would you like to run?"
    echo "1) All phases (1, 2, 3, 4)"
    echo "2) Phase 1 only"
    echo "3) Phase 2 only"
    echo "4) Phase 3 only"
    echo "5) Phase 4 only"
    read -p "Enter choice (1-5): " CHOICE
    
    case $CHOICE in
        1)
            phase1_setup
            phase2_setup
            phase3_federation
            phase4_datafactory
            ;;
        2)
            phase1_setup
            ;;
        3)
            phase2_setup
            ;;
        4)
            phase3_federation
            ;;
        5)
            phase4_datafactory
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    log_success "Deployment complete!"
    echo ""
    log_info "Next steps:"
    echo "1. Verify resources in Azure Portal"
    echo "2. Test the Data Factory pipeline manually"
    echo "3. Check logs copied to AdminCenter storage"
}

# Run main
main
