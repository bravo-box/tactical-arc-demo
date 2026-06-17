#!/usr/bin/env bash
# repo-scripts/docker-login.sh
# Authenticate Docker to Azure Container Registry (ACR) in Azure Government.
#
# Required environment variables:
#   ACR_NAME            - ACR name (without .azurecr.us)
#   ARM_ENVIRONMENT     - Azure environment (default: usgovernment)

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

ACR_NAME="${ACR_NAME:-}"
ARM_ENVIRONMENT="${ARM_ENVIRONMENT:-usgovernment}"

if [[ -z "${ACR_NAME}" ]]; then
  log_error "ACR_NAME environment variable is required"
  log_error "Example: export ACR_NAME=tacticalarctfstate"
  exit 1
fi

ACR_ENDPOINT="${ACR_NAME}.azurecr.us"

echo "================================================"
echo " Tactical ARC Demo - Docker ACR Login"
echo "================================================"
log_info "ACR endpoint: ${ACR_ENDPOINT}"
log_info "Environment:  ${ARM_ENVIRONMENT}"
echo ""

log_info "Logging in to Azure Government..."
az login --environment AzureUSGovernment --only-show-errors

log_info "Authenticating Docker to ${ACR_ENDPOINT}..."
az acr login --name "${ACR_NAME}" --environment AzureUSGovernment

log_info "Docker is now authenticated to ${ACR_ENDPOINT}"
