#!/usr/bin/env bash
# Deploy the cloud cluster Helm chart to AKS in Azure Government.
#
# Usage: deploy.sh --resource-group <rg> --cluster <aks-name> [--registry <acr>] [--release <name>] [--namespace <ns>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/../helm/cloud-cluster"

RESOURCE_GROUP=""
CLUSTER_NAME=""
REGISTRY=""
RELEASE="cloud-cluster"
NAMESPACE="tactical-arc"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --resource-group)
    RESOURCE_GROUP="$2"
    shift 2
    ;;
  --cluster)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  --registry)
    REGISTRY="$2"
    shift 2
    ;;
  --release)
    RELEASE="$2"
    shift 2
    ;;
  --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -h | --help)
    sed -n '2,4p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if [ -z "${RESOURCE_GROUP}" ] || [ -z "${CLUSTER_NAME}" ]; then
  echo "--resource-group and --cluster are required" >&2
  exit 1
fi

echo "Fetching credentials for ${CLUSTER_NAME}..."
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --overwrite-existing

helm_args=(--namespace "${NAMESPACE}" --create-namespace --wait)
if [ -n "${REGISTRY}" ]; then
  helm_args+=(--set "imageRegistry=${REGISTRY}")
fi

helm upgrade --install "${RELEASE}" "${CHART_DIR}" "${helm_args[@]}"
