#!/usr/bin/env bash
# Create (optionally) and configure an Azure Container Registry for edge
# device pulls: either enable anonymous pull for a lab/demo registry, or
# create a least-privilege repository-scoped pull token.
#
# Usage: configure-registry.sh --name <acrName> [options]
set -euo pipefail

NAME=""
RESOURCE_GROUP=""
LOCATION="usgovvirginia"
CLOUD="AzureUSGovernment"
SUBSCRIPTION=""
SKU="Basic"
CREATE_RESOURCE_GROUP="false"
CREATE_REGISTRY="false"
ANONYMOUS_PULL="false"
TOKEN_NAME=""
REPOSITORIES=()
SECRET_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --name)
    NAME="$2"
    shift 2
    ;;
  --resource-group)
    RESOURCE_GROUP="$2"
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
  --sku)
    SKU="$2"
    shift 2
    ;;
  --create-resource-group)
    CREATE_RESOURCE_GROUP="true"
    shift
    ;;
  --create-registry)
    CREATE_REGISTRY="true"
    shift
    ;;
  --anonymous-pull)
    ANONYMOUS_PULL="true"
    shift
    ;;
  --pull-token)
    TOKEN_NAME="$2"
    shift 2
    ;;
  --repository)
    REPOSITORIES+=("$2")
    shift 2
    ;;
  --secret-file)
    SECRET_FILE="$2"
    shift 2
    ;;
  -h | --help)
    sed -n '2,6p' "${BASH_SOURCE[0]}"
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

if [ -z "${NAME}" ]; then
  echo "--name is required" >&2
  exit 1
fi
if [ -n "${TOKEN_NAME}" ] && [ "${ANONYMOUS_PULL}" = "true" ]; then
  echo "--pull-token and --anonymous-pull are mutually exclusive" >&2
  exit 1
fi
if [ -n "${TOKEN_NAME}" ] && [ "${#REPOSITORIES[@]}" -eq 0 ]; then
  echo "--pull-token requires at least one --repository" >&2
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

if [ "${CREATE_REGISTRY}" = "true" ] || [ -n "${RESOURCE_GROUP}" ]; then
  if [ -z "${RESOURCE_GROUP}" ]; then
    echo "--resource-group is required with --create-registry" >&2
    exit 1
  fi
  if ! az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    if [ "${CREATE_RESOURCE_GROUP}" != "true" ]; then
      echo "Resource group '${RESOURCE_GROUP}' does not exist." >&2
      echo "Use --create-resource-group or create it first." >&2
      exit 1
    fi
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none
  fi
fi

if az acr show --name "${NAME}" >/dev/null 2>&1; then
  echo "Registry '${NAME}' already exists."
elif [ "${CREATE_REGISTRY}" = "true" ]; then
  if [ -z "${RESOURCE_GROUP}" ]; then
    echo "--resource-group is required with --create-registry" >&2
    exit 1
  fi
  echo "Creating registry '${NAME}'..."
  az acr create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${NAME}" \
    --sku "${SKU}" \
    --output none
else
  echo "Registry '${NAME}' does not exist; pass --create-registry to create it." >&2
  exit 1
fi

LOGIN_SERVER="$(az acr show --name "${NAME}" --query loginServer --output tsv)"

if [ "${ANONYMOUS_PULL}" = "true" ]; then
  echo "Enabling anonymous pull on '${NAME}'..."
  az acr update --name "${NAME}" --anonymous-pull-enabled true --output none
  echo "Registry login server: ${LOGIN_SERVER}"
  echo "Devices can pull images from ${LOGIN_SERVER} without credentials."
fi

if [ -n "${TOKEN_NAME}" ]; then
  echo "Creating repository-scoped pull token '${TOKEN_NAME}'..."
  scope_map_args=()
  for repo in "${REPOSITORIES[@]}"; do
    scope_map_args+=(--repository "${repo}" content/read)
  done
  if az acr token show --registry "${NAME}" --name "${TOKEN_NAME}" >/dev/null 2>&1; then
    echo "Token '${TOKEN_NAME}' already exists; updating its repository scope."
    az acr token update \
      --registry "${NAME}" \
      --name "${TOKEN_NAME}" \
      "${scope_map_args[@]}" \
      --output none
  else
    az acr token create \
      --registry "${NAME}" \
      --name "${TOKEN_NAME}" \
      "${scope_map_args[@]}" \
      --output none
  fi

  token_secret="$(
    az acr token credential generate \
      --registry "${NAME}" \
      --name "${TOKEN_NAME}" \
      --password1 \
      --query passwords[0].value \
      --output tsv
  )"

  echo "Registry login server: ${LOGIN_SERVER}"
  echo "Pull token username:   ${TOKEN_NAME}"
  if [ -n "${SECRET_FILE}" ]; then
    install -d -m 0700 "$(dirname "${SECRET_FILE}")"
    umask 077
    printf '%s\n' "${token_secret}" >"${SECRET_FILE}"
    chmod 0600 "${SECRET_FILE}"
    echo "Pull token credential written to ${SECRET_FILE} (mode 0600)."
  else
    echo "Pull token credential: ${token_secret}"
  fi
fi

if [ "${ANONYMOUS_PULL}" != "true" ] && [ -z "${TOKEN_NAME}" ]; then
  echo "Registry login server: ${LOGIN_SERVER}"
fi
