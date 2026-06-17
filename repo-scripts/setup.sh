#!/usr/bin/env bash
# repo-scripts/setup.sh
# Initialize the development environment for the Tactical ARC Demo.
# Verifies required tools are installed and sets up local configuration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

check_tool() {
  local tool="$1"
  if command -v "${tool}" &>/dev/null; then
    log_info "${tool} found: $(command -v "${tool}")"
  else
    log_warn "${tool} not found - some features may not work"
  fi
}

echo "================================================"
echo " Tactical ARC Demo - Environment Setup"
echo "================================================"
echo ""

log_info "Repository root: ${REPO_ROOT}"
echo ""

# Check required tools
log_info "Checking required tools..."
check_tool az
check_tool terraform
check_tool kubectl
check_tool helm
check_tool docker
check_tool python3
check_tool node
check_tool npm
check_tool dotnet
echo ""

# Azure CLI - check if logged in
log_info "Checking Azure CLI authentication..."
if az account show --environment AzureUSGovernment &>/dev/null 2>&1; then
  AZ_ACCOUNT=$(az account show --environment AzureUSGovernment --query '{name:name, id:id}' -o tsv 2>/dev/null || true)
  log_info "Logged in to Azure Government: ${AZ_ACCOUNT}"
else
  log_warn "Not logged in to Azure Government. Run: az login --environment AzureUSGovernment"
fi
echo ""

# Set up Python virtual environments
log_info "Setting up Cloud API virtual environment..."
if [[ ! -d "${REPO_ROOT}/cloud-app/api/.venv" ]]; then
  python3 -m venv "${REPO_ROOT}/cloud-app/api/.venv"
  log_info "Created venv at cloud-app/api/.venv"
fi
source "${REPO_ROOT}/cloud-app/api/.venv/bin/activate"
pip install --quiet -r "${REPO_ROOT}/cloud-app/api/requirements.txt"
deactivate
log_info "Cloud API dependencies installed"
echo ""

log_info "Setting up Local Agent virtual environment..."
if [[ ! -d "${REPO_ROOT}/local-app/agent/.venv" ]]; then
  python3 -m venv "${REPO_ROOT}/local-app/agent/.venv"
  log_info "Created venv at local-app/agent/.venv"
fi
source "${REPO_ROOT}/local-app/agent/.venv/bin/activate"
pip install --quiet -r "${REPO_ROOT}/local-app/agent/requirements.txt"
deactivate
log_info "Local Agent dependencies installed"
echo ""

log_info "Setup complete!"
log_info "Next steps:"
log_info "  1. Log in to Azure Gov:  az login --environment AzureUSGovernment"
log_info "  2. Initialize Terraform: bash repo-scripts/terraform.sh init"
log_info "  3. Deploy infrastructure: bash repo-scripts/terraform.sh apply"
log_info "  4. Get AKS credentials:  bash repo-scripts/get-aks-credentials.sh"
log_info "  5. Build containers:     bash repo-scripts/build.sh --target all"
log_info "  6. Deploy to AKS:        bash repo-scripts/deploy.sh --target cloud"
