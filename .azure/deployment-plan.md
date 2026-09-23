# Azure Deployment Plan

> **Status:** Ready for Validation

Generated: 2026-09-23T12:08:00-04:00

---

## 1. Project Overview

**Goal:** Extend the cloud-side telemetry application with persistent Azure Cosmos DB for NoSQL storage. Store one JSON document per device containing the current device state, bounded heartbeat history, saved-image metadata, latitude/longitude, and device specifications. The AKS telemetry API will access Cosmos DB through the existing Microsoft Entra workload identity without account keys or connection strings.

**Path:** Add Components

---

## 2. Requirements

| Attribute | Value |
|-----------|-------|
| Classification | Development / demonstration |
| Scale | Small |
| Budget | Cost-Optimized |
| Subscription | Existing Terraform deployment subscription, selected by `var.subscription_id` or the active Azure CLI subscription; user confirmed reuse |
| Location | `usgovvirginia`; user confirmed reuse of the existing Terraform location |
| Cloud | Azure Government |

---

## 3. Components Detected

| Component | Type | Technology | Path |
|-----------|------|------------|------|
| Telemetry API and web UI | API / Frontend | ASP.NET Core 8 minimal API | `cloud-cluster/apps/telemetry-api` |
| Heartbeat consumer | Worker | Azure Service Bus SDK for .NET | `cloud-cluster/apps/telemetry-api/Services/ServiceBusHeartbeatConsumer.cs` |
| Image event consumer | Worker | Azure Service Bus SDK for .NET | `cloud-cluster/apps/telemetry-api/Services/ServiceBusImageConsumer.cs` |
| Cloud deployment | Kubernetes package | Helm | `cloud-cluster/helm/cloud-cluster` |
| Cloud infrastructure | Infrastructure as code | Terraform / AzureRM | `infra` |
| Edge heartbeat publisher | Worker | Python / Azure Service Bus SDK | `remote-cluster/apps/edge-heartbeat` |

The current telemetry API keeps heartbeat and image state in process memory, so data is lost when its AKS pod restarts and replicas do not share state.

---

## 4. Recipe Selection

**Selected:** Terraform

**Rationale:**

- The repository already uses Terraform 1.6+ and AzureRM 4.x for an Azure Government deployment.
- AKS, its user-assigned workload identity, private networking, and role assignments already exist in Terraform.
- The change can extend the current modules without introducing a second deployment tool or state boundary.

---

## 5. Architecture

**Stack:** Existing private AKS cluster plus Azure Cosmos DB for NoSQL

### Service Mapping

| Component | Azure Service | SKU / Configuration |
|-----------|---------------|---------------------|
| Telemetry API | Existing Azure Kubernetes Service | Existing private Standard-tier cluster |
| Device document store | Azure Cosmos DB for NoSQL | Single region, Session consistency, 400 RU/s provisioned throughput |
| Device images | Existing Azure Blob Storage | Image bytes remain in Blob Storage; Cosmos stores image metadata and blob names |
| Event ingestion | Existing Azure Service Bus | Existing topics/subscriptions |

### Device Document

The `devices` container will use `/deviceId` as its partition key and one document per device:

```json
{
  "id": "device-id",
  "deviceId": "device-id",
  "ipAddress": "10.0.0.10",
  "healthStatus": "Green",
  "lastSeen": "2026-09-23T16:00:00Z",
  "location": {
    "latitude": 38.8977,
    "longitude": -77.0365
  },
  "specs": [
    { "name": "hostname", "value": "edge-01" },
    { "name": "architecture", "value": "arm64" }
  ],
  "heartbeats": [],
  "images": []
}
```

- Heartbeat and image histories will be bounded by configuration to respect Cosmos DB's 2 MB item limit.
- Image entries contain metadata and Blob Storage references, not binary image content.
- Heartbeat events will carry optional location and device specs; existing publishers that omit them remain compatible.
- Writes will use Cosmos DB optimistic concurrency and retry on ETag conflicts so heartbeat and image consumers cannot overwrite each other's updates.

### Supporting Services

| Service | Purpose |
|---------|---------|
| Existing user-assigned managed identity | Token-based AKS-to-Cosmos authentication |
| Cosmos DB built-in data-plane role | Grant only data contributor access to the application identity |
| Private endpoint and private DNS | Keep Cosmos traffic on the existing virtual network |
| Existing Log Analytics / Application Insights | Existing application and cluster observability |

---

## 6. Provisioning Limit Checklist

Azure Cosmos DB is not supported by `az quota`. The local Azure CLI installation also fails before account lookup because its `win32file` dependency cannot load. The inventory therefore uses the existing Terraform resource graph in this repository and Microsoft Cosmos DB service-limit documentation. The account limit is 250 Cosmos DB accounts per subscription; this deployment adds one account.

| Resource Type | Number to Deploy | Total in This Deployment | Limit / Capacity | Notes |
|---------------|------------------|--------------------------|------------------|-------|
| `Microsoft.DocumentDB/databaseAccounts` | 1 | 1 | 250 accounts per subscription | `az quota` unsupported for Microsoft.DocumentDB; Microsoft Learn Cosmos DB resource model limit |
| Cosmos SQL database | 1 | 1 | 500 databases/containers by default per account | Child resource; within documented account metadata limit |
| Cosmos SQL container | 1 | 1 | 500 databases/containers by default per account | One `devices` container partitioned by `/deviceId` |
| Cosmos SQL role assignment | 1 | 1 | No separate deployment quota identified | Existing AKS workload identity receives built-in data contributor |
| `Microsoft.Network/privateEndpoints` | 1 | 4 managed by this Terraform deployment | 1,000 per virtual network | Existing configuration has three private endpoints; one Cosmos endpoint is added |
| `Microsoft.Network/privateDnsZones` | 1 | 4 managed by this Terraform deployment | 1,000 private DNS zones per subscription | Adds the Azure Government Cosmos private-link zone |

**Status:** All planned resources are within documented limits. Subscription-wide current Cosmos account usage could not be queried because the Azure CLI installation is broken; deployment remains subject to the subscription's 250-account limit.

---

## 7. Execution Checklist

### Phase 1: Planning

- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location with user
- [x] Prepare resource inventory
- [x] Check quota support and document fallback limits
- [x] Scan codebase
- [x] Select recipe
- [x] Plan architecture
- [x] **User approved this plan**

### Phase 2: Execution

- [x] Add Cosmos DB account, database, container, data-plane RBAC, diagnostics, private endpoint, and private DNS to Terraform
- [x] Add Cosmos endpoint/database/container outputs and Helm configuration
- [x] Add Cosmos SDK and managed-identity client configuration to the telemetry API
- [x] Replace in-memory heartbeat and image persistence with a shared Cosmos device document repository
- [x] Extend heartbeat payloads with optional location and device specifications
- [x] Keep API behavior compatible while reading persisted device documents
- [x] Add and update unit tests for document persistence, validation, and bounded histories
- [x] Update deployment and operator documentation
- [x] Functionally verify .NET tests, Python tests, Helm rendering, and Terraform formatting/validation
- [x] Set plan status to `Ready for Validation`

### Phase 3: Validation

- [x] Invoke `azure-validate`
- [ ] All validation checks pass
  - [x] Terraform CLI is installed
  - [x] Azure CLI is installed and authenticated
  - [ ] Terraform initializes successfully with the remote backend
  - [x] Terraform formatting check passes
  - [x] Terraform configuration validates
  - [ ] Terraform plan succeeds
  - [ ] Terraform state is accessible
  - [x] Terraform template-variable scan passes
  - [x] Terraform variables JSON syntax check is not applicable
- [x] Validate Helm, application build, and targeted tests
- [ ] Update plan status to `Validated`
- [ ] Record validation proof below

### Phase 4: Deployment

- [ ] Invoke `azure-deploy` only if deployment is requested after validation
- [ ] Verify Cosmos connectivity from the AKS workload
- [ ] Update plan status to `Deployed`

---

## 8. Validation Proof

| Check | Command Run | Result | Timestamp |
|-------|-------------|--------|-----------|
| Terraform format | `terraform -chdir=.\infra fmt -check -recursive` | ✅ Pass | 2026-09-23 |
| Terraform syntax | `terraform -chdir=.\infra init -backend=false -input=false` then `terraform validate` | ✅ Pass | 2026-09-23 |
| Official Terraform preflight | `validate-terraform.sh .../infra` | ❌ Remote backend init, plan, and state blocked because backend parameters were not supplied; all local checks and Azure authentication passed | 2026-09-23 |
| Telemetry API tests | `dotnet test ...HeartbeatMonitor.Tests.csproj` | ✅ 8 passed | 2026-09-23 |
| Telemetry API release build | `dotnet build ...HeartbeatMonitor.csproj --configuration Release` | ✅ Pass, zero warnings | 2026-09-23 |
| Edge heartbeat tests | `python -m unittest discover ...` | ✅ 6 passed | 2026-09-23 |
| Helm render | `helm template` for cloud and remote charts | ✅ Pass | 2026-09-23 |
| Helm lint | `helm lint` for cloud and remote charts | ✅ Pass | 2026-09-23 |
| Diff whitespace | `git diff --check` | ✅ Pass | 2026-09-23 |

**Validated by:** `azure-validate` local checks; final validation remains blocked until existing remote backend parameters are supplied.

---

## 9. Files to Generate or Modify

| File / Area | Purpose | Status |
|-------------|---------|--------|
| `.azure/deployment-plan.md` | Deployment source of truth | Complete for approval |
| `infra/modules/cloud/*` | Cosmos account, database, container, RBAC, diagnostics, and outputs | Complete |
| `infra/modules/private-link/*` | Cosmos private endpoint and Azure Government private DNS | Complete |
| `infra/main.tf`, `infra/outputs.tf` | Wire module dependencies and publish deployment values | Complete |
| `cloud-cluster/apps/telemetry-api/*` | Cosmos-backed device repository and API integration | Complete |
| `cloud-cluster/apps/telemetry-api.Tests/*` | Persistence and compatibility tests | Complete |
| `cloud-cluster/helm/cloud-cluster/*` | Cosmos endpoint/database/container configuration | Complete |
| `remote-cluster/apps/edge-heartbeat/*` | Optional location and device-spec payload fields | Complete |
| Existing READMEs | Configuration and operational guidance | Complete |

---

## 10. Next Step

Run `azure-validate` against the prepared application and infrastructure.
