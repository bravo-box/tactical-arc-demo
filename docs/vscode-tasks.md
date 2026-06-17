# VS Code Tasks Reference

This document describes all VS Code tasks available in the Tactical ARC Demo. Tasks are defined in `.vscode/tasks.json` and provide a convenient way to run scripts without leaving the editor.

## Running Tasks

1. Open the Command Palette: `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS)
2. Type **"Tasks: Run Task"** and press Enter
3. Select the task from the list

Or use the keyboard shortcuts:
- **Build default task**: `Ctrl+Shift+B` — runs **Build: All**
- **Run test task**: `Ctrl+Shift+T` — opens task selector for test group

## Available Tasks

### Setup Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Setup: Initialize Environment** | `repo-scripts/setup.sh` | Verify tool installations, create Python venvs |

### Build Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Build: Cloud App** | `repo-scripts/build.sh --target cloud` | Build the Cloud API Docker image |
| **Build: Local App** | `repo-scripts/build.sh --target local` | Build the Local Agent Docker image |
| **Build: All** _(default)_ | `repo-scripts/build.sh --target all` | Build all Docker images |

### Deploy Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Deploy: Infrastructure (Terraform)** | `repo-scripts/deploy.sh --target infra` | Run Terraform apply for all infrastructure |
| **Deploy: Cloud App (Helm)** | `repo-scripts/deploy.sh --target cloud` | Deploy Cloud API to AKS via Helm |
| **Deploy: All** | `repo-scripts/deploy.sh --target all` | Deploy infrastructure then cloud app |

### Infrastructure (Terraform) Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Infra: Terraform Init** | `repo-scripts/terraform.sh init` | Initialize Terraform and download providers |
| **Infra: Terraform Plan** | `repo-scripts/terraform.sh plan` | Preview infrastructure changes |
| **Infra: Terraform Apply** | `repo-scripts/terraform.sh apply` | Apply infrastructure changes |
| **Infra: Terraform Destroy** | `repo-scripts/terraform.sh destroy` | Destroy all infrastructure ⚠️ |

### Kubernetes / Docker Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Docker: Login to ACR** | `repo-scripts/docker-login.sh` | Authenticate Docker to Azure Container Registry |
| **Kubernetes: Get AKS Credentials** | `repo-scripts/get-aks-credentials.sh` | Configure kubectl for the AKS cluster |

### Hardware / Edge Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Hardware: Setup Jetson Nano** | `hardware-scripts/jetson-setup.sh` | Initial setup of a Jetson Nano device |
| **Hardware: Update Jetson Nano** | `hardware-scripts/jetson-update.sh` | Update agent on a Jetson Nano device |

### Local Development Tasks

| Task Name | Script | Description |
|-----------|--------|-------------|
| **Cloud: Run API Locally** | `cloud-app/scripts/run-local.sh` | Start Cloud API on localhost:8080 |
| **Local App: Run Agent Locally** | `local-app/agent/run-local.sh` | Start edge agent in local dev mode |

## Task Groups

Tasks are organized into VS Code task groups:

- **build** — Build and initialization tasks (runs with `Ctrl+Shift+B`)
- **test** — Deployment and run tasks (accessible via task picker)

## Environment Variables

Most tasks read configuration from environment variables. You can set these in a `.env` file or in your shell profile. Key variables:

```bash
# Azure
export ARM_ENVIRONMENT=usgovernment
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_CLIENT_ID="<client-id>"
export ARM_CLIENT_SECRET="<client-secret>"

# ACR / AKS
export ACR_NAME="<acr-name>"
export AKS_RESOURCE_GROUP="tactical-arc-dev-rg"
export AKS_CLUSTER_NAME="tactical-arc-dev-aks"
export IMAGE_TAG="latest"

# Edge device
export JETSON_HOST="<jetson-ip>"
export JETSON_USER="jetson"
export DEVICE_ID="jetson-nano-001"
export CLOUD_API_URL="http://<cloud-api-endpoint>/api/v1"
```
