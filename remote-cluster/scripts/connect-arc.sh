#!/usr/bin/env bash
# Connect the edge Kubernetes cluster to Azure Arc in Azure Government.
#
# Usage: connect-arc.sh --resource-group <rg> --name <arc-cluster-name> [--location <region>]
set -euo pipefail

RESOURCE_GROUP=""
CLUSTER_NAME=""
LOCATION="usgovvirginia"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --resource-group)
    RESOURCE_GROUP="$2"
    shift 2
    ;;
  --name)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  --location)
    LOCATION="$2"
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
  echo "--resource-group and --name are required" >&2
  exit 1
fi

az cloud set --name AzureUSGovernment
az extension add --name connectedk8s --upgrade --yes

az connectedk8s connect \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --location "${LOCATION}"

az connectedk8s show --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --output table
