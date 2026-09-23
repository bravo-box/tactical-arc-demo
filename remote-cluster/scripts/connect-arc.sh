#!/usr/bin/env bash
# Connect the edge Kubernetes cluster to Azure Arc.
#
# Usage: connect-arc.sh --resource-group <rg> --name <arc-name> [options]
set -euo pipefail

RESOURCE_GROUP=""
CLUSTER_NAME=""
LOCATION="usgovvirginia"
CLOUD="AzureUSGovernment"
SUBSCRIPTION=""
CREATE_RESOURCE_GROUP="false"
LIST_RESOURCE_GROUPS="false"

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
  --cloud)
    CLOUD="$2"
    shift 2
    ;;
  --subscription)
    SUBSCRIPTION="$2"
    shift 2
    ;;
  --create-resource-group)
    CREATE_RESOURCE_GROUP="true"
    shift
    ;;
  --list-resource-groups)
    LIST_RESOURCE_GROUPS="true"
    shift
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

for command in az kubectl helm; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done

az cloud set --name "${CLOUD}"
if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI login required for ${CLOUD}; run: az login" >&2
  exit 1
fi
if [ -n "${SUBSCRIPTION}" ]; then
  az account set --subscription "${SUBSCRIPTION}"
fi

echo "Azure context:"
az account show --query '{Name:name,Cloud:environmentName}' --output table

if [ "${LIST_RESOURCE_GROUPS}" = "true" ]; then
  az group list --query '[].{Name:name,Location:location}' --output table
  if [ -z "${RESOURCE_GROUP}" ] && [ -z "${CLUSTER_NAME}" ]; then
    exit 0
  fi
fi

if [ -z "${RESOURCE_GROUP}" ] || [ -z "${CLUSTER_NAME}" ]; then
  echo "--resource-group and --name are required" >&2
  exit 1
fi

if ! az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  if [ "${CREATE_RESOURCE_GROUP}" != "true" ]; then
    echo "Resource group '${RESOURCE_GROUP}' does not exist." >&2
    echo "Use --create-resource-group or choose one from --list-resource-groups." >&2
    exit 1
  fi
  az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none
fi

kubectl cluster-info >/dev/null
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az extension add --name connectedk8s --upgrade --yes

if az connectedk8s show --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" >/dev/null 2>&1; then
  echo "Azure Arc connection already exists; showing current status."
else
  az connectedk8s connect \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --location "${LOCATION}"
fi

az connectedk8s show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --query '{Name:name,ResourceGroup:resourceGroup,Location:location,Status:connectivityStatus}' \
  --output table
