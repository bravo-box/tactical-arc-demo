# cloud-cluster/apps

Containerized applications that run in the cloud cluster. Each subdirectory
contains the app source code and its `Dockerfile`.

- `telemetry-api/` – monitors edge heartbeats and, when enabled, consumes image
  uploads, persists one Cosmos DB document per device through AKS workload
  identity, and renders a per-device image gallery with full-size metadata
  views.
