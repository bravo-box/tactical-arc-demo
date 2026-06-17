#!/usr/bin/env bash
# cloud-app/scripts/run-local.sh
# Run the Cloud API locally for development/testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
API_DIR="${REPO_ROOT}/cloud-app/api"

echo "==> Starting Cloud API locally..."
echo "    API directory: ${API_DIR}"

# Ensure virtual environment
if [[ ! -d "${API_DIR}/.venv" ]]; then
  echo "==> Creating Python virtual environment..."
  python3 -m venv "${API_DIR}/.venv"
fi

source "${API_DIR}/.venv/bin/activate"

echo "==> Installing dependencies..."
pip install --quiet -r "${API_DIR}/requirements.txt"

echo "==> Launching Flask development server on http://localhost:8080"
export PORT=8080
export FLASK_DEBUG=true
export AZURE_ENVIRONMENT="AzureUSGovernment"
export ARC_RESOURCE_GROUP="${ARC_RESOURCE_GROUP:-tactical-arc-rg}"
export ARC_CLUSTER_NAME="${ARC_CLUSTER_NAME:-tactical-arc-cluster}"

python3 "${API_DIR}/src/main.py"
