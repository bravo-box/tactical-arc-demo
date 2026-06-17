#!/usr/bin/env bash
# repo-scripts/deploy.sh
# Deploy the Tactical ARC Demo infrastructure and applications.
#
# Usage: deploy.sh [--target infra|cloud|all]
#   --target  What to deploy: infra (Terraform), cloud (Helm to AKS), or all (default: all)
#
# Required environment variables:
#   ACR_NAME            - Azure Container Registry name (without .azurecr.us)
#   AKS_RESOURCE_GROUP  - Resource group containing the AKS cluster
#   AKS_CLUSTER_NAME    - Name of the AKS cluster
#   IMAGE_TAG           - Docker image tag to deploy (default: latest)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Defaults
TARGET="all"
IMAGE_TAG="${IMAGE_TAG:-latest}"
ACR_NAME="${ACR_NAME:-}"
AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP:-tactical-arc-dev-rg}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-tactical-arc-dev-aks}"
HELM_NAMESPACE="${HELM_NAMESPACE:-tactical-arc}"
HELM_RELEASE="${HELM_RELEASE:-cloud-api}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

deploy_infra() {
  log_info "Deploying infrastructure via Terraform..."
  bash "${SCRIPT_DIR}/terraform.sh" apply
  log_info "Infrastructure deployed"
}

deploy_cloud_app() {
  if [[ -z "${ACR_NAME}" ]]; then
    log_error "ACR_NAME environment variable is required"
    exit 1
  fi

  log_info "Deploying Cloud API to AKS via Helm..."
  log_info "  Namespace:  ${HELM_NAMESPACE}"
  log_info "  Release:    ${HELM_RELEASE}"
  log_info "  Image:      ${ACR_NAME}.azurecr.us/cloud-api:${IMAGE_TAG}"

  kubectl create namespace "${HELM_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  helm upgrade --install "${HELM_RELEASE}" \
    "${REPO_ROOT}/cloud-app/api/helm" \
    --namespace "${HELM_NAMESPACE}" \
    --set image.repository="${ACR_NAME}.azurecr.us/cloud-api" \
    --set image.tag="${IMAGE_TAG}" \
    --wait \
    --timeout 5m

  log_info "Cloud API deployed successfully"
  kubectl get pods -n "${HELM_NAMESPACE}"
}

echo "================================================"
echo " Tactical ARC Demo - Deployment"
echo "================================================"
log_info "Target: ${TARGET}"
echo ""

case "${TARGET}" in
  infra)
    deploy_infra
    ;;
  cloud)
    deploy_cloud_app
    ;;
  all)
    deploy_infra
    deploy_cloud_app
    ;;
  *)
    log_error "Unknown target: ${TARGET}. Use infra, cloud, or all."
    exit 1
    ;;
esac

echo ""
log_info "Deployment complete!"
