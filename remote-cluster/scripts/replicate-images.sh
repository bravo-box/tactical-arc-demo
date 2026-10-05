#!/usr/bin/env bash
# Replicate edge application images from an Azure Container Registry onto
# this device: optional Docker login, image pre-pull, and optional K3s
# (containerd) registry authentication so Helm-triggered pulls succeed.
#
# Run this on the edge device:
#   ./replicate-images.sh --registry <loginServer> [options]
set -euo pipefail

REGISTRY=""
TAG="0.1.0"
IMAGES=()
USERNAME=""
CREDENTIAL_FILE=""
CONFIGURE_K3S="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --registry)
    REGISTRY="$2"
    shift 2
    ;;
  --tag)
    TAG="$2"
    shift 2
    ;;
  --image)
    IMAGES+=("$2")
    shift 2
    ;;
  --username)
    USERNAME="$2"
    shift 2
    ;;
  --credential-file)
    CREDENTIAL_FILE="$2"
    shift 2
    ;;
  --configure-k3s)
    CONFIGURE_K3S="true"
    shift
    ;;
  -h | --help)
    sed -n '2,7p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Required command not found: docker" >&2
  exit 1
fi
if [ -z "${REGISTRY}" ]; then
  echo "--registry is required" >&2
  exit 1
fi
if [ -n "${USERNAME}" ] && { [ -z "${CREDENTIAL_FILE}" ] || [ ! -r "${CREDENTIAL_FILE}" ] || [ ! -s "${CREDENTIAL_FILE}" ]; }; then
  echo "--username requires a readable, non-empty --credential-file" >&2
  exit 1
fi
if [ "${CONFIGURE_K3S}" = "true" ] && [ -z "${USERNAME}" ]; then
  echo "--configure-k3s requires --username and --credential-file" >&2
  exit 1
fi

if [ "${#IMAGES[@]}" -eq 0 ]; then
  IMAGES=(edge-heartbeat device-service location-service)
fi

if [ -n "${USERNAME}" ]; then
  echo "Logging in to ${REGISTRY}..."
  docker login "${REGISTRY}" --username "${USERNAME}" --password-stdin <"${CREDENTIAL_FILE}"
fi

for image in "${IMAGES[@]}"; do
  ref="${REGISTRY%/}/${image}:${TAG}"
  echo "Pulling ${ref}..."
  docker pull "${ref}"
done

if [ "${CONFIGURE_K3S}" = "true" ]; then
  if [ "$(id -u)" -ne 0 ]; then
    echo "--configure-k3s must be run as root (use sudo)." >&2
    exit 1
  fi
  echo "Writing K3s containerd registry credentials for ${REGISTRY}..."
  install -d -m 0755 /etc/rancher/k3s
  credential_value="$(cat "${CREDENTIAL_FILE}")"
  cat >/etc/rancher/k3s/registries.yaml <<EOF
configs:
  "${REGISTRY}":
    auth:
      username: ${USERNAME}
      password: ${credential_value}
EOF
  chmod 0600 /etc/rancher/k3s/registries.yaml
  echo "Restarting K3s to apply registry configuration..."
  systemctl restart k3s
fi

echo "Image replication complete."
