# Tactical ARC Demo

A demonstration of how to use **Azure Arc**, **Azure Kubernetes Service (AKS)**, and **Kubernetes** to deploy and manage a containerized application on **Azure Government** cloud while remotely managing an **NVIDIA Jetson Nano** edge device.

This project showcases the Adaptive Cloud pattern: cloud workloads running on AKS in Azure Government (usgovarizona) with edge workloads on a Jetson Nano device, all managed through a unified control plane using Azure Arc.

---

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [VS Code Tasks](#vs-code-tasks)
- [Quick Start](#quick-start)
- [Documentation](#documentation)

---

## Overview

**Tactical ARC Demo** deploys:

- A **Python Flask API** on AKS (Azure Government) that manages edge devices
- A **Python edge agent** running on a Jetson Nano, connected via Azure Arc
- **Azure infrastructure** (AKS, ACR, VNet) provisioned with Terraform targeting Azure Government
- **Helm charts** for Kubernetes deployment
- **Bash scripts** for all automation tasks

---

## Repository Structure

```
tactical-arc-demo/
├── .devcontainer/          # Dev container with all required tools pre-installed
│   └── devcontainer.json
├── .vscode/                # VS Code tasks for running all scripts
│   └── tasks.json
├── cloud-app/              # Cloud-side containerized services (AKS)
│   ├── api/                # Python Flask REST API
│   │   ├── src/            # Application source code
│   │   ├── helm/           # Helm chart for AKS deployment
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── scripts/            # Cloud-specific scripts
├── docs/                   # Documentation and architecture guides
│   ├── architecture.md
│   ├── cloud-app.md
│   ├── getting-started.md
│   ├── infrastructure.md
│   ├── local-app.md
│   └── vscode-tasks.md
├── hardware-scripts/       # Scripts for edge devices (Jetson Nano)
│   ├── jetson-setup.sh
│   └── jetson-update.sh
├── infra/                  # Terraform templates (Azure Government)
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── aks/            # AKS cluster module
│       ├── acr/            # Azure Container Registry module
│       └── networking/     # Virtual Network module
├── local-app/              # Edge-side containerized services (Jetson Nano)
│   └── agent/              # Python edge agent
│       ├── src/
│       ├── Dockerfile
│       └── requirements.txt
└── repo-scripts/           # Shared bash scripts for repo operations
    ├── setup.sh
    ├── build.sh
    ├── deploy.sh
    ├── terraform.sh
    ├── docker-login.sh
    └── get-aks-credentials.sh
```

---

## Prerequisites

All tools are pre-configured in the **dev container** (recommended). Open this repo in VS Code and select **"Reopen in Container"**.

For manual setup, you need:
- Azure CLI (`az`)
- Terraform >= 1.5.0
- kubectl
- Helm >= 3.0
- Docker
- Python 3.11+
- Node.js (LTS)
- .NET SDK 8.0

---

## VS Code Tasks

All scripts can be run directly from VS Code without opening a terminal. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and type **"Tasks: Run Task"** to see all available tasks.

| Task | Description |
|------|-------------|
| **Setup: Initialize Environment** | Verify tools and create Python virtual environments |
| **Build: Cloud App** | Build the Cloud API Docker image |
| **Build: Local App** | Build the Local Agent Docker image |
| **Build: All** _(default build)_ | Build all Docker images |
| **Deploy: Infrastructure (Terraform)** | Run Terraform apply for all infrastructure |
| **Deploy: Cloud App (Helm)** | Deploy Cloud API to AKS via Helm |
| **Deploy: All** | Deploy infrastructure then cloud app |
| **Infra: Terraform Init** | Initialize Terraform and download providers |
| **Infra: Terraform Plan** | Preview infrastructure changes |
| **Infra: Terraform Apply** | Apply infrastructure changes |
| **Infra: Terraform Destroy** | Destroy all infrastructure ⚠️ |
| **Docker: Login to ACR** | Authenticate Docker to Azure Container Registry |
| **Kubernetes: Get AKS Credentials** | Configure kubectl for the AKS cluster |
| **Hardware: Setup Jetson Nano** | Initial setup of a Jetson Nano device |
| **Hardware: Update Jetson Nano** | Update agent on a Jetson Nano device |
| **Cloud: Run API Locally** | Start Cloud API on localhost:8080 |
| **Local App: Run Agent Locally** | Start edge agent in local dev mode |

> See [docs/vscode-tasks.md](docs/vscode-tasks.md) for detailed task documentation and required environment variables.

---

## Quick Start

```bash
# 1. Initialize environment (verify tools, create venvs)
bash repo-scripts/setup.sh

# 2. Log in to Azure Government
az login --environment AzureUSGovernment

# 3. Deploy infrastructure
bash repo-scripts/terraform.sh init
bash repo-scripts/terraform.sh plan
bash repo-scripts/terraform.sh apply

# 4. Build and push container images
export ACR_NAME="<acr-name-from-terraform-output>"
bash repo-scripts/build.sh --target all --push --tag v1.0.0

# 5. Get AKS credentials
export AKS_RESOURCE_GROUP="tactical-arc-dev-rg"
export AKS_CLUSTER_NAME="tactical-arc-dev-aks"
bash repo-scripts/get-aks-credentials.sh

# 6. Deploy cloud application
export IMAGE_TAG="v1.0.0"
bash repo-scripts/deploy.sh --target cloud

# 7. Set up Jetson Nano
export JETSON_HOST="<jetson-nano-ip>"
export DEVICE_ID="jetson-nano-001"
export CLOUD_API_URL="http://<cloud-api-ip>/api/v1"
export AGENT_IMAGE="${ACR_NAME}.azurecr.us/local-agent:v1.0.0"
bash hardware-scripts/jetson-setup.sh --host "${JETSON_HOST}"
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/getting-started.md](docs/getting-started.md) | Step-by-step setup and first deployment guide |
| [docs/architecture.md](docs/architecture.md) | System architecture overview and component descriptions |
| [docs/infrastructure.md](docs/infrastructure.md) | Terraform infrastructure details and configuration |
| [docs/cloud-app.md](docs/cloud-app.md) | Cloud API service documentation |
| [docs/local-app.md](docs/local-app.md) | Local edge agent documentation |
| [docs/vscode-tasks.md](docs/vscode-tasks.md) | VS Code tasks reference and environment variables |
