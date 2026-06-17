#!/usr/bin/env bash
# local-app/agent/run-local.sh
# Run the edge agent locally for development/testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="${SCRIPT_DIR}"

echo "==> Starting Edge Agent locally..."

# Ensure virtual environment
if [[ ! -d "${AGENT_DIR}/.venv" ]]; then
  echo "==> Creating Python virtual environment..."
  python3 -m venv "${AGENT_DIR}/.venv"
fi

source "${AGENT_DIR}/.venv/bin/activate"

echo "==> Installing dependencies..."
pip install --quiet -r "${AGENT_DIR}/requirements.txt"

echo "==> Launching edge agent..."
export CLOUD_API_URL="${CLOUD_API_URL:-http://localhost:8080/api/v1}"
export DEVICE_ID="${DEVICE_ID:-jetson-nano-local-dev}"
export HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-10}"
export AZURE_ENVIRONMENT="AzureUSGovernment"

python3 "${AGENT_DIR}/src/agent.py"
