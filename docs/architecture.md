# Architecture Overview

## System Design

The Tactical ARC Demo is a two-tier architecture consisting of a **cloud layer** running on Azure Kubernetes Service (AKS) in Azure Government and an **edge layer** running on Jetson Nano devices managed via Azure Arc.

```
┌─────────────────────────────────────────────────────────┐
│                  Azure Government Cloud                  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  AKS Cluster (usgovarizona)                       │  │
│  │  ┌──────────────┐  ┌──────────────────────────┐  │  │
│  │  │  Cloud API   │  │   Azure Arc Control Plane │  │  │
│  │  │  (Flask/     │  │   (manages edge clusters) │  │  │
│  │  │   Python)    │  │                           │  │  │
│  │  └──────────────┘  └──────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌────────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │    ACR     │  │  VNet    │  │   Terraform State  │  │
│  │ (.azurecr. │  │          │  │   (Storage Acct)   │  │
│  │   us)      │  │          │  │                    │  │
│  └────────────┘  └──────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │ Azure Arc
                          │ (secure tunnel)
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     Edge / Field                        │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Jetson Nano                                      │  │
│  │  ┌──────────────────────────────────────────┐    │  │
│  │  │  k3s (lightweight Kubernetes)             │    │  │
│  │  │  ┌────────────────────────────────────┐  │    │  │
│  │  │  │  Local Edge Agent (Python)          │  │    │  │
│  │  │  │  - Polls cloud API for commands     │  │    │  │
│  │  │  │  - Reports device status            │  │    │  │
│  │  │  │  - Manages local workloads          │  │    │  │
│  │  │  └────────────────────────────────────┘  │    │  │
│  │  └──────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Components

### Cloud Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Cloud API | Python / Flask | REST API for managing edge devices |
| AKS | Azure Kubernetes Service | Container orchestration on Azure Gov |
| ACR | Azure Container Registry | Private container image storage |
| Virtual Network | Azure VNet | Network isolation for AKS |
| Azure Arc | Azure Arc | Edge device management and GitOps |

### Edge Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Local Agent | Python | Polls cloud API, executes commands |
| k3s | Lightweight Kubernetes | Container runtime on Jetson Nano |
| Docker | Docker | Container engine |

## Data Flow

1. **Command Dispatch**: Operator sends command via Cloud API → stored in Azure → delivered to Jetson Nano via Arc/polling
2. **Status Reporting**: Jetson Nano agent sends heartbeat → Cloud API stores device status → available for querying
3. **Image Distribution**: Developer pushes to ACR → AKS pulls via AcrPull role assignment → Helm deploys updated image

## Security

- **Managed Identity**: AKS uses SystemAssigned identity; AcrPull role granted to kubelet identity
- **Non-root containers**: Both Cloud API and Local Agent run as non-root users
- **Read-only filesystem**: Cloud API container uses `readOnlyRootFilesystem: true`
- **Azure Government**: All resources target `usgovernment` environment with FedRAMP-compliant endpoints
- **Admin disabled**: ACR admin access is disabled; authentication uses managed identity
