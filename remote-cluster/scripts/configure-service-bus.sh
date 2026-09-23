#!/usr/bin/env bash
# Configure the heartbeat Service Bus topic and write its sender credential locally.
#
# Usage: configure-service-bus.sh --resource-group <rg> --namespace <namespace> [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_GROUP=""
NAMESPACE=""
LOCATION="usgovvirginia"
CLOUD="AzureUSGovernment"
SUBSCRIPTION=""
TOPIC="edge-heartbeat"
MONITOR_SUBSCRIPTION="heartbeat-monitor"
AUTH_RULE="edge-device-send"
SECRET_FILE="${SCRIPT_DIR}/../.secrets/servicebus-connection-string"
LOCATION_QUEUE="update-location"
LOCATION_AUTH_RULE="edge-location-listen"
LOCATION_SECRET_FILE="${SCRIPT_DIR}/../.secrets/location-servicebus-connection-string"
CREATE_RESOURCE_GROUP="false"
LIST_RESOURCE_GROUPS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --resource-group)
    RESOURCE_GROUP="$2"
    shift 2
    ;;
  --namespace)
    NAMESPACE="$2"
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
  --topic)
    TOPIC="$2"
    shift 2
    ;;
  --monitor-subscription)
    MONITOR_SUBSCRIPTION="$2"
    shift 2
    ;;
  --secret-file)
    SECRET_FILE="$2"
    shift 2
    ;;
  --location-queue)
    LOCATION_QUEUE="$2"
    shift 2
    ;;
  --location-secret-file)
    LOCATION_SECRET_FILE="$2"
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

if ! command -v az >/dev/null 2>&1; then
  echo "Required command not found: az" >&2
  exit 1
fi

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
  if [ -z "${RESOURCE_GROUP}" ] && [ -z "${NAMESPACE}" ]; then
    exit 0
  fi
fi

if [ -z "${RESOURCE_GROUP}" ] || [ -z "${NAMESPACE}" ]; then
  echo "--resource-group and --namespace are required" >&2
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

if ! az servicebus namespace show --resource-group "${RESOURCE_GROUP}" --name "${NAMESPACE}" >/dev/null 2>&1; then
  az servicebus namespace create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NAMESPACE}" \
    --location "${LOCATION}" \
    --sku Standard \
    --output none
fi

LOCAL_AUTH_DISABLED="$(
  az servicebus namespace show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NAMESPACE}" \
    --query disableLocalAuth \
    --output tsv
)"
PUBLIC_ACCESS="$(
  az servicebus namespace show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NAMESPACE}" \
    --query publicNetworkAccess \
    --output tsv
)"
if [ "${LOCAL_AUTH_DISABLED,,}" = "true" ]; then
  echo "Namespace '${NAMESPACE}' has local authentication disabled." >&2
  echo "Use a dedicated edge namespace or enable local authentication explicitly." >&2
  exit 1
fi
if [ "${PUBLIC_ACCESS,,}" = "disabled" ]; then
  echo "Namespace '${NAMESPACE}' uses private networking; verify this device has VPN/private DNS access." >&2
fi

if ! az servicebus topic show --resource-group "${RESOURCE_GROUP}" --namespace-name "${NAMESPACE}" --name "${TOPIC}" >/dev/null 2>&1; then
  az servicebus topic create \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${NAMESPACE}" \
    --name "${TOPIC}" \
    --output none
fi
if ! az servicebus topic subscription show --resource-group "${RESOURCE_GROUP}" --namespace-name "${NAMESPACE}" --topic-name "${TOPIC}" --name "${MONITOR_SUBSCRIPTION}" >/dev/null 2>&1; then
  az servicebus topic subscription create \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${NAMESPACE}" \
    --topic-name "${TOPIC}" \
    --name "${MONITOR_SUBSCRIPTION}" \
    --output none
fi
if ! az servicebus topic authorization-rule show --resource-group "${RESOURCE_GROUP}" --namespace-name "${NAMESPACE}" --topic-name "${TOPIC}" --name "${AUTH_RULE}" >/dev/null 2>&1; then
  az servicebus topic authorization-rule create \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${NAMESPACE}" \
    --topic-name "${TOPIC}" \
    --name "${AUTH_RULE}" \
    --rights Send \
    --output none
fi

install -d -m 0700 "$(dirname "${SECRET_FILE}")"
umask 077
az servicebus topic authorization-rule keys list \
  --resource-group "${RESOURCE_GROUP}" \
  --namespace-name "${NAMESPACE}" \
  --topic-name "${TOPIC}" \
  --name "${AUTH_RULE}" \
  --query primaryConnectionString \
  --output tsv >"${SECRET_FILE}"
chmod 0600 "${SECRET_FILE}"

if ! az servicebus queue show --resource-group "${RESOURCE_GROUP}" --namespace-name "${NAMESPACE}" --name "${LOCATION_QUEUE}" >/dev/null 2>&1; then
  az servicebus queue create \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${NAMESPACE}" \
    --name "${LOCATION_QUEUE}" \
    --enable-session true \
    --output none
fi
if ! az servicebus queue authorization-rule show --resource-group "${RESOURCE_GROUP}" --namespace-name "${NAMESPACE}" --queue-name "${LOCATION_QUEUE}" --name "${LOCATION_AUTH_RULE}" >/dev/null 2>&1; then
  az servicebus queue authorization-rule create \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${NAMESPACE}" \
    --queue-name "${LOCATION_QUEUE}" \
    --name "${LOCATION_AUTH_RULE}" \
    --rights Listen \
    --output none
fi
install -d -m 0700 "$(dirname "${LOCATION_SECRET_FILE}")"
az servicebus queue authorization-rule keys list \
  --resource-group "${RESOURCE_GROUP}" \
  --namespace-name "${NAMESPACE}" \
  --queue-name "${LOCATION_QUEUE}" \
  --name "${LOCATION_AUTH_RULE}" \
  --query primaryConnectionString \
  --output tsv >"${LOCATION_SECRET_FILE}"
chmod 0600 "${LOCATION_SECRET_FILE}"

echo "Configured Service Bus topic '${TOPIC}' and subscription '${MONITOR_SUBSCRIPTION}'."
echo "Sender credential written to ${SECRET_FILE} (mode 0600)."
echo "Location receiver credential written to ${LOCATION_SECRET_FILE} (mode 0600)."
