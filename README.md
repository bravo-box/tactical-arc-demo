# tactical-arc-demo

Build out an application showing remote management of a device at the edge using Arc, and connecting to a the cloud for data and telemetry.

## Repository layout

| Path | Purpose |
| --- | --- |
| `/infra` | Terraform templates for Azure Government, authenticated with the logged-in Azure CLI user. |
| `/cloud-cluster` | The apps to run the cloud cluster. |
| `/cloud-cluster/apps` | Containerized app source code and Dockerfiles. |
| `/cloud-cluster/helm` | Helm chart deploying the cloud apps and dependencies onto the cluster. |
| `/cloud-cluster/scripts` | Scripts for building and deploying the cloud section. |
| `/remote-cluster` | The apps designed to run at the edge. |
| `/remote-cluster/apps` | Containerized edge app source code and Dockerfiles. |
| `/remote-cluster/helm` | Helm chart for deploying the apps to the edge device. |
| `/remote-cluster/scripts` | Edge scripts, including Kubernetes/Docker stand-up for the edge cluster. |
| `/scripts` | General scripts for the repo. |

## Edge camera image flow

The optional image pipeline extends the heartbeat monitor without changing its
default deployment:

1. The cloud UI sends a GUID-correlated `TakePicture` command for the selected
   device through a session-enabled Service Bus queue. `camera-capture` receives
   only its device session, captures `/dev/video0`, and writes the JPEG plus a
   recovery manifest to the shared edge volume.
2. It publishes a QoS 1 `SendImage` event to the local Mosquitto router.
3. `image-uploader` uploads pending manifests to the private `device-images`
   blob container after obtaining current device metadata from `device-service`
   over a correlated local MQTT request. Connectivity is checked every five seconds; five failures
   open the circuit for one minute, followed by one-second half-open probes
   until connectivity returns.
4. After upload, it publishes `ImageUpload` to Service Bus and removes the
   local image and manifest.
5. The existing cloud heartbeat monitor consumes `ImageUpload`. Selecting a
   device can trigger a capture, inspect correlated request status in a
   collapsible panel, browse image tiles, and open the full image metadata.

Set `imagePipeline.enabled=true` in the remote chart and
`telemetryApi.imageServiceBus.enabled=true` in the cloud chart after applying
the Terraform resources. Both applications support connection strings for
local/demo use and `DefaultAzureCredential` with the private Terraform
deployment.

## Dev container

`.devcontainer/` provides a container with everything needed to work on this repo:

- **SSH git authentication** – the host `~/.ssh` directory is mounted (read-only) and copied
  into the container with correct permissions, GitHub host keys are trusted, and available
  keys are added to the SSH agent. VS Code also forwards the host `ssh-agent`.
- **kubectl** and **helm**
- **Azure CLI** (defaults to the `AzureUSGovernment` cloud via `AZURE_CLOUD`)
- **Terraform** (with tflint)
- **Packer** (installed from the HashiCorp apt repository in `post-create.sh`)
- Docker-in-Docker for building the container images

> The dev container mounts the host `~/.ssh` directory read-only, so create it on the
> host (with your git key) before starting the container.

Verify the tooling inside the container with:

```bash
./scripts/verify-tools.sh            # tool availability only
./scripts/verify-tools.sh --check-ssh # also test SSH auth against github.com
```

## Linting

```bash
./scripts/lint.sh
```
