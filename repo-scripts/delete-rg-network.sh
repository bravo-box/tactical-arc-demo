#!/usr/bin/env bash
# repo-scripts/delete-rg-network.sh
# Deletes the resource group (and all resources within it) in Azure Government,
# and removes the generated terraform.tfvars so you can start fresh.
#
# Usage: delete-rg-network.sh [options]
#   --project-name    Project name prefix (default: tactical-arc)
#   --environment     Deployment environment (default: dev)
#   --yes             Skip confirmation prompt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infra"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Defaults
PROJECT_NAME="tactical-arc"
ENVIRONMENT="dev"
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)  PROJECT_NAME="$2"; shift 2 ;;
    --environment)   ENVIRONMENT="$2"; shift 2 ;;
    --yes)           SKIP_CONFIRM=true; shift ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

RG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-rg"

echo "================================================"
echo " Tactical ARC Demo - Delete RG & Network"
echo "================================================"
echo ""
log_warn "This will DELETE the resource group '${RG_NAME}' and ALL resources within it."
echo ""

# Verify Azure CLI is logged in to Azure Government
log_info "Verifying Azure Government login..."
CURRENT_CLOUD=$(az cloud show --query name -o tsv 2>/dev/null || true)
if [[ "${CURRENT_CLOUD}" != "AzureUSGovernment" ]]; then
  log_warn "Current cloud is '${CURRENT_CLOUD}', switching to AzureUSGovernment..."
  az cloud set --name AzureUSGovernment
fi

if ! az account show &>/dev/null 2>&1; then
  log_error "Not logged in. Run: az login --environment AzureUSGovernment"
  exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
log_info "Subscription: ${SUBSCRIPTION_NAME}"
echo ""

# Check if resource group exists
if ! az group show --name "${RG_NAME}" &>/dev/null 2>&1; then
  log_warn "Resource group '${RG_NAME}' does not exist. Nothing to delete."
else
  # Confirmation prompt
  if [[ "${SKIP_CONFIRM}" != true ]]; then
    echo -e "${RED}Are you sure you want to delete '${RG_NAME}' and all its resources? (yes/no)${NC}"
    read -r CONFIRMATION
    if [[ "${CONFIRMATION}" != "yes" ]]; then
      log_info "Aborted. No resources were deleted."
      exit 0
    fi
  fi

  log_info "Deleting resource group '${RG_NAME}'..."
  az group delete \
    --name "${RG_NAME}" \
    --yes \
    --no-wait

  log_info "Resource group deletion initiated (running in background)."
  log_info "Use 'az group show --name ${RG_NAME}' to check status."
fi

echo ""

# Clean up terraform.tfvars
TFVARS_FILE="${INFRA_DIR}/terraform.tfvars"
if [[ -f "${TFVARS_FILE}" ]]; then
  log_info "Removing ${TFVARS_FILE}..."
  rm -f "${TFVARS_FILE}"
  log_info "terraform.tfvars removed"
else
  log_info "No terraform.tfvars found to remove"
fi

# Clean up terraform state files if present
if [[ -f "${INFRA_DIR}/tfplan" ]]; then
  log_info "Removing stale tfplan..."
  rm -f "${INFRA_DIR}/tfplan"
fi

echo ""
log_info "Cleanup complete! You can now run create-rg-network.sh to start fresh."
