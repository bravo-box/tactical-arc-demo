#!/usr/bin/env bash
# Deploy the edge Helm chart onto the edge Kubernetes cluster.
#
# Usage: deploy.sh [--telemetry-url <url>] [--registry <acr>] [--release <name>] [--namespace <ns>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/../helm/remote-cluster"

TELEMETRY_URL=""
REGISTRY=""
RELEASE="remote-cluster"
NAMESPACE="tactical-arc"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --telemetry-url)
    TELEMETRY_URL="$2"
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

helm_args=(--namespace "${NAMESPACE}" --create-namespace --wait)
if [ -n "${REGISTRY}" ]; then
  helm_args+=(--set "imageRegistry=${REGISTRY}")
fi
if [ -n "${TELEMETRY_URL}" ]; then
  helm_args+=(--set "edgeAgent.telemetryUrl=${TELEMETRY_URL}")
fi

helm upgrade --install "${RELEASE}" "${CHART_DIR}" "${helm_args[@]}"
