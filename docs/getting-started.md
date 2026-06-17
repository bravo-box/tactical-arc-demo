# Getting Started

This guide walks you through setting up your local development environment and deploying the Tactical ARC Demo for the first time.

## Prerequisites

Before you begin, ensure you have the following:

- An **Azure Government subscription** with sufficient permissions (Contributor or Owner)
- A **Jetson Nano** device (for edge functionality)
- A development machine with internet access

## Option 1: Use the Dev Container (Recommended)

All required tools are pre-configured in the dev container.

1. Install [VS Code](https://code.visualstudio.com/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
3. Clone this repository
4. Open in VS Code and click **"Reopen in Container"** when prompted
5. All tools (az, terraform, kubectl, helm, docker, python, node, dotnet) will be available

## Option 2: Manual Installation

Install the following tools manually:

| Tool | Version | Installation |
|------|---------|-------------|
| Azure CLI | Latest | [docs.microsoft.com](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Terraform | >= 1.5.0 | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/downloads) |
| kubectl | Latest | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Helm | >= 3.0 | [helm.sh](https://helm.sh/docs/intro/install/) |
| Docker | Latest | [docker.com](https://docs.docker.com/get-docker/) |
| Python | 3.11+ | [python.org](https://www.python.org/downloads/) |
| Node.js | LTS | [nodejs.org](https://nodejs.org/) |
| .NET SDK | 8.0 | [dotnet.microsoft.com](https://dotnet.microsoft.com/download) |

## Step 1: Initialize the Environment

Run the setup script to verify tool installations and create Python virtual environments:

```bash
bash repo-scripts/setup.sh
```

Or use the **VS Code task**: `Setup: Initialize Environment`

## Step 2: Authenticate to Azure Government

```bash
az login --environment AzureUSGovernment
az account set --subscription "<your-subscription-id>"
```

## Step 3: Deploy Infrastructure

Initialize and apply the Terraform templates:

```bash
# Set required environment variables
export ARM_ENVIRONMENT=usgovernment
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export ARM_TENANT_ID="<your-tenant-id>"
export ARM_CLIENT_ID="<your-service-principal-id>"
export ARM_CLIENT_SECRET="<your-service-principal-secret>"

# Initialize Terraform
bash repo-scripts/terraform.sh init

# Review the plan
bash repo-scripts/terraform.sh plan

# Apply the infrastructure
bash repo-scripts/terraform.sh apply
```

Or use the **VS Code tasks**: `Infra: Terraform Init`, `Infra: Terraform Plan`, `Infra: Terraform Apply`

## Step 4: Build and Push Container Images

```bash
export ACR_NAME="<acr-name-from-terraform-output>"

# Build and push all images
bash repo-scripts/build.sh --target all --push --tag v1.0.0
```

Or use the **VS Code task**: `Build: All`

## Step 5: Get AKS Credentials

```bash
export AKS_RESOURCE_GROUP="tactical-arc-dev-rg"
export AKS_CLUSTER_NAME="tactical-arc-dev-aks"

bash repo-scripts/get-aks-credentials.sh
```

Or use the **VS Code task**: `Kubernetes: Get AKS Credentials`

## Step 6: Deploy Cloud Application

```bash
export IMAGE_TAG="v1.0.0"
export ACR_NAME="<your-acr-name>"

bash repo-scripts/deploy.sh --target cloud
```

Or use the **VS Code task**: `Deploy: Cloud App (Helm)`

## Step 7: Set Up Jetson Nano

```bash
export JETSON_HOST="<jetson-nano-ip>"
export DEVICE_ID="jetson-nano-001"
export CLOUD_API_URL="http://<cloud-api-endpoint>/api/v1"
export AGENT_IMAGE="${ACR_NAME}.azurecr.us/local-agent:v1.0.0"

bash hardware-scripts/jetson-setup.sh --host "${JETSON_HOST}"
```

Or use the **VS Code task**: `Hardware: Setup Jetson Nano`

## Verify the Deployment

After all steps are complete:

```bash
# Check AKS pods
kubectl get pods -n tactical-arc

# Check Cloud API health
kubectl port-forward -n tactical-arc svc/cloud-api 8080:80
curl http://localhost:8080/health
```
