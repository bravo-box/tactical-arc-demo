#!/usr/bin/env bash
# hardware-scripts/jetson-update.sh
# Update the edge agent and system packages on a Jetson Nano device.
#
# Usage: jetson-update.sh [--host <jetson-ip>] [--user <username>] [--image <new-agent-image>]
#   --host   IP or hostname of the Jetson Nano (runs remotely via SSH)
#   --user   SSH user (default: jetson)
#   --image  New agent container image to deploy

set -euo pipefail

JETSON_HOST="${JETSON_HOST:-}"
JETSON_USER="${JETSON_USER:-jetson}"
AGENT_IMAGE="${AGENT_IMAGE:-}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)  JETSON_HOST="$2";  shift 2 ;;
    --user)  JETSON_USER="$2";  shift 2 ;;
    --image) AGENT_IMAGE="$2";  shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# If --host provided, run this script remotely
if [[ -n "${JETSON_HOST}" ]]; then
  log_info "Running update remotely on ${JETSON_USER}@${JETSON_HOST}..."
  ssh "${JETSON_USER}@${JETSON_HOST}" \
    "AGENT_IMAGE='${AGENT_IMAGE}' bash -s" \
    < "${BASH_SOURCE[0]}"
  exit 0
fi

echo "================================================"
echo " Tactical ARC Demo - Jetson Nano Update"
echo "================================================"
echo ""

# Update system packages
log_info "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq
log_info "System packages updated"

# Update edge agent container
if [[ -n "${AGENT_IMAGE}" ]]; then
  log_info "Updating edge agent image to: ${AGENT_IMAGE}..."
  docker pull "${AGENT_IMAGE}"

  # Update systemd unit with new image
  if [[ -f "/etc/systemd/system/tactical-arc-agent.service" ]]; then
    log_info "Restarting edge agent service with new image..."
    sudo sed -i "s|ExecStart=.*|ExecStart=/usr/bin/docker run --rm --name tactical-arc-agent -e DEVICE_ID=\${DEVICE_ID} -e CLOUD_API_URL=\${CLOUD_API_URL} -e AZURE_ENVIRONMENT=AzureUSGovernment ${AGENT_IMAGE}|" \
      /etc/systemd/system/tactical-arc-agent.service
    sudo systemctl daemon-reload
    sudo systemctl restart tactical-arc-agent
    log_info "Edge agent restarted with new image"
  else
    log_warn "Agent service not found. Run jetson-setup.sh first."
  fi
else
  # Restart with current image to pick up config changes
  if systemctl is-active --quiet tactical-arc-agent 2>/dev/null; then
    log_info "Restarting edge agent service..."
    sudo systemctl restart tactical-arc-agent
    log_info "Edge agent restarted"
  else
    log_warn "Edge agent service is not running"
  fi
fi

echo ""
log_info "Jetson Nano update complete!"
