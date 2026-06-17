# Cloud Application

This document describes the cloud-side components of the Tactical ARC Demo, deployed on AKS in Azure Government.

## Overview

The cloud application consists of a **Python Flask API** that serves as the management plane for edge devices. It is containerized and deployed to AKS using a Helm chart.

## Directory Structure

```
cloud-app/
├── api/
│   ├── src/
│   │   └── main.py          # Flask API application
│   ├── helm/                # Helm chart for AKS deployment
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── serviceaccount.yaml
│   ├── Dockerfile
│   └── requirements.txt
└── scripts/
    └── run-local.sh         # Run API locally for development
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/api/v1/status` | Service and environment status |
| `GET` | `/api/v1/devices` | List registered edge devices |
| `GET` | `/api/v1/devices/{id}` | Get device details |
| `POST` | `/api/v1/devices/{id}/command` | Send command to a device |

## Running Locally

```bash
bash cloud-app/scripts/run-local.sh
```

Or use the VS Code task: **`Cloud: Run API Locally`**

The API will be available at `http://localhost:8080`.

## Building the Container

```bash
bash repo-scripts/build.sh --target cloud --tag v1.0.0
```

## Deploying to AKS

```bash
export ACR_NAME="<your-acr-name>"
export IMAGE_TAG="v1.0.0"

bash repo-scripts/deploy.sh --target cloud
```

## Helm Chart Configuration

Key values in `cloud-app/api/helm/values.yaml`:

| Value | Default | Description |
|-------|---------|-------------|
| `replicaCount` | `2` | Number of pod replicas |
| `image.repository` | `` | ACR image repository (required) |
| `image.tag` | `latest` | Container image tag |
| `env.AZURE_ENVIRONMENT` | `AzureUSGovernment` | Azure environment |
| `env.ARC_RESOURCE_GROUP` | `tactical-arc-rg` | Arc resource group |
| `resources.limits.cpu` | `500m` | CPU limit |
| `resources.limits.memory` | `256Mi` | Memory limit |

Override values at deploy time:

```bash
helm upgrade --install cloud-api cloud-app/api/helm \
  --namespace tactical-arc \
  --set image.repository="${ACR_NAME}.azurecr.us/cloud-api" \
  --set image.tag="v1.0.0" \
  --set replicaCount=3
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `8080` | Port to listen on |
| `FLASK_DEBUG` | No | `false` | Enable Flask debug mode |
| `AZURE_ENVIRONMENT` | No | `AzureUSGovernment` | Azure cloud environment |
| `ARC_RESOURCE_GROUP` | No | `tactical-arc-rg` | Arc resource group name |
| `ARC_CLUSTER_NAME` | No | `tactical-arc-cluster` | Arc cluster name |
