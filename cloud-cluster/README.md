# cloud-cluster

Workloads that run in the Azure Government cloud cluster (AKS provisioned by `/infra`).
The C# heartbeat monitor consumes the `heartbeat-monitor` subscription on the
`edge-heartbeat` topic and displays active devices and their heartbeat history.

- `apps/` – containerized application source code and Dockerfiles.
- `helm/` – Helm chart that deploys the cloud apps and their dependencies.
- `scripts/` – build and deployment scripts for this section.

```bash
./cloud-cluster/scripts/build-images.sh --registry <acr>.azurecr.us --push
./cloud-cluster/scripts/deploy.sh --resource-group rg-tacticalarc --cluster aks-tacticalarc --registry <acr>.azurecr.us
```

Configure either `telemetryApi.serviceBus.existingSecret` with a Service Bus
connection string, or set `fullyQualifiedNamespace` and `workloadIdentity.clientId`
for AKS workload identity.
