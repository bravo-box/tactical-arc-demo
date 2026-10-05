#!/usr/bin/env bash
# Replicate edge application images from an Azure Container Registry onto
# this device: optional Docker login (Azure CLI identity via --acr-name, or a
# username/credential file), image pre-pull, and optional K3s (containerd)
# registry authentication so Helm-triggered pulls succeed.
#
# Run this on the edge device:
#   ./replicate-images.sh --registry <loginServer> | --acr-name <acrName> [options]
set -euo pipefail

REGISTRY=""
TAG="0.1.0"
IMAGES=()
USERNAME=""
CREDENTIAL_FILE=""
ACR_NAME=""
CONFIGURE_K3S="false"
# ACR accepts Microsoft Entra access tokens with this fixed username.
ACR_TOKEN_USERNAME="00000000-0000-0000-0000-000000000000"

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
  --acr-name)
    ACR_NAME="$2"
    shift 2
    ;;
  --configure-k3s)
    CONFIGURE_K3S="true"
    shift
    ;;
  -h | --help)
    sed -n '2,8p' "${BASH_SOURCE[0]}"
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
if [ -n "${ACR_NAME}" ] && [ -n "${USERNAME}" ]; then
  echo "--acr-name and --username are mutually exclusive" >&2
  exit 1
fi
if [ -z "${REGISTRY}" ] && [ -z "${ACR_NAME}" ]; then
  echo "--registry or --acr-name is required" >&2
  exit 1
fi
if [ -n "${USERNAME}" ] && { [ -z "${CREDENTIAL_FILE}" ] || [ ! -r "${CREDENTIAL_FILE}" ] || [ ! -s "${CREDENTIAL_FILE}" ]; }; then
  echo "--username requires a readable, non-empty --credential-file" >&2
  exit 1
fi
if [ "${CONFIGURE_K3S}" = "true" ] && [ -z "${USERNAME}" ] && [ -z "${ACR_NAME}" ]; then
  echo "--configure-k3s requires --acr-name, or --username and --credential-file" >&2
  exit 1
fi

if [ "${#IMAGES[@]}" -eq 0 ]; then
  IMAGES=(edge-heartbeat device-service location-service)
fi

credential_value=""
if [ -n "${ACR_NAME}" ]; then
  if ! command -v az >/dev/null 2>&1; then
    echo "Required command not found: az" >&2
    exit 1
  fi
  # Under sudo, use the invoking user's Azure CLI sign-in rather than root's.
  az_cmd=(az)
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    az_cmd=(sudo -H -u "${SUDO_USER}" az)
  fi
  if ! "${az_cmd[@]}" account show >/dev/null 2>&1; then
    echo "Azure CLI login required; run: az login" >&2
    exit 1
  fi
  echo "Requesting an ACR access token for the signed-in Azure CLI identity..."
  acr_login="$("${az_cmd[@]}" acr login --name "${ACR_NAME}" --expose-token \
    --query '[loginServer, accessToken]' --output tsv)"
  # TSV output may be tab- or newline-separated; read splits on either.
  read -r -d '' acr_login_server credential_value <<<"${acr_login}" || true
  if [ -z "${acr_login_server}" ] || [ -z "${credential_value}" ]; then
    echo "Could not obtain an access token for ${ACR_NAME}." >&2
    exit 1
  fi
  REGISTRY="${REGISTRY:-${acr_login_server}}"
  USERNAME="${ACR_TOKEN_USERNAME}"
  echo "Logging in to ${REGISTRY}..."
  docker login "${REGISTRY}" --username "${USERNAME}" --password-stdin <<<"${credential_value}"
elif [ -n "${USERNAME}" ]; then
  echo "Logging in to ${REGISTRY}..."
  docker login "${REGISTRY}" --username "${USERNAME}" --password-stdin <"${CREDENTIAL_FILE}"
  credential_value="$(cat "${CREDENTIAL_FILE}")"
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
  umask 077
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
  if [ -n "${ACR_NAME}" ]; then
    echo "Note: the ACR access token expires after about 3 hours; rerun this"
    echo "script to refresh it before later Helm installs or image upgrades."
  fi
fi

echo "Image replication complete."
