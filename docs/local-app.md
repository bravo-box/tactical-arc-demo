# Local Edge Application

This document describes the edge-side components of the Tactical ARC Demo, running on Jetson Nano devices.

## Overview

The local application consists of a **Python agent** that runs on the Jetson Nano. It communicates with the cloud API to receive commands and report device status. It runs as a Docker container managed by systemd.

## Directory Structure

```
local-app/
└── agent/
    ├── src/
    │   └── agent.py          # Edge agent application
    ├── Dockerfile            # ARM64 container (Jetson L4T base)
    ├── requirements.txt
    └── run-local.sh          # Run agent locally for development
```

## Agent Behavior

The agent runs in a continuous loop:

1. **Collect system info** — hostname, device ID, GPU frequency (Jetson-specific)
2. **Send heartbeat** — POST to `{CLOUD_API_URL}/devices/{DEVICE_ID}/heartbeat`
3. **Poll for commands** — GET from `{CLOUD_API_URL}/devices/{DEVICE_ID}/commands/pending`
4. **Execute commands** — handles `ping`, `restart_service`, `update_config`
5. **Sleep** — waits `HEARTBEAT_INTERVAL` seconds before repeating

## Running Locally (Development)

```bash
bash local-app/agent/run-local.sh
```

Or use the VS Code task: **`Local App: Run Agent Locally`**

The agent will try to reach `http://localhost:8080/api/v1` by default.

## Building the Container

```bash
bash repo-scripts/build.sh --target local --tag v1.0.0
```

> **Note**: The Dockerfile uses `nvcr.io/nvidia/l4t-base:r32.7.1` as the base image, which is ARM64 and optimized for the Jetson Nano. Cross-compilation may be required on non-ARM development machines.

## Deploying to Jetson Nano

```bash
export JETSON_HOST="<jetson-nano-ip>"
export DEVICE_ID="jetson-nano-001"
export CLOUD_API_URL="http://<cloud-api-ip>/api/v1"
export AGENT_IMAGE="<acr-name>.azurecr.us/local-agent:v1.0.0"

bash hardware-scripts/jetson-setup.sh --host "${JETSON_HOST}"
```

Or use the VS Code task: **`Hardware: Setup Jetson Nano`**

## Updating the Agent

```bash
export JETSON_HOST="<jetson-nano-ip>"
export AGENT_IMAGE="<acr-name>.azurecr.us/local-agent:v1.0.1"

bash hardware-scripts/jetson-update.sh --host "${JETSON_HOST}" --image "${AGENT_IMAGE}"
```

Or use the VS Code task: **`Hardware: Update Jetson Nano`**

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CLOUD_API_URL` | No | `http://cloud-api/api/v1` | Cloud API base URL |
| `DEVICE_ID` | No | `jetson-nano-001` | Unique device identifier |
| `HEARTBEAT_INTERVAL` | No | `30` | Seconds between heartbeats |
| `AZURE_ENVIRONMENT` | No | `AzureUSGovernment` | Azure cloud environment |

## Monitoring

Check the agent status on the Jetson Nano:

```bash
# View service status
systemctl status tactical-arc-agent

# View logs
journalctl -u tactical-arc-agent -f
```
