#!/usr/bin/env bash
# Install or upgrade edge-heartbeat from a local, repository, URL, or OCI Helm chart.
#
# Usage: deploy.sh [--chart <chart-ref>] [--config <file>] [--device-config <file>] [--connection-string-file <file>] [--location-connection-string-file <file>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART="${SCRIPT_DIR}/../helm/remote-cluster"
CONFIG_FILE="${SCRIPT_DIR}/../config/edge-heartbeat.json"
DEVICE_CONFIG_FILE="${SCRIPT_DIR}/../config/device-info.json"
CONNECTION_STRING_FILE="${SCRIPT_DIR}/../.secrets/servicebus-connection-string"
LOCATION_CONNECTION_STRING_FILE="${SCRIPT_DIR}/../.secrets/location-servicebus-connection-string"
REGISTRY=""
RELEASE="remote-cluster"
NAMESPACE="tactical-arc"
CHART_VERSION=""
SECRET_NAME="edge-heartbeat-servicebus"
LOCATION_SECRET_NAME="location-service-servicebus"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --chart)
    CHART="$2"
    shift 2
    ;;
  --chart-version)
    CHART_VERSION="$2"
    shift 2
    ;;
  --config)
    CONFIG_FILE="$2"
    shift 2
    ;;
  --device-config)
    DEVICE_CONFIG_FILE="$2"
    shift 2
    ;;
  --connection-string-file)
    CONNECTION_STRING_FILE="$2"
    shift 2
    ;;
  --location-connection-string-file)
    LOCATION_CONNECTION_STRING_FILE="$2"
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

for command in helm kubectl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done
if [ ! -r "${CONFIG_FILE}" ]; then
  echo "Heartbeat configuration is not readable: ${CONFIG_FILE}" >&2
  exit 1
fi
if [ ! -r "${DEVICE_CONFIG_FILE}" ]; then
  echo "Device information configuration is not readable: ${DEVICE_CONFIG_FILE}" >&2
  exit 1
fi
if [ ! -r "${CONNECTION_STRING_FILE}" ] || [ ! -s "${CONNECTION_STRING_FILE}" ]; then
  echo "Service Bus credential is missing or empty: ${CONNECTION_STRING_FILE}" >&2
  echo "Run configure-service-bus.sh first or pass --connection-string-file." >&2
  exit 1
fi
if [ ! -r "${LOCATION_CONNECTION_STRING_FILE}" ] || [ ! -s "${LOCATION_CONNECTION_STRING_FILE}" ]; then
  echo "Location Service Bus credential is missing or empty: ${LOCATION_CONNECTION_STRING_FILE}" >&2
  echo "Run configure-service-bus.sh first or pass --location-connection-string-file." >&2
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client --output yaml | kubectl apply -f -
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-file="connection-string=${CONNECTION_STRING_FILE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -
kubectl create secret generic "${LOCATION_SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-file="connection-string=${LOCATION_CONNECTION_STRING_FILE}" \
  --dry-run=client \
  --output yaml |
  kubectl apply -f -

helm_args=(
  --namespace "${NAMESPACE}"
  --create-namespace
  --wait
  --set-file "edgeHeartbeat.config=${CONFIG_FILE}"
  --set-string "deviceService.configHostPath=$(readlink -f "${DEVICE_CONFIG_FILE}")"
  --set "edgeHeartbeat.serviceBus.existingSecret=${SECRET_NAME}"
  --set "locationService.serviceBus.existingSecret=${LOCATION_SECRET_NAME}"
)
if [ -n "${REGISTRY}" ]; then
  helm_args+=(--set "imageRegistry=${REGISTRY}")
fi
if [ -n "${CHART_VERSION}" ]; then
  helm_args+=(--version "${CHART_VERSION}")
fi

helm upgrade --install "${RELEASE}" "${CHART}" "${helm_args[@]}"
kubectl rollout status \
  --namespace "${NAMESPACE}" \
  deployment \
  --selector "app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/component=edge-heartbeat" \
  --timeout=180s
kubectl rollout status \
  --namespace "${NAMESPACE}" \
  deployment \
  --selector "app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/component=location-service" \
  --timeout=180s
kubectl rollout status \
  --namespace "${NAMESPACE}" \
  deployment \
  --selector "app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/component=device-service" \
  --timeout=180s
