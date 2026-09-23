# cloud-cluster

Workloads that run in the Azure Government cloud cluster (AKS provisioned by `/infra`).
The C# heartbeat monitor consumes the `heartbeat-monitor` subscription on the
`edge-heartbeat` topic and displays active devices and their heartbeat history.
Its optional image feature also consumes `image-upload`, reads private blobs,
and displays image tiles and a full-size metadata modal on the selected device.

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

Enable images with:

```bash
helm upgrade --install cloud-cluster ./cloud-cluster/helm/cloud-cluster \
  --namespace tactical-arc \
  --set telemetryApi.imageServiceBus.enabled=true \
  --set telemetryApi.imageServiceBus.fullyQualifiedNamespace="<namespace>.servicebus.usgovcloudapi.net" \
  --set telemetryApi.cameraCommands.fullyQualifiedNamespace="<namespace>.servicebus.usgovcloudapi.net" \
  --set telemetryApi.storage.accountUrl="https://<account>.blob.core.usgovcloudapi.net" \
  --set telemetryApi.workloadIdentity.clientId="<terraform workload_identity_client_id>"
```

For a local/demo namespace, set the image Service Bus and storage
`existingSecret` values instead. Each secret must contain a `connection-string`
key.

The selected device name is sent as the Service Bus session ID, so it must
match `cameraCapture.config.deviceId` on the edge device. The UI assigns a GUID
correlation ID to each request and shows it as `Queued` until the matching
`ImageUpload` event marks it `Uploaded`.
