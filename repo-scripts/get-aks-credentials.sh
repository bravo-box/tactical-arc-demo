#!/usr/bin/env bash
# repo-scripts/get-aks-credentials.sh
# Retrieve AKS cluster credentials and set up kubectl context.
#
# Required environment variables:
#   AKS_RESOURCE_GROUP  - Resource group containing the AKS cluster
#   AKS_CLUSTER_NAME    - Name of the AKS cluster

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP:-tactical-arc-dev-rg}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-tactical-arc-dev-aks}"

echo "================================================"
echo " Tactical ARC Demo - Get AKS Credentials"
echo "================================================"
log_info "Resource Group: ${AKS_RESOURCE_GROUP}"
log_info "Cluster Name:   ${AKS_CLUSTER_NAME}"
echo ""

log_info "Fetching AKS credentials from Azure Government..."
az aks get-credentials \
  --resource-group "${AKS_RESOURCE_GROUP}" \
  --name "${AKS_CLUSTER_NAME}" \
  --environment AzureUSGovernment \
  --overwrite-existing

log_info "kubectl context set to ${AKS_CLUSTER_NAME}"
log_info "Verifying connectivity..."
kubectl get nodes

log_info "AKS credentials retrieved successfully"
