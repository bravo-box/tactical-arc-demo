# Edge device setup

These scripts configure a Jetson Nano, Raspberry Pi, or Debian/Ubuntu edge
device with K3s, Azure Arc-enabled Kubernetes, Service Bus, the
`edge-heartbeat` application, and local MQTT-backed device and location services.
The chart also contains an opt-in camera image
pipeline for a V4L2-compatible camera such as `/dev/video0`.

## Prerequisites

- A 64-bit Jetson Nano or Raspberry Pi is recommended. ARMv7 is also accepted
  by the installer, but the selected container registry must provide an ARMv7
  image.
- Debian, Raspberry Pi OS, or Ubuntu with `systemd`.
- Azure CLI installed and authenticated.
- Outbound HTTPS and AMQP-over-WebSockets/AMQP connectivity to Azure.

The examples default to Azure Government. Use `--cloud AzureCloud` and an
Azure public region when deploying to commercial Azure.

## 1. Install local Kubernetes

Run on the device:

```bash
sudo ./remote-cluster/scripts/install-kubernetes.sh
```

This installs Docker, single-node K3s, Helm, and a user kubeconfig. Docker is
needed only for local image builds and can be omitted with `--skip-docker`.

## 2. Connect Kubernetes to Azure Arc

Inspect available resource groups, then connect the cluster:

```bash
./remote-cluster/scripts/connect-arc.sh --list-resource-groups
./remote-cluster/scripts/connect-arc.sh \
  --resource-group az-tactical-demo-edge \
  --name edge-01 \
  --create-resource-group
```

Use `--subscription "<name-or-id>"` if the Azure CLI account has more than one
subscription. The script registers the Arc resource providers, installs the
`connectedk8s` extension, checks the local cluster, and returns Arc status.

## 3. Configure the heartbeat channel

For a standalone edge namespace with a topic-scoped sender credential:

```bash
./remote-cluster/scripts/configure-service-bus.sh \
  --resource-group az-tactical-demo-edge \
  --namespace "<globally-unique-service-bus-name>" \
  --create-resource-group
```

The script creates the `edge-heartbeat` topic, a `heartbeat-monitor`
subscription, the session-aware `update-location` queue, and least-privilege
edge credentials. The heartbeat sender and location receiver connection strings
are written with mode `0600` under `remote-cluster/.secrets/`, which Git ignores.

The Terraform stack also creates the topic and monitoring subscription in the
private Premium namespace. That path requires device VPN/private DNS access
and an identity integration because local authentication is disabled.

## 4. Configure, build, and deploy

Edit the heartbeat configuration:

```json
{
  "device-name": "edge-01",
  "healthStatus": "Green",
  "heartbeatIntervalSeconds": 5,
  "serviceBusTopic": "edge-heartbeat",
  "mqttPort": 1883,
  "deviceInfoTimeoutSeconds": 5,
  "locationTimeoutSeconds": 5
}
```

Edit `remote-cluster/config/device-info.json` on the device with the stable
device information to include in heartbeats and image metadata:

```json
{
  "deviceId": "edge-01",
  "manufacturer": "Example",
  "model": "Edge Device",
  "serialNumber": "replace-me"
}
```

The deploy script mounts this file directly from the device filesystem as a
read-only `hostPath`. Pass `--device-config /absolute/path/device-info.json`
to use another location.

The chart initializes `/var/lib/tactical-arc/location/location.json` with
`locationService.initialLocation` and mounts that host directory read/write
into `location-service`. Existing coordinates survive pod upgrades and are not
overwritten. Set the initial coordinates and device ID during deployment:

```bash
helm upgrade --install remote-cluster ./remote-cluster/helm/remote-cluster \
  --namespace tactical-arc \
  --set locationService.deviceId=edge-01 \
  --set locationService.initialLocation.latitude=47.6062 \
  --set locationService.initialLocation.longitude=-122.3321
```

Then build a multi-architecture image and deploy the local chart:

```bash
./remote-cluster/scripts/build-images.sh \
  --platform linux/arm64 \
  --registry "<registry>" \
  --push \

# Or publish both common 64-bit targets:
./remote-cluster/scripts/build-images.sh \
  --platform linux/amd64,linux/arm64 \
  --registry "<registry>" \
  --push

./remote-cluster/scripts/deploy.sh \
  --registry "<registry>" \
  --config remote-cluster/config/edge-heartbeat.json \
  --device-config remote-cluster/config/device-info.json
```

To install a remote chart instead, pass a repository chart, archive URL, or OCI
reference and optional version:

```bash
./remote-cluster/scripts/deploy.sh \
  --chart oci://<registry>/helm/remote-cluster \
  --chart-version 0.2.0 \
  --registry "<registry>"
```

Verify operation with:

```bash
kubectl -n tactical-arc logs \
  -l app.kubernetes.io/component=edge-heartbeat \
  --follow
```

The deploy script creates the Kubernetes Secret directly before invoking Helm,
so the Service Bus credential is not stored in Helm values or release history.
The heartbeat publishes only after correlated device information and
`RequestLocation` / `ResponseLocation` exchanges, preventing incomplete device
records when either local service is unavailable. Location changes arrive as
`UpdateLocationRequest`, are validated and atomically persisted, and produce an
`UpdateLocationResponse` confirmation on MQTT.

## Camera image pipeline

Apply the Terraform stack, configure the edge identity or Kubernetes secrets,
then enable the pipeline:

```bash
helm upgrade --install remote-cluster ./remote-cluster/helm/remote-cluster \
  --namespace tactical-arc \
  --set imagePipeline.enabled=true \
  --set cameraCapture.cameraDeviceHostPath=/dev/video0 \
  --set cameraCapture.videoGroupId=44
```

Update `cameraCapture.config` and `imageUploader.config` in `values.yaml` with
the Terraform Service Bus namespace and storage account URL when using the Arc
identity. For connection-string authentication, create the three secrets named
by `cameraCapture.serviceBus`, `imageUploader.serviceBus`, and
`imageUploader.storage`; each uses a `connection-string` key.

The command body accepts either form:

```json
{"type":"TakePicture","id":"11a3524e-86b3-4428-9f9a-abf51136f1ad","correlationId":"11a3524e-86b3-4428-9f9a-abf51136f1ad","deviceId":"edge-01"}
```

```json
{"command":"TakePicture","id":"11a3524e-86b3-4428-9f9a-abf51136f1ad","correlationId":"11a3524e-86b3-4428-9f9a-abf51136f1ad","deviceId":"edge-01"}
```

The capture service emits `SendImage` on `edge/images/send`. Before upload, the
uploader requests current device information and location, then adds both to
the blob metadata and `ImageUpload` event. The uploader keeps
the JPEG and JSON manifest on the persistent volume until both the blob upload
and `ImageUpload` Service Bus notification succeed. With no connectivity it
checks every five seconds, opens after five failures, waits one minute, then
probes every second until the circuit closes.

The `take-picture` queue requires Service Bus sessions. Each camera receiver
accepts only the session matching its configured `deviceId`, and the GUID
`correlationId` is preserved in the MQTT event, blob metadata, `ImageUpload`
message, and cloud request status.
