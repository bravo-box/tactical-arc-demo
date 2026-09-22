# remote-cluster

Workloads designed to run at the edge on an Azure Arc-enabled Kubernetes cluster.

- `apps/` – containerized edge application source code and Dockerfiles.
- `helm/` – Helm chart for deploying the apps to the edge device.
- `scripts/` – scripts that run on the edge device, including Kubernetes and Docker setup.

```bash
sudo ./remote-cluster/scripts/install-kubernetes.sh
./remote-cluster/scripts/connect-arc.sh --resource-group rg-tacticalarc --name arc-edge-01
./remote-cluster/scripts/build-images.sh
./remote-cluster/scripts/deploy.sh --telemetry-url https://telemetry.example.us/telemetry
```
