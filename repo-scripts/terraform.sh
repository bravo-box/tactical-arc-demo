#!/usr/bin/env bash
# repo-scripts/terraform.sh
# Wrapper for Terraform operations in the infra/ directory.
#
# Usage: terraform.sh <command> [options]
#   Commands: init, validate, plan, apply, destroy, output
#
# Required environment variables for Azure Government auth:
#   ARM_ENVIRONMENT=usgovernment
#   ARM_SUBSCRIPTION_ID
#   ARM_TENANT_ID
#   ARM_CLIENT_ID
#   ARM_CLIENT_SECRET

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infra"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

COMMAND="${1:-}"
if [[ -z "${COMMAND}" ]]; then
  log_error "Usage: terraform.sh <init|validate|plan|apply|destroy|output>"
  exit 1
fi

# Ensure ARM_ENVIRONMENT is set to usgovernment
export ARM_ENVIRONMENT="${ARM_ENVIRONMENT:-usgovernment}"

echo "================================================"
echo " Tactical ARC Demo - Terraform: ${COMMAND}"
echo "================================================"
log_info "Infra directory: ${INFRA_DIR}"
log_info "ARM_ENVIRONMENT: ${ARM_ENVIRONMENT}"
echo ""

cd "${INFRA_DIR}"

case "${COMMAND}" in
  init)
    log_info "Initializing Terraform..."
    terraform init -upgrade
    ;;
  validate)
    log_info "Validating Terraform configuration..."
    terraform validate
    ;;
  plan)
    log_info "Running Terraform plan..."
    terraform plan -out=tfplan
    ;;
  apply)
    if [[ -f "${INFRA_DIR}/tfplan" ]]; then
      log_info "Applying saved Terraform plan..."
      terraform apply tfplan
    else
      log_warn "No saved plan found. Running plan + apply..."
      terraform apply -auto-approve
    fi
    ;;
  destroy)
    log_warn "This will DESTROY all infrastructure. Proceeding in 5 seconds..."
    sleep 5
    terraform destroy -auto-approve
    ;;
  output)
    terraform output
    ;;
  *)
    log_error "Unknown command: ${COMMAND}. Use init, validate, plan, apply, destroy, or output."
    exit 1
    ;;
esac

echo ""
log_info "Terraform ${COMMAND} complete"
