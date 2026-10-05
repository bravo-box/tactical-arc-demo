#!/usr/bin/env bash
# Create (optionally) and configure an Azure Container Registry for edge
# device pulls: either enable anonymous pull for a lab/demo registry, or
# grant the identity signed in to the Azure CLI an ACR role (default AcrPull)
# so it can authenticate with Microsoft Entra ID via `az acr login`.
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
AUTHENTICATED_PULL="false"
ROLE="AcrPull"

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
  --authenticated-pull)
    AUTHENTICATED_PULL="true"
    shift
    ;;
  --role)
    ROLE="$2"
    shift 2
    ;;
  --pull-token | --repository | --secret-file)
    echo "$1 is no longer supported; use --authenticated-pull to grant the signed-in Azure CLI identity access." >&2
    exit 1
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

if ! command -v az >/dev/null 2>&1; then
  echo "Required command not found: az" >&2
  exit 1
fi

if [ -z "${NAME}" ]; then
  echo "--name is required" >&2
  exit 1
fi
if [ "${AUTHENTICATED_PULL}" = "true" ] && [ "${ANONYMOUS_PULL}" = "true" ]; then
  echo "--authenticated-pull and --anonymous-pull are mutually exclusive" >&2
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

if [ "${AUTHENTICATED_PULL}" = "true" ]; then
  account_name="$(az account show --query user.name --output tsv)"
  account_type="$(az account show --query user.type --output tsv)"
  case "${account_type}" in
  user)
    principal_id="$(az ad signed-in-user show --query id --output tsv)"
    principal_type="User"
    ;;
  servicePrincipal)
    principal_id="$(az ad sp show --id "${account_name}" --query id --output tsv)"
    principal_type="ServicePrincipal"
    ;;
  *)
    echo "Unsupported Azure CLI account type '${account_type}'; sign in as a user or service principal." >&2
    exit 1
    ;;
  esac
  if [ -z "${principal_id}" ]; then
    echo "Could not resolve the object ID of the signed-in Azure CLI identity." >&2
    exit 1
  fi

  registry_id="$(az acr show --name "${NAME}" --query id --output tsv)"
  existing="$(
    az role assignment list \
      --assignee "${principal_id}" \
      --role "${ROLE}" \
      --scope "${registry_id}" \
      --query "length(@)" \
      --output tsv
  )"
  if [ "${existing}" != "0" ]; then
    echo "'${account_name}' already has '${ROLE}' on '${NAME}'."
  else
    echo "Granting '${ROLE}' on '${NAME}' to the signed-in identity '${account_name}'..."
    az role assignment create \
      --assignee-object-id "${principal_id}" \
      --assignee-principal-type "${principal_type}" \
      --role "${ROLE}" \
      --scope "${registry_id}" \
      --output none
    echo "Role assignments can take a few minutes to propagate."
  fi

  echo "Verifying Microsoft Entra sign-in to '${NAME}'..."
  if az acr login --name "${NAME}" --expose-token --output none 2>/dev/null; then
    echo "The signed-in identity can obtain a registry access token."
  else
    echo "Warning: could not obtain a registry access token. A private registry" >&2
    echo "requires VPN/private DNS connectivity (see configure-vpn.sh)." >&2
  fi

  echo "Registry login server: ${LOGIN_SERVER}"
  echo "Sign in with 'az login' as '${account_name}' (or any identity granted"
  echo "'${ROLE}'), then authenticate with: az acr login --name ${NAME}"
fi

if [ "${ANONYMOUS_PULL}" != "true" ] && [ "${AUTHENTICATED_PULL}" != "true" ]; then
  echo "Registry login server: ${LOGIN_SERVER}"
fi
