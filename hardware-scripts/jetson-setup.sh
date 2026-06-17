#!/usr/bin/env bash
# hardware-scripts/jetson-setup.sh
# Initial setup and configuration for a Jetson Nano edge device.
# This script is intended to be run directly on the Jetson Nano OR
# executed remotely via SSH.
#
# Usage: jetson-setup.sh [--host <jetson-ip>] [--user <username>]
#   --host  IP or hostname of the Jetson Nano (runs remotely via SSH)
#   --user  SSH user (default: jetson)
#
# If --host is not provided, the script runs locally on the Jetson Nano.

set -euo pipefail

JETSON_HOST="${JETSON_HOST:-}"
JETSON_USER="${JETSON_USER:-jetson}"
DEVICE_ID="${DEVICE_ID:-jetson-nano-001}"
CLOUD_API_URL="${CLOUD_API_URL:-}"
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
    --host)   JETSON_HOST="$2";  shift 2 ;;
    --user)   JETSON_USER="$2";  shift 2 ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# If --host provided, run this script remotely
if [[ -n "${JETSON_HOST}" ]]; then
  log_info "Running setup remotely on ${JETSON_USER}@${JETSON_HOST}..."
  ssh "${JETSON_USER}@${JETSON_HOST}" \
    "DEVICE_ID='${DEVICE_ID}' CLOUD_API_URL='${CLOUD_API_URL}' AGENT_IMAGE='${AGENT_IMAGE}' bash -s" \
    < "${BASH_SOURCE[0]}"
  exit 0
fi

echo "================================================"
echo " Tactical ARC Demo - Jetson Nano Setup"
echo "================================================"
log_info "Device ID: ${DEVICE_ID}"
echo ""

# Update system packages
log_info "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install required packages
log_info "Installing required packages..."
sudo apt-get install -y -qq \
  curl \
  wget \
  git \
  python3 \
  python3-pip \
  docker.io \
  jq

# Configure Docker for non-root use
log_info "Configuring Docker..."
sudo systemctl enable docker
sudo systemctl start docker
if ! groups | grep -q docker; then
  sudo usermod -aG docker "${USER}"
  log_warn "Added ${USER} to docker group. Re-login may be required."
fi

# Install k3s (lightweight Kubernetes for edge)
if ! command -v k3s &>/dev/null; then
  log_info "Installing k3s (lightweight Kubernetes)..."
  curl -sfL https://get.k3s.io | sh -
  sudo systemctl enable k3s
  log_info "k3s installed"
else
  log_info "k3s already installed: $(k3s --version | head -1)"
fi

# Configure DEVICE_ID in systemd environment
log_info "Configuring device identity..."
sudo tee /etc/environment.d/tactical-arc.conf > /dev/null <<EOF
DEVICE_ID=${DEVICE_ID}
CLOUD_API_URL=${CLOUD_API_URL}
AZURE_ENVIRONMENT=AzureUSGovernment
EOF

# Pull and start the edge agent container (if image provided)
if [[ -n "${AGENT_IMAGE}" ]]; then
  log_info "Pulling edge agent image: ${AGENT_IMAGE}..."
  docker pull "${AGENT_IMAGE}"

  log_info "Installing edge agent as systemd service..."
  sudo tee /etc/systemd/system/tactical-arc-agent.service > /dev/null <<EOF
[Unit]
Description=Tactical ARC Edge Agent
After=docker.service network-online.target
Requires=docker.service

[Service]
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop tactical-arc-agent
ExecStartPre=-/usr/bin/docker rm tactical-arc-agent
ExecStart=/usr/bin/docker run --rm --name tactical-arc-agent \\
  -e DEVICE_ID=${DEVICE_ID} \\
  -e CLOUD_API_URL=${CLOUD_API_URL} \\
  -e AZURE_ENVIRONMENT=AzureUSGovernment \\
  ${AGENT_IMAGE}
ExecStop=/usr/bin/docker stop tactical-arc-agent

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable tactical-arc-agent
  sudo systemctl start tactical-arc-agent
  log_info "Edge agent service started"
fi

echo ""
log_info "Jetson Nano setup complete!"
log_info "Device: ${DEVICE_ID}"
