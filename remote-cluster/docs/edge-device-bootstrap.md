# Edge device bootstrap guide: Raspberry Pi and Jetson Nano

A single, start-to-finish runbook for turning a bare Raspberry Pi or NVIDIA
Jetson Nano into a running `edge-heartbeat` node: flash the OS, stand up
Kubernetes, pull images from an Azure Container Registry, connect to Azure
Arc, wire up Service Bus, and deploy the Helm chart. Each automated step below
links to the script that does the work; this guide fills in the manual,
device-specific steps the scripts assume are already done (OS flashing, first
boot, and registry connectivity).

## Who this is for

Run **Steps 1-2** on your workstation (flashing media) and **Steps 3-8** on
the device itself unless noted otherwise. Device-specific call-outs are
labeled **Raspberry Pi** or **Jetson Nano**; everything else is common to
both.

## At a glance

| Step | What it does | Where |
| --- | --- | --- |
| 1 | Flash and boot the OS | Workstation + device |
| 2 | First-boot hardening (hostname, updates, cgroups) | Device (`prepare-device.sh`) |
| 3 | Install Docker, K3s, and Helm | Device (`install-kubernetes.sh`) |
| 4 | Connect to an Azure Container Registry and pull images | Workstation (`configure-registry.sh`, `build-images.sh`) + device (`replicate-images.sh`) |
| 5 | Connect the cluster to Azure Arc | Device (`connect-arc.sh`) |
| 6 | Configure the Service Bus channel | Workstation or device (`configure-service-bus.sh`) |
| 7 | Configure device identity and deploy the Helm chart | Device (`deploy.sh`) |
| 8 | Verify | Device |

## Prerequisites

**Workstation:**

- Azure CLI, `kubectl`, `helm`, and Docker (with `buildx`) installed. The
  repo's `.devcontainer` already has all of these.
- Signed in to the target Azure cloud: `az cloud set --name
  AzureUSGovernment` (or `AzureCloud`) then `az login`.
- An SD card imaging tool: [Raspberry Pi
  Imager](https://www.raspberrypi.com/software/) for the Pi, or
  [balenaEtcher](https://etcher.balena.io/)/NVIDIA SDK Manager for the Jetson
  Nano.

**Azure:**

- A resource group and an Azure Container Registry the device can reach
  (public-access ACR for a lab/demo, or the private Premium ACR from
  `/infra` if the device has VPN/private DNS connectivity — see
  [`infra/README.md`](../../infra/README.md)).
- A Service Bus namespace (Terraform-managed, or standalone per
  `configure-service-bus.sh`).

**Per device:**

- A 64-bit Jetson Nano or Raspberry Pi is recommended; ARMv7 also works as
  long as the registry carries an ARMv7 image.
- microSD card (32 GB+), stable 5V power supply (Jetson Nano needs 4A/5V — a
  phone charger will brown out under load), Ethernet or Wi-Fi.

## Step 1: Flash and boot the OS

### Raspberry Pi

1. Open Raspberry Pi Imager, choose **Raspberry Pi OS Lite (64-bit)**, and
   select the SD card.
2. Click the gear/advanced-options icon before writing and set:
   - Hostname (e.g. `edge-01`)
   - Enable SSH, using password or your public key
   - Username/password
   - Wi-Fi SSID/password and locale, if not using Ethernet
3. Write the image, insert the card, and power on the Pi.
4. From your workstation: `ssh <user>@edge-01.local` (or the DHCP-assigned
   IP).

### Jetson Nano

1. Download the JetPack **SD Card image** for your Nano revision (2 GB vs.
   4 GB module) from the [NVIDIA Jetson Download
   Center](https://developer.nvidia.com/embedded/jetpack), or use NVIDIA SDK
   Manager if flashing over USB instead of SD.
2. Flash the image with balenaEtcher (or SDK Manager), insert the microSD
   card, connect a display/keyboard (or a USB-serial console) for first boot,
   and power on with the recommended power supply.
3. Complete the Ubuntu `oem-config` first-boot wizard (EULA, locale,
   username/password, hostname).
4. Enable SSH if it isn't already running: `sudo systemctl enable --now ssh`.
5. From your workstation: `ssh <user>@<jetson-ip>`.

## Step 2: First-boot hardening (both devices)

Copy (or `git clone`) this repo onto the device, then run:

```bash
sudo ./remote-cluster/scripts/prepare-device.sh --hostname edge-01
```

This upgrades packages, sets the hostname (matching the device ID you'll use
later), ensures SSH is enabled, and — on Raspberry Pi only — enables cgroup
memory accounting in `/boot/firmware/cmdline.txt` (or `/boot/cmdline.txt` on
older images) and reboots if that file changed. Jetson/JetPack kernels
already ship with cgroups enabled, so the script is a no-op for that part on
a Nano. Use `--skip-upgrade`, `--skip-ssh`, or `--skip-reboot` to narrow what
it does. If you plan to run GPU workloads on the Nano later, keep
`nvidia-jetpack` packages installed and avoid replacing the vendor kernel.

## Step 3: Install Kubernetes

```bash
sudo ./remote-cluster/scripts/install-kubernetes.sh
```

This installs Docker (using the vendor `docker.io` package on Jetson for
JetPack compatibility, or `docker-ce` on Raspberry Pi OS), single-node K3s,
Helm, and a user kubeconfig at `~/.kube/config`. Docker is only needed for
local image builds; add `--skip-docker` to omit it. Verify:

```bash
kubectl get nodes
```

## Step 4: Connect to an Azure Container Registry

This step builds images on your workstation, pushes them to ACR, and pulls
("replicates") them down to the device.

1. **Identify or create the registry, and configure device access.** Run
   `configure-registry.sh` on your workstation. If you applied the Terraform
   stack in `/infra`, point it at the existing registry name (read it with
   `terraform -chdir=infra output container_registry_name`); otherwise add
   `--create-registry --resource-group <rg> --create-resource-group` to
   create a standalone one.

   ```bash
   # Simplest for a lab/demo: allow unauthenticated pulls from the device
   ./remote-cluster/scripts/configure-registry.sh \
     --name <acrName> \
     --anonymous-pull

   # Or, for authenticated pulls, create a least-privilege repository-pull token
   ./remote-cluster/scripts/configure-registry.sh \
     --name <acrName> \
     --pull-token edge-pull \
     --repository edge-heartbeat \
     --repository device-service \
     --repository location-service \
     --secret-file remote-cluster/.secrets/acr-pull-credential
   ```

   The Terraform ACR disables public access by default, which requires the
   device to have VPN or private DNS connectivity regardless of which option
   above you choose. The script prints (and, with `--secret-file`, saves to a
   mode-`0600` file) the registry login server and, for the token path, the
   pull credential.

2. **Build and push multi-arch images from your workstation** (requires
   Docker Buildx):

   ```bash
   az acr login --name <acrName>

   ./remote-cluster/scripts/build-images.sh \
     --platform linux/arm64 \
     --registry <acrLoginServer> \
     --push

   # Or publish both common 64-bit targets in one pass:
   ./remote-cluster/scripts/build-images.sh \
     --platform linux/amd64,linux/arm64 \
     --registry <acrLoginServer> \
     --push
   ```

3. **Replicate the images onto the device.** Copy the repo (and the secret
   file, if you created one) to the device, then run `replicate-images.sh`
   to pre-pull each image so the first Helm install doesn't stall on a slow
   link. The default image list is `edge-heartbeat`, `device-service`, and
   `location-service`; add `--image camera-capture --image image-uploader`
   if `imagePipeline.enabled=true`.

   ```bash
   # Anonymous-pull registry: no credentials needed
   ./remote-cluster/scripts/replicate-images.sh --registry <acrLoginServer>

   # Token-authenticated registry: also configure K3s (containerd) so
   # Helm-triggered pulls succeed without a Kubernetes image pull secret
   sudo ./remote-cluster/scripts/replicate-images.sh \
     --registry <acrLoginServer> \
     --username edge-pull \
     --credential-file remote-cluster/.secrets/acr-pull-credential \
     --configure-k3s
   ```

## Step 5: Connect Kubernetes to Azure Arc

```bash
./remote-cluster/scripts/connect-arc.sh --list-resource-groups
./remote-cluster/scripts/connect-arc.sh \
  --resource-group az-tactical-demo-edge \
  --name edge-01 \
  --create-resource-group
```

Add `--subscription "<name-or-id>"` if the signed-in account has more than
one subscription. The script registers the Arc resource providers, installs
the `connectedk8s` CLI extension, checks the local cluster, connects it (or
reports the existing connection), and prints connectivity status.

## Step 6: Configure the Service Bus channel

```bash
./remote-cluster/scripts/configure-service-bus.sh \
  --resource-group az-tactical-demo-edge \
  --namespace "<globally-unique-service-bus-name>" \
  --create-resource-group
```

This creates the `edge-heartbeat` topic, `heartbeat-monitor` subscription,
the session-aware `update-location` queue, and least-privilege edge
credentials. Connection strings land under `remote-cluster/.secrets/` (mode
`0600`, Git-ignored). If you're instead using the private Terraform
namespace, see the Arc-identity path in
[`remote-cluster/README.md`](../README.md#3-configure-the-heartbeat-channel).

## Step 7: Configure device identity and deploy the Helm chart

Edit `remote-cluster/config/edge-heartbeat.json` and
`remote-cluster/config/device-info.json` with this device's ID and metadata
(see [`remote-cluster/README.md`](../README.md#4-configure-build-and-deploy)
for the full field list), then deploy:

```bash
./remote-cluster/scripts/deploy.sh \
  --registry <acrLoginServer> \
  --config remote-cluster/config/edge-heartbeat.json \
  --device-config remote-cluster/config/device-info.json
```

Pass `--chart oci://<registry>/helm/remote-cluster --chart-version <ver>` (or
a repository/URL reference) instead of the default local chart path if you
publish the chart to the registry too. The script creates the
`edge-heartbeat-servicebus` and `location-service-servicebus` Kubernetes
secrets directly, so the connection strings never go into Helm values or
release history, then runs `helm upgrade --install` and waits for the
`edge-heartbeat`, `location-service`, and `device-service` rollouts.

## Step 8: Verify

```bash
kubectl -n tactical-arc get pods
kubectl -n tactical-arc logs -l app.kubernetes.io/component=edge-heartbeat --follow
az connectedk8s show --resource-group az-tactical-demo-edge --name edge-01 \
  --query connectivityStatus --output tsv
```

Confirm in the cloud UI that the device appears and heartbeats are updating.

## Device-specific troubleshooting

**Raspberry Pi**

- `kubectl get nodes` stuck `NotReady`: confirm `prepare-device.sh` added
  `cgroup_memory=1 cgroup_enable=memory` to `cmdline.txt` and the device
  rebooted (rerun the script, or check `cat /proc/cmdline`).
- Low-power SD cards can cause intermittent I/O errors under K3s/etcd load;
  prefer A2-rated cards or boot from USB SSD on Pi 4/5.

**Jetson Nano**

- If `install-kubernetes.sh` reports an unsupported distribution when
  installing Docker, confirm you're on the vendor JetPack/L4T image; the
  script auto-detects `/etc/nv_tegra_release` and installs `docker.io`
  instead of `docker-ce` for compatibility.
- Brown-outs/reboots under load usually mean an underpowered supply; use the
  recommended barrel-jack 5V/4A adapter and enable the barrel-jack power
  mode jumper (J48) if present on your carrier board.
- `docker buildx build --platform linux/arm64` on the Nano itself is slow;
  prefer building on the workstation (Step 4) and only pulling on the device.

## Script reference

| Script | Runs on | Purpose |
| --- | --- | --- |
| `remote-cluster/scripts/prepare-device.sh` | Device | Package upgrade, hostname, SSH, cgroup kernel params |
| `remote-cluster/scripts/install-kubernetes.sh` | Device | Docker + K3s + Helm + kubeconfig |
| `remote-cluster/scripts/configure-registry.sh` | Workstation | Create/configure ACR: anonymous pull or a scoped pull token |
| `remote-cluster/scripts/build-images.sh` | Workstation | Build and push edge app images |
| `remote-cluster/scripts/replicate-images.sh` | Device | Docker login + pre-pull images + optional K3s/containerd registry auth |
| `remote-cluster/scripts/connect-arc.sh` | Device | Azure Arc onboarding |
| `remote-cluster/scripts/configure-service-bus.sh` | Workstation or device | Service Bus topic/queue + credentials |
| `remote-cluster/scripts/deploy.sh` | Device | Secrets + `helm upgrade --install` + rollout wait |
